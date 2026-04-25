//
//  WKMarkdownRenderer.swift
//  WuKongBase
//
//  Markdown rendering using cmark-gfm (pure C parser, no WebKit dependency).
//  Tables are still rendered via WKWebView; text portions use NSAttributedString built from AST.
//

import UIKit
import libcmark_gfm

@objc public class WKMarkdownRenderer: NSObject {

    @objc public static func render(_ text: String,
                                     fontSize: CGFloat,
                                     textColorHex: String) -> NSAttributedString? {
        return render(text, fontSize: fontSize, textColorHex: textColorHex, dynamicTextColor: nil)
    }

    @objc public static func render(_ text: String,
                                     fontSize: CGFloat,
                                     textColorHex: String,
                                     dynamicTextColor: UIColor?) -> NSAttributedString? {
        guard !text.isEmpty else { return nil }

        let isDark = WKApp.shared().config.style == WKSystemStyleDark
        let textColor = dynamicTextColor ?? UIColor.wk_fromHex(textColorHex)
        let linkColor: UIColor
        if #available(iOS 13.0, *) {
            linkColor = UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 100/255, green: 181/255, blue: 246/255, alpha: 1)
                    : UIColor(red: 89/255, green: 121/255, blue: 240/255, alpha: 1)
            }
        } else {
            linkColor = isDark
                ? UIColor(red: 100/255, green: 181/255, blue: 246/255, alpha: 1)
                : UIColor(red: 89/255, green: 121/255, blue: 240/255, alpha: 1)
        }

        let codeBg: UIColor = isDark
            ? UIColor(white: 1, alpha: 0.1)
            : UIColor(white: 0, alpha: 0.06)
        let blockquoteColor: UIColor = isDark
            ? UIColor(red: 170/255, green: 170/255, blue: 170/255, alpha: 1)
            : UIColor.gray

        let baseFont = WKApp.shared().config.appFont(ofSize: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        let boldFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? baseFont.fontDescriptor, size: fontSize)
        let italicFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? baseFont.fontDescriptor, size: fontSize)
        let boldItalicFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) ?? baseFont.fontDescriptor, size: fontSize)
        let codeFont = UIFont(name: "Menlo", size: fontSize - 1) ?? UIFont(name: "Courier", size: fontSize - 1) ?? UIFont.systemFont(ofSize: fontSize - 1)

        // Register GFM extensions
        cmark_gfm_core_extensions_ensure_registered()

        guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return nil }
        defer { cmark_parser_free(parser) }

        // Attach GFM extensions: strikethrough, table, autolink, tagfilter
        let extNames = ["strikethrough", "table", "autolink", "tagfilter"]
        for name in extNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        cmark_parser_feed(parser, text, text.utf8.count)
        guard let doc = cmark_parser_finish(parser) else { return nil }
        defer { cmark_node_free(doc) }

        // Context for recursive rendering
        struct RenderContext {
            let fontSize: CGFloat
            let textColor: UIColor
            let linkColor: UIColor
            let codeBg: UIColor
            let blockquoteColor: UIColor
            let baseFont: UIFont
            let boldFont: UIFont
            let italicFont: UIFont
            let boldItalicFont: UIFont
            let codeFont: UIFont
            var isBold = false
            var isItalic = false
            var isCode = false
            var isBlockquote = false
            var isStrikethrough = false
            var linkURL: String? = nil
            var listType: cmark_list_type = CMARK_NO_LIST
            var listItemIndex: Int = 0
            var listDepth: Int = 0
            var headingLevel: Int = 0
        }

        var ctx = RenderContext(
            fontSize: fontSize,
            textColor: textColor,
            linkColor: linkColor,
            codeBg: codeBg,
            blockquoteColor: blockquoteColor,
            baseFont: baseFont,
            boldFont: boldFont,
            italicFont: italicFont,
            boldItalicFont: boldItalicFont,
            codeFont: codeFont
        )

        let result = NSMutableAttributedString()

        func currentFont(_ ctx: RenderContext) -> UIFont {
            if ctx.isCode { return ctx.codeFont }
            if ctx.headingLevel > 0 {
                let scale: CGFloat = ctx.headingLevel == 1 ? 1.5 : ctx.headingLevel == 2 ? 1.3 : 1.15
                let hSize = ctx.fontSize * scale
                let desc = ctx.baseFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? ctx.baseFont.fontDescriptor
                return UIFont(descriptor: desc, size: hSize)
            }
            if ctx.isBold && ctx.isItalic { return ctx.boldItalicFont }
            if ctx.isBold { return ctx.boldFont }
            if ctx.isItalic { return ctx.italicFont }
            return ctx.baseFont
        }

        func currentColor(_ ctx: RenderContext) -> UIColor {
            if ctx.linkURL != nil { return ctx.linkColor }
            if ctx.isBlockquote { return ctx.blockquoteColor }
            return ctx.textColor
        }

        func renderNode(_ node: UnsafeMutablePointer<cmark_node>, ctx: inout RenderContext) {
            let nodeType = cmark_node_get_type(node)
            let nodeTypeStr = cmark_node_get_type_string(node)
            let typeStr = nodeTypeStr != nil ? String(cString: nodeTypeStr!) : ""

            switch nodeType {
            case CMARK_NODE_TEXT:
                if let literal = cmark_node_get_literal(node) {
                    let text = String(cString: literal)
                    var attrs: [NSAttributedString.Key: Any] = [
                        .font: currentFont(ctx),
                        .foregroundColor: currentColor(ctx)
                    ]
                    if ctx.isCode {
                        attrs[.backgroundColor] = ctx.codeBg
                    }
                    if ctx.isStrikethrough {
                        attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    }
                    if let url = ctx.linkURL {
                        attrs[.link] = url
                        attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    }
                    result.append(NSAttributedString(string: text, attributes: attrs))
                }
                return

            case CMARK_NODE_SOFTBREAK:
                result.append(NSAttributedString(string: "\n", attributes: [.font: currentFont(ctx), .foregroundColor: currentColor(ctx)]))
                return

            case CMARK_NODE_LINEBREAK:
                result.append(NSAttributedString(string: "\n", attributes: [.font: currentFont(ctx), .foregroundColor: currentColor(ctx)]))
                return

            case CMARK_NODE_CODE:
                if let literal = cmark_node_get_literal(node) {
                    let text = String(cString: literal)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: ctx.codeFont,
                        .foregroundColor: currentColor(ctx),
                        .backgroundColor: ctx.codeBg
                    ]
                    result.append(NSAttributedString(string: text, attributes: attrs))
                }
                return

            case CMARK_NODE_CODE_BLOCK:
                if let literal = cmark_node_get_literal(node) {
                    var text = String(cString: literal)
                    if text.hasSuffix("\n") { text = String(text.dropLast()) }
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 8
                    style.headIndent = 8
                    style.tailIndent = -8
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: ctx.codeFont,
                        .foregroundColor: currentColor(ctx),
                        .backgroundColor: ctx.codeBg,
                        .paragraphStyle: style
                    ]
                    if result.length > 0 {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                    }
                    result.append(NSAttributedString(string: text, attributes: attrs))
                    result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                }
                return

            case CMARK_NODE_THEMATIC_BREAK:
                result.append(NSAttributedString(string: "\n─────────\n", attributes: [
                    .font: ctx.baseFont,
                    .foregroundColor: UIColor.gray
                ]))
                return

            default:
                break
            }

            // GFM strikethrough extension node
            if typeStr == "strikethrough" {
                let wasST = ctx.isStrikethrough
                ctx.isStrikethrough = true
                renderChildren(node, ctx: &ctx)
                ctx.isStrikethrough = wasST
                return
            }

            // Handle enter/exit for container nodes
            switch nodeType {
            case CMARK_NODE_PARAGRAPH:
                if result.length > 0 {
                    let last = result.string.last
                    if last != nil && last != "\n" {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                    }
                }
                renderChildren(node, ctx: &ctx)
                return

            case CMARK_NODE_HEADING:
                let level = Int(cmark_node_get_heading_level(node))
                if result.length > 0 {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                }
                let oldLevel = ctx.headingLevel
                ctx.headingLevel = level
                renderChildren(node, ctx: &ctx)
                ctx.headingLevel = oldLevel
                return

            case CMARK_NODE_STRONG:
                let was = ctx.isBold
                ctx.isBold = true
                renderChildren(node, ctx: &ctx)
                ctx.isBold = was
                return

            case CMARK_NODE_EMPH:
                let was = ctx.isItalic
                ctx.isItalic = true
                renderChildren(node, ctx: &ctx)
                ctx.isItalic = was
                return

            case CMARK_NODE_LINK:
                if let urlC = cmark_node_get_url(node) {
                    let url = String(cString: urlC)
                    let oldURL = ctx.linkURL
                    ctx.linkURL = url
                    renderChildren(node, ctx: &ctx)
                    ctx.linkURL = oldURL
                } else {
                    renderChildren(node, ctx: &ctx)
                }
                return

            case CMARK_NODE_BLOCK_QUOTE:
                let was = ctx.isBlockquote
                ctx.isBlockquote = true
                if result.length > 0 {
                    result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                }
                renderChildren(node, ctx: &ctx)
                ctx.isBlockquote = was
                return

            case CMARK_NODE_LIST:
                let oldType = ctx.listType
                let oldIdx = ctx.listItemIndex
                ctx.listType = cmark_node_get_list_type(node)
                ctx.listItemIndex = 0
                ctx.listDepth += 1
                renderChildren(node, ctx: &ctx)
                ctx.listDepth -= 1
                ctx.listType = oldType
                ctx.listItemIndex = oldIdx
                return

            case CMARK_NODE_ITEM:
                ctx.listItemIndex += 1
                if result.length > 0 {
                    let last = result.string.last
                    if last != nil && last != "\n" {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: ctx.baseFont]))
                    }
                }
                let indent = String(repeating: "  ", count: max(0, ctx.listDepth - 1))
                let bullet: String
                if ctx.listType == CMARK_ORDERED_LIST {
                    bullet = "\(indent)\(ctx.listItemIndex). "
                } else {
                    bullet = "\(indent)• "
                }
                result.append(NSAttributedString(string: bullet, attributes: [
                    .font: ctx.baseFont,
                    .foregroundColor: currentColor(ctx)
                ]))
                renderChildren(node, ctx: &ctx)
                return

            case CMARK_NODE_IMAGE:
                if let urlC = cmark_node_get_url(node) {
                    let url = String(cString: urlC)
                    let altText = cmark_node_get_literal(cmark_node_first_child(node)).flatMap { String(cString: $0) } ?? "image"
                    result.append(NSAttributedString(string: "[\(altText)]", attributes: [
                        .font: ctx.baseFont,
                        .foregroundColor: ctx.linkColor,
                        .link: url
                    ]))
                }
                return

            case CMARK_NODE_HTML_BLOCK, CMARK_NODE_HTML_INLINE:
                if let literal = cmark_node_get_literal(node) {
                    let html = String(cString: literal)
                    // Handle <del>text</del> from GFM
                    let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    if !stripped.isEmpty {
                        result.append(NSAttributedString(string: stripped, attributes: [
                            .font: ctx.baseFont,
                            .foregroundColor: currentColor(ctx)
                        ]))
                    }
                }
                return

            default:
                renderChildren(node, ctx: &ctx)
                return
            }
        }

        func renderChildren(_ node: UnsafeMutablePointer<cmark_node>, ctx: inout RenderContext) {
            var child = cmark_node_first_child(node)
            while let c = child {
                renderNode(c, ctx: &ctx)
                child = cmark_node_next(c)
            }
        }

        renderChildren(doc, ctx: &ctx)

        // Trim trailing newlines
        while result.length > 0 {
            let last = result.attributedSubstring(from: NSRange(location: result.length - 1, length: 1)).string
            if last == "\n" || last == "\r" {
                result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
            } else {
                break
            }
        }

        return result.length > 0 ? result : nil
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

    // MARK: - Table helpers (unchanged — used by WKWebView table rendering)

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

    private static func renderInlineCellContent(_ text: String) -> String {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) else {
            return escapeHTML(text)
        }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return escapeHTML(text) }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let preLen = match.range.location - lastEnd
            if preLen > 0 {
                result += escapeHTML(nsText.substring(with: NSRange(location: lastEnd, length: preLen)))
            }
            let linkText = escapeHTML(nsText.substring(with: match.range(at: 1)))
            let url     = escapeHTML(nsText.substring(with: match.range(at: 2)))
            result += "<a href=\"\(url)\">\(linkText)</a>"
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < nsText.length {
            result += escapeHTML(nsText.substring(from: lastEnd))
        }
        return result
    }

    private static func convertTableToHTML(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }
        let hasSeparator = lines.count >= 2 && isTableSeparator(lines[1])
        var html = "<table>"
        for (idx, line) in lines.enumerated() {
            if hasSeparator && idx == 1 { continue }
            let cells = parseTableCells(line)
            let isHeader = hasSeparator && idx == 0
            let tag = isHeader ? "th" : "td"
            html += "<tr>"
            for cell in cells {
                html += "<\(tag)>\(renderInlineCellContent(cell))</\(tag)>"
            }
            html += "</tr>"
        }
        html += "</table>"
        return html
    }

    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Table extraction for WKWebView rendering

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
            if inCodeBlock { consecutiveTableLines = 0; continue }
            if isTableLine(line) {
                consecutiveTableLines += 1
                if consecutiveTableLines >= 2 { return true }
            } else {
                consecutiveTableLines = 0
            }
        }
        return false
    }

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
                i += 1; continue
            }
            if inCodeBlock { currentTextLines.append(line); i += 1; continue }
            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    let txt = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !txt.isEmpty { segments.append(["type": "text", "content": txt]) }
                    currentTextLines = []
                    let tableContent = Array(lines[i..<j]).joined(separator: "\n")
                    segments.append(["type": "table", "content": tableContent])
                    i = j; continue
                }
            }
            currentTextLines.append(line)
            i += 1
        }
        let remaining = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty { segments.append(["type": "text", "content": remaining]) }
        return segments as NSArray
    }

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
                currentTable = []; continue
            }
            if inCodeBlock { continue }
            if isTableLine(line) { currentTable.append(line) }
            else {
                if currentTable.count >= 2 { tableGroups.append(currentTable) }
                currentTable = []
            }
        }
        if currentTable.count >= 2 { tableGroups.append(currentTable) }
        if tableGroups.isEmpty { return nil }

        var tablesHTML = ""
        for tableLines in tableGroups { tablesHTML += convertTableToHTML(tableLines) }

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
                currentTextLines.append(line); i += 1; continue
            }
            if inCodeBlock { currentTextLines.append(line); i += 1; continue }
            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    if !currentTextLines.isEmpty { html += textLinesToHTML(currentTextLines); currentTextLines = [] }
                    html += convertTableToHTML(Array(lines[i..<j]))
                    i = j; continue
                }
            }
            currentTextLines.append(line); i += 1
        }
        if !currentTextLines.isEmpty { html += textLinesToHTML(currentTextLines) }
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

    @objc public static func fullContentHeight(_ text: String, fontSize: CGFloat) -> CGFloat {
        let lines = text.components(separatedBy: "\n")
        let lineHeight = fontSize * 1.4
        var height: CGFloat = 0
        var inCodeBlock = false
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { inCodeBlock = !inCodeBlock; height += lineHeight; i += 1; continue }
            if inCodeBlock { height += lineHeight; i += 1; continue }
            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 {
                    let hasSep = isTableSeparator(lines[i + 1])
                    let visibleRows = hasSep ? j - i - 1 : j - i
                    height += CGFloat(visibleRows) * 32.0 + 4.0
                    i = j; continue
                }
            }
            height += line.isEmpty ? lineHeight * 0.5 : lineHeight
            i += 1
        }
        return height
    }

    @objc public static func removeTableMarkdown(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inCodeBlock = false
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { inCodeBlock = !inCodeBlock; result.append(line); i += 1; continue }
            if inCodeBlock { result.append(line); i += 1; continue }
            if isTableLine(line) {
                var j = i
                while j < lines.count && isTableLine(lines[j]) { j += 1 }
                if j - i >= 2 { i = j; continue }
            }
            result.append(line); i += 1
        }
        return result.joined(separator: "\n")
    }

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
                    for tl in currentTableLines { if !isTableSeparator(tl) { count += 1 } }
                }
                currentTableLines = []; continue
            }
            if inCodeBlock { continue }
            if isTableLine(line) { currentTableLines.append(line) }
            else {
                if currentTableLines.count >= 2 {
                    for tl in currentTableLines { if !isTableSeparator(tl) { count += 1 } }
                }
                currentTableLines = []
            }
        }
        if currentTableLines.count >= 2 {
            for tl in currentTableLines { if !isTableSeparator(tl) { count += 1 } }
        }
        return count
    }

    // MARK: - CSS (for WKWebView table rendering only)

    private static func buildTableWebViewCSS(fontSize: CGFloat, textColorHex: String, isDark: Bool) -> String {
        let borderColor = isDark ? "#444444" : "#E0E0E0"
        let thBg = isDark ? "rgba(255,255,255,0.08)" : "#F5F5F5"
        let linkColor = isDark ? "#64B5F6" : "#5979F0"
        return """
        * { font-family: -apple-system, 'PingFang SC', sans-serif; font-size: \(fontSize)px; color: \(textColorHex); margin: 0; padding: 0; }
        body { margin: 0; padding: 0; -webkit-text-size-adjust: none; background-color: transparent; }
        table { border-collapse: collapse; width: max-content; white-space: nowrap; }
        th { font-weight: 600; padding: 10px 14px; border: 1px solid \(borderColor); text-align: left; background-color: \(thBg); }
        td { padding: 10px 14px; border: 1px solid \(borderColor); }
        a { color: \(linkColor); text-decoration: underline; }
        """
    }

    private static func buildFullContentCSS(fontSize: CGFloat, textColorHex: String, isDark: Bool) -> String {
        let thBorder = isDark ? "#666666" : "#999"
        let thBg = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.04)"
        let tdBorder = isDark ? "#444444" : "#E0E0E0"
        return """
        * { font-family: -apple-system, 'PingFang SC', sans-serif; font-size: \(fontSize)px; color: \(textColorHex); margin: 0; padding: 0; }
        body { margin: 0; padding: 0; -webkit-text-size-adjust: none; }
        .text-block { white-space: pre-wrap; line-height: 1.4; padding: 2px 0; }
        table { border-collapse: collapse; width: max-content; white-space: nowrap; margin: 4px 0; }
        th { font-weight: 600; padding: 6px 12px; border-bottom: 2px solid \(thBorder); text-align: left; background-color: \(thBg); }
        td { padding: 6px 12px; border-bottom: 1px solid \(tdBorder); }
        tr:last-child td { border-bottom: none; }
        """
    }

    private static func textLinesToHTML(_ lines: [String]) -> String {
        let joined = lines.joined(separator: "\n")
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        var escaped = escapeHTML(trimmed)
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            escaped = boldRegex.stringByReplacingMatches(in: escaped, options: [], range: NSRange(escaped.startIndex..., in: escaped), withTemplate: "<strong>$1</strong>")
        }
        return "<div class=\"text-block\">\(escaped.replacingOccurrences(of: "\n", with: "<br>"))</div>"
    }

    // MARK: - Task list helpers (for WKWebView rendering path)

    private static func isTaskListLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("- [ ] ")
    }

    private static func convertTaskListToHTML(_ lines: [String]) -> String {
        var html = "<ul style=\"list-style:none;padding-left:4px;\">"
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let checked = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
            let text = String(trimmed.dropFirst(6))
            let checkbox = checked ? "☑" : "☐"
            let style = checked ? "color:gray;text-decoration:line-through;" : ""
            html += "<li>\(checkbox) <span style=\"\(style)\">\(escapeHTML(text))</span></li>"
        }
        html += "</ul>"
        return html
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
