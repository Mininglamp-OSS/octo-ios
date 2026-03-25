//
//  WKMarkdownRenderer.swift
//  WuKongBase
//
//  Markdown rendering using Down library (cmark).
//  Tables and task lists are pre-processed to HTML since cmark doesn't support GFM extensions.
//

import UIKit
import Down

@objc public class WKMarkdownRenderer: NSObject {

    @objc public static func render(_ text: String,
                                     fontSize: CGFloat,
                                     textColorHex: String) -> NSAttributedString? {
        guard !text.isEmpty else { return nil }

        // Pre-process: convert GFM extensions (tables, task lists, strikethrough) to HTML
        let preprocessed = preprocessGFM(text)

        let down = Down(markdownString: preprocessed)
        let css = buildCSS(fontSize: fontSize, textColorHex: textColorHex)

        do {
            let attributed = try down.toAttributedString(.unsafe, stylesheet: css)

            // Trim trailing newlines
            let mutable = NSMutableAttributedString(attributedString: attributed)
            while mutable.length > 0 {
                let lastChar = mutable.attributedSubstring(from: NSRange(location: mutable.length - 1, length: 1)).string
                if lastChar == "\n" || lastChar == "\r" {
                    mutable.deleteCharacters(in: NSRange(location: mutable.length - 1, length: 1))
                } else {
                    break
                }
            }

            return mutable
        } catch {
            return nil
        }
    }

    @objc public static func containsMarkdown(_ text: String) -> Bool {
        if text.isEmpty { return false }

        if text.contains("**") { return true }
        if text.contains("```") { return true }
        if text.contains("~~") { return true }
        if text.range(of: "^#{1,3} ", options: .regularExpression) != nil { return true }
        if text.range(of: "`[^`]+`", options: .regularExpression) != nil { return true }
        if text.range(of: "\\[.+\\]\\(.+\\)", options: .regularExpression) != nil { return true }

        let multilinePatterns = [
            "^- \\[[xX ]\\] ",
            "^\\|.*\\|$",
            "^>\\s",
            "^-{3,}$",
            "^\\d+\\. ",
            "^[\\-\\*] "
        ]
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in multilinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
               regex.firstMatch(in: text, range: nsRange) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - GFM Pre-processing

    /// Pre-process GFM extensions that cmark doesn't support:
    /// tables, task lists, strikethrough → convert to raw HTML blocks
    private static func preprocessGFM(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0
        var inCodeBlock = false

        while i < lines.count {
            let line = lines[i]

            // Track code fences — don't process anything inside
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                result.append(line)
                i += 1
                continue
            }
            if inCodeBlock {
                result.append(line)
                i += 1
                continue
            }

            // Table: consecutive lines starting and ending with |
            if isTableLine(line) {
                var tableLines: [String] = [line]
                var j = i + 1
                while j < lines.count && isTableLine(lines[j]) {
                    tableLines.append(lines[j])
                    j += 1
                }
                if tableLines.count >= 2 {
                    let html = convertTableToHTML(tableLines)
                    result.append("")  // blank line before HTML block
                    result.append(html)
                    result.append("")  // blank line after HTML block
                    i = j
                    continue
                }
            }

            // Task list item: - [x] or - [ ]
            if isTaskListLine(line) {
                // Collect consecutive task list items
                var taskLines: [String] = [line]
                var j = i + 1
                while j < lines.count && isTaskListLine(lines[j]) {
                    taskLines.append(lines[j])
                    j += 1
                }
                let html = convertTaskListToHTML(taskLines)
                result.append("")
                result.append(html)
                result.append("")
                i = j
                continue
            }

            // Strikethrough: ~~text~~ → <del>text</del>
            let processed = processStrikethrough(line)
            result.append(processed)
            i += 1
        }

        return result.joined(separator: "\n")
    }

    private static func isTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count >= 3
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }
        let allowed = CharacterSet(charactersIn: "|:- ")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func parseTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func convertTableToHTML(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }

        let hasSeparator = lines.count >= 2 && isTableSeparator(lines[1])

        var html = "<table>"

        for (idx, line) in lines.enumerated() {
            if hasSeparator && idx == 1 { continue }  // skip separator row

            let cells = parseTableCells(line)
            let isHeader = hasSeparator && idx == 0
            let tag = isHeader ? "th" : "td"

            html += "<tr>"
            for cell in cells {
                html += "<\(tag)>\(escapeHTML(cell))</\(tag)>"
            }
            html += "</tr>"
        }

        html += "</table>"
        return html
    }

    private static func isTaskListLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("- [ ] ")
    }

    private static func convertTaskListToHTML(_ lines: [String]) -> String {
        var html = "<ul style=\"list-style:none;padding-left:4px;\">"
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let checked = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
            let text = String(trimmed.dropFirst(6))  // drop "- [x] " or "- [ ] "

            let checkbox = checked ? "☑" : "☐"
            let style = checked ? "color:gray;text-decoration:line-through;" : ""
            html += "<li>\(checkbox) <span style=\"\(style)\">\(escapeHTML(text))</span></li>"
        }
        html += "</ul>"
        return html
    }

    private static func processStrikethrough(_ line: String) -> String {
        guard line.contains("~~") else { return line }
        // Replace ~~text~~ with <del>text</del>
        var result = line
        while let openRange = result.range(of: "~~") {
            let afterOpen = openRange.upperBound
            guard let closeRange = result.range(of: "~~", range: afterOpen..<result.endIndex) else { break }
            let content = String(result[afterOpen..<closeRange.lowerBound])
            if content.isEmpty {
                // Skip empty
                break
            }
            result = result.replacingCharacters(in: openRange.lowerBound..<closeRange.upperBound,
                                                 with: "<del>\(escapeHTML(content))</del>")
        }
        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - CSS

    private static func buildCSS(fontSize: CGFloat, textColorHex: String) -> String {
        let h1 = fontSize * 1.5
        let h2 = fontSize * 1.3
        let h3 = fontSize * 1.15
        let codeFontSize = fontSize - 1.0

        return """
        * {
            font-family: -apple-system, 'PingFang SC', 'Helvetica Neue', sans-serif;
            font-size: \(fontSize)px;
            color: \(textColorHex);
            line-height: 1.4;
        }
        h1 { font-size: \(h1)px; font-weight: 600; margin: 4px 0; }
        h2 { font-size: \(h2)px; font-weight: 600; margin: 3px 0; }
        h3 { font-size: \(h3)px; font-weight: 600; margin: 2px 0; }
        p { margin: 2px 0; }
        code {
            font-family: Menlo, monospace;
            font-size: \(codeFontSize)px;
            background-color: rgba(0,0,0,0.06);
            padding: 1px 4px;
            border-radius: 3px;
        }
        pre {
            background-color: rgba(0,0,0,0.06);
            padding: 8px;
            border-radius: 6px;
            margin: 4px 0;
            overflow-x: auto;
        }
        pre code { background-color: transparent; padding: 0; }
        blockquote {
            color: gray;
            margin: 2px 0;
            padding-left: 12px;
            border-left: 3px solid #ccc;
        }
        a { color: #007AFF; text-decoration: underline; }
        table { border-collapse: collapse; margin: 4px 0; width: auto; }
        th {
            font-weight: 600;
            padding: 4px 8px;
            border-bottom: 2px solid #999;
            text-align: left;
        }
        td {
            padding: 4px 8px;
            border-bottom: 1px solid #E0E0E0;
        }
        ul, ol { padding-left: 20px; margin: 2px 0; }
        li { margin: 1px 0; }
        hr { border: none; border-top: 1px solid #ccc; margin: 6px 0; }
        del, s { text-decoration: line-through; }
        """
    }
}
