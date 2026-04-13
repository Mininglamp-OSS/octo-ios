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
        return render(text, fontSize: fontSize, textColorHex: textColorHex, dynamicTextColor: nil)
    }

    /// 带动态颜色的渲染方法，dynamicTextColor 会被设置到 attributed string 中，
    /// 使文本颜色能跟随系统深浅色模式实时变化。
    @objc public static func render(_ text: String,
                                     fontSize: CGFloat,
                                     textColorHex: String,
                                     dynamicTextColor: UIColor?) -> NSAttributedString? {
        guard !text.isEmpty else { return nil }

        // Pre-process: convert GFM extensions (tables, task lists, strikethrough) to HTML
        let preprocessed = preprocessGFM(text)

        let down = Down(markdownString: preprocessed)
        let isDark = WKApp.shared().config.style == WKSystemStyleDark
        let css = buildCSS(fontSize: fontSize, textColorHex: textColorHex, isDark: isDark)

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

            // 用动态 UIColor 替换 WebKit 渲染的静态颜色，使文本能跟随深浅色实时变化
            let replaceColor = dynamicTextColor ?? UIColor.wk_fromHex(textColorHex)
            fixForegroundColors(in: mutable, replaceColor: replaceColor, isDark: isDark)

            return mutable
        } catch {
            return nil
        }
    }

    @objc public static func containsMarkdown(_ text: String) -> Bool {
        if text.isEmpty { return false }

        if text.contains("**") { NSLog("[Markdown] matched: **"); return true }
        if text.contains("```") { NSLog("[Markdown] matched: ```"); return true }
        if text.contains("~~") { NSLog("[Markdown] matched: ~~"); return true }
        if text.range(of: "^#{1,3} ", options: .regularExpression) != nil { NSLog("[Markdown] matched: heading"); return true }
        if text.range(of: "`[^`]+`", options: .regularExpression) != nil { NSLog("[Markdown] matched: inline code"); return true }
        if text.range(of: "\\[.+\\]\\(.+\\)", options: .regularExpression) != nil { NSLog("[Markdown] matched: link [%@]", String(text.prefix(30))); return true }

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

    // MARK: - Table extraction for WKWebView rendering

    /// Check if markdown text contains a valid table (at least 2 consecutive | lines)
    @objc public static func containsTable(_ text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var consecutiveTableLines = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                consecutiveTableLines = 0
                continue
            }
            if inCodeBlock {
                consecutiveTableLines = 0
                continue
            }
            if isTableLine(line) {
                consecutiveTableLines += 1
                if consecutiveTableLines >= 2 { return true }
            } else {
                consecutiveTableLines = 0
            }
        }
        return false
    }

    /// Split content into ordered segments of text and table blocks
    @objc public static func splitContentSegments(_ text: String) -> NSArray {
        let lines = text.components(separatedBy: "\n")
        var segments: [[String: String]] = []
        var currentTextLines: [String] = []
        var inCodeBlock = false
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                currentTextLines.append(line)
                i += 1
                continue
            }
            if inCodeBlock {
                currentTextLines.append(line)
                i += 1
                continue
            }

            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    // Flush accumulated text
                    let txt = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !txt.isEmpty {
                        segments.append(["type": "text", "content": txt])
                    }
                    currentTextLines = []
                    // Add table segment
                    let tableContent = Array(lines[i..<j]).joined(separator: "\n")
                    segments.append(["type": "table", "content": tableContent])
                    i = j
                    continue
                }
            }

            currentTextLines.append(line)
            i += 1
        }

        let remaining = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            segments.append(["type": "text", "content": remaining])
        }

        return segments as NSArray
    }

    /// Extract table portions from markdown and return a full HTML document for WKWebView rendering
    @objc public static func extractTableHTML(_ text: String,
                                               fontSize: CGFloat,
                                               textColorHex: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var tableGroups: [[String]] = []
        var currentTable: [String] = []
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                if currentTable.count >= 2 { tableGroups.append(currentTable) }
                currentTable = []
                continue
            }
            if inCodeBlock { continue }

            if isTableLine(line) {
                currentTable.append(line)
            } else {
                if currentTable.count >= 2 { tableGroups.append(currentTable) }
                currentTable = []
            }
        }
        if currentTable.count >= 2 { tableGroups.append(currentTable) }
        if tableGroups.isEmpty { return nil }

        var tablesHTML = ""
        for tableLines in tableGroups {
            tablesHTML += convertTableToHTML(tableLines)
        }

        let isDark = WKApp.shared().config.style == WKSystemStyleDark
        let css = buildTableWebViewCSS(fontSize: fontSize, textColorHex: textColorHex, isDark: isDark)
        return """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(css)</style>
        </head><body>\(tablesHTML)</body></html>
        """
    }

    /// Render full content (text + tables) as HTML, preserving original order
    @objc public static func renderFullContentHTML(_ text: String,
                                                    fontSize: CGFloat,
                                                    textColorHex: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var i = 0
        var currentTextLines: [String] = []

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                currentTextLines.append(line)
                i += 1
                continue
            }
            if inCodeBlock {
                currentTextLines.append(line)
                i += 1
                continue
            }

            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    // Flush accumulated text
                    if !currentTextLines.isEmpty {
                        html += textLinesToHTML(currentTextLines)
                        currentTextLines = []
                    }
                    let tableLines = Array(lines[i..<j])
                    html += convertTableToHTML(tableLines)
                    i = j
                    continue
                }
            }

            currentTextLines.append(line)
            i += 1
        }
        // Flush remaining text
        if !currentTextLines.isEmpty {
            html += textLinesToHTML(currentTextLines)
        }

        if html.isEmpty { return nil }

        let isDark = WKApp.shared().config.style == WKSystemStyleDark
        let css = buildFullContentCSS(fontSize: fontSize, textColorHex: textColorHex, isDark: isDark)
        return """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>\(css)</style>
        </head><body>\(html)</body></html>
        """
    }

    /// Estimate total content height (text lines + table rows)
    @objc public static func fullContentHeight(_ text: String, fontSize: CGFloat) -> CGFloat {
        let lines = text.components(separatedBy: "\n")
        let lineHeight = fontSize * 1.4
        var height: CGFloat = 0
        var inCodeBlock = false
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                height += lineHeight
                i += 1
                continue
            }
            if inCodeBlock {
                height += lineHeight
                i += 1
                continue
            }

            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    let hasSep = j - i >= 2 && isTableSeparator(lines[i + 1])
                    let visibleRows = hasSep ? j - i - 1 : j - i
                    height += CGFloat(visibleRows) * 32.0 + 4.0
                    i = j
                    continue
                }
            }

            if line.isEmpty {
                height += lineHeight * 0.5
            } else {
                height += lineHeight
            }
            i += 1
        }

        return height
    }

    private static func textLinesToHTML(_ lines: [String]) -> String {
        let joined = lines.joined(separator: "\n")
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        var escaped = escapeHTML(trimmed)
        // Basic markdown: **bold**
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            escaped = boldRegex.stringByReplacingMatches(in: escaped, options: [], range: NSRange(escaped.startIndex..., in: escaped), withTemplate: "<strong>$1</strong>")
        }
        return "<div class=\"text-block\">\(escaped.replacingOccurrences(of: "\n", with: "<br>"))</div>"
    }

    private static func buildFullContentCSS(fontSize: CGFloat, textColorHex: String, isDark: Bool) -> String {
        let thBorder = isDark ? "#666666" : "#999"
        let thBg = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.04)"
        let tdBorder = isDark ? "#444444" : "#E0E0E0"

        return """
        * {
            font-family: -apple-system, 'PingFang SC', 'Helvetica Neue', sans-serif;
            font-size: \(fontSize)px;
            color: \(textColorHex);
            margin: 0;
            padding: 0;
        }
        body { margin: 0; padding: 0; -webkit-text-size-adjust: none; }
        .text-block { white-space: pre-wrap; line-height: 1.4; padding: 2px 0; }
        table { border-collapse: collapse; width: max-content; white-space: nowrap; margin: 4px 0; }
        th {
            font-weight: 600;
            padding: 6px 12px;
            border-bottom: 2px solid \(thBorder);
            text-align: left;
            background-color: \(thBg);
        }
        td {
            padding: 6px 12px;
            border-bottom: 1px solid \(tdBorder);
        }
        tr:last-child td { border-bottom: none; }
        """
    }

    /// Remove table markdown lines from text, keeping the rest
    @objc public static func removeTableMarkdown(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inCodeBlock = false
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
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

            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    i = j   // skip valid table block
                    continue
                }
            }

            result.append(line)
            i += 1
        }

        return result.joined(separator: "\n")
    }

    /// Count visible table rows (excluding separator rows) for height estimation
    @objc public static func tableRowCount(_ text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var count = 0
        var inCodeBlock = false
        var currentTableLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                if currentTableLines.count >= 2 {
                    for tl in currentTableLines {
                        if !isTableSeparator(tl) { count += 1 }
                    }
                }
                currentTableLines = []
                continue
            }
            if inCodeBlock { continue }

            if isTableLine(line) {
                currentTableLines.append(line)
            } else {
                if currentTableLines.count >= 2 {
                    for tl in currentTableLines {
                        if !isTableSeparator(tl) { count += 1 }
                    }
                }
                currentTableLines = []
            }
        }
        if currentTableLines.count >= 2 {
            for tl in currentTableLines {
                if !isTableSeparator(tl) { count += 1 }
            }
        }

        return count
    }

    private static func buildTableWebViewCSS(fontSize: CGFloat, textColorHex: String, isDark: Bool) -> String {
        let borderColor = isDark ? "#444444" : "#E0E0E0"
        let thBg = isDark ? "rgba(255,255,255,0.08)" : "#F5F5F5"

        return """
        * {
            font-family: -apple-system, 'PingFang SC', 'Helvetica Neue', sans-serif;
            font-size: \(fontSize)px;
            color: \(textColorHex);
            margin: 0;
            padding: 0;
        }
        body { margin: 0; padding: 0; -webkit-text-size-adjust: none; background-color: transparent; }
        table { border-collapse: collapse; width: max-content; white-space: nowrap; }
        th {
            font-weight: 600;
            padding: 10px 14px;
            border: 1px solid \(borderColor);
            text-align: left;
            background-color: \(thBg);
        }
        td {
            padding: 10px 14px;
            border: 1px solid \(borderColor);
        }
        """
    }

    // MARK: - CSS

    private static func buildCSS(fontSize: CGFloat, textColorHex: String, isDark: Bool) -> String {
        let h1 = fontSize * 1.5
        let h2 = fontSize * 1.3
        let h3 = fontSize * 1.15
        let codeFontSize = fontSize - 1.0

        let codeBg = isDark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.06)"
        let blockquoteColor = isDark ? "#aaaaaa" : "gray"
        let blockquoteBorder = isDark ? "#555555" : "#ccc"
        let linkColor = isDark ? "#64B5F6" : "#5979F0"
        let thBorder = isDark ? "#666666" : "#999"
        let tdBorder = isDark ? "#444444" : "#E0E0E0"
        let hrColor = isDark ? "#555555" : "#ccc"

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
            background-color: \(codeBg);
            padding: 1px 4px;
            border-radius: 3px;
        }
        pre {
            background-color: \(codeBg);
            padding: 8px;
            border-radius: 6px;
            margin: 4px 0;
            overflow-x: auto;
        }
        pre code { background-color: transparent; padding: 0; }
        blockquote {
            color: \(blockquoteColor);
            margin: 2px 0;
            padding-left: 12px;
            border-left: 3px solid \(blockquoteBorder);
        }
        a { color: \(linkColor); text-decoration: underline; }
        table { border-collapse: collapse; margin: 4px 0; width: auto; }
        th {
            font-weight: 600;
            padding: 4px 8px;
            border-bottom: 2px solid \(thBorder);
            text-align: left;
        }
        td {
            padding: 4px 8px;
            border-bottom: 1px solid \(tdBorder);
        }
        ul, ol { padding-left: 20px; margin: 2px 0; }
        li { margin: 1px 0; }
        hr { border: none; border-top: 1px solid \(hrColor); margin: 6px 0; }
        del, s { text-decoration: line-through; }
        """
    }

    // MARK: - 颜色修正

    /// 修正文本颜色：将 WebKit 渲染产生的静态颜色替换为动态 UIColor，
    /// 使 UILabel 在深浅色模式切换时能自动更新颜色，无需手动 reloadData。
    /// 保留链接、blockquote 等特殊颜色不变。
    /// replaceColor: 传入动态 UIColor（如 messageRecvTextColor），UILabel 在 trait 变化时自动更新
    private static func fixForegroundColors(in attrStr: NSMutableAttributedString, replaceColor: UIColor, isDark: Bool) {
        // 动态链接颜色
        let dynamicLinkColor: UIColor
        if #available(iOS 13.0, *) {
            dynamicLinkColor = UIColor { traitCollection in
                let dark = traitCollection.userInterfaceStyle == .dark
                return dark ? UIColor(red: 100/255, green: 181/255, blue: 246/255, alpha: 1)
                            : UIColor(red: 89/255, green: 121/255, blue: 240/255, alpha: 1)
            }
        } else {
            dynamicLinkColor = isDark ? UIColor(red: 100/255, green: 181/255, blue: 246/255, alpha: 1)
                                      : UIColor(red: 89/255, green: 121/255, blue: 240/255, alpha: 1)
        }

        // 当前模式下的链接色和引用色，用于识别不应替换的特殊颜色
        let curLinkColor = isDark ? UIColor(red: 100/255, green: 181/255, blue: 246/255, alpha: 1)
                                  : UIColor(red: 89/255, green: 121/255, blue: 240/255, alpha: 1)
        let curBlockquoteColor = isDark ? UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1)
                                        : UIColor.gray

        let fullRange = NSRange(location: 0, length: attrStr.length)
        attrStr.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            guard let color = value as? UIColor else {
                attrStr.addAttribute(.foregroundColor, value: replaceColor, range: range)
                return
            }
            if isColorSimilar(color, curLinkColor) {
                attrStr.addAttribute(.foregroundColor, value: dynamicLinkColor, range: range)
            } else if !isColorSimilar(color, curBlockquoteColor) {
                attrStr.addAttribute(.foregroundColor, value: replaceColor, range: range)
            }
        }
    }

    /// 判断两个颜色是否相近（容差 0.1）
    private static func isColorSimilar(_ c1: UIColor, _ c2: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let threshold: CGFloat = 0.1
        return abs(r1 - r2) < threshold && abs(g1 - g2) < threshold && abs(b1 - b2) < threshold
    }
}

// MARK: - UIColor hex 工具

private extension UIColor {
    static func wk_fromHex(_ hexString: String) -> UIColor {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 else { return UIColor.black }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                       green: CGFloat((rgb >> 8) & 0xFF) / 255,
                       blue: CGFloat(rgb & 0xFF) / 255,
                       alpha: 1)
    }
}
