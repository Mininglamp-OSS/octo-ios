// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLaTeXPreprocessor.swift
//  WuKongBase
//
//  LaTeX → Markdown 预处理 + 数学段抽取。CoCraft 等机器人会直接把
//  LaTeX 文档片段（\subsection{} / \textbf{} / \begin{quote} / 行内数学）
//  发到群里，cmark-gfm 不认识这些命令。本预处理把命令降级到 Markdown，
//  数学段抽成 \u{FFFC} (Object Replacement Character) 占位符，由
//  WKMarkdownRenderer 渲染后再由 OC 端把占位符替换成等宽样式的 TeX 源文本
//  (Phase 1) 或 iosMath 渲染的图片附件 (Phase 2)。
//
//  关键约束：不引入 WebView；不破坏现有 mention / link / token / cache 链路。
//

import Foundation
import UIKit
import iosMath

private let kMathPlaceholderScalar: Unicode.Scalar = Unicode.Scalar(0xFFFC)!
private let kMathPlaceholderChar: Character = Character(kMathPlaceholderScalar)
private let kMathPlaceholderString = String(kMathPlaceholderChar)

@objc public class WKLaTeXMathSegment: NSObject {
    @objc public let tex: String
    @objc public let isDisplay: Bool
    @objc public init(tex: String, isDisplay: Bool) {
        self.tex = tex
        self.isDisplay = isDisplay
    }
}

@objc public class WKLaTeXPreprocessResult: NSObject {
    @objc public let markdown: String
    @objc public let mathSegments: [WKLaTeXMathSegment]
    @objc public init(markdown: String, mathSegments: [WKLaTeXMathSegment]) {
        self.markdown = markdown
        self.mathSegments = mathSegments
    }
}

@objc public class WKLaTeXPreprocessor: NSObject {

    // MARK: - Detection

    @objc public static func containsLaTeX(_ text: String) -> Bool {
        if text.isEmpty { return false }
        let patterns = [
            #"\\(?:section|subsection|subsubsection|paragraph|textbf|textit|emph|texttt|underline|begin|end|label|ref|cite|item|textbar|textbackslash|par)\b"#,
            #"\\[\(\)\[\]]"#
        ]
        let nsRange = NSRange(text.startIndex..., in: text)
        for p in patterns {
            if let re = try? NSRegularExpression(pattern: p),
               re.firstMatch(in: text, options: [], range: nsRange) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Preprocess

    @objc public static func preprocess(_ text: String) -> WKLaTeXPreprocessResult {
        var segments: [WKLaTeXMathSegment] = []
        var s = extractMath(text, into: &segments)
        s = stripMetaCommands(s)
        s = transformEnvironments(s)
        s = transformSections(s)
        s = transformAtomicInline(s)
        s = transformBraceBalancedFormat(s)
        s = transformFallbackUnknown(s)
        s = cleanupWhitespace(s)
        return WKLaTeXPreprocessResult(markdown: s, mathSegments: segments)
    }

    // MARK: - Math extraction (Step 1)

    private static func extractMath(_ text: String, into segments: inout [WKLaTeXMathSegment]) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        let chars = Array(text)
        let n = chars.count
        var i = 0

        func emit(_ tex: String, isDisplay: Bool) {
            segments.append(WKLaTeXMathSegment(tex: tex, isDisplay: isDisplay))
            out.append(kMathPlaceholderChar)
        }

        while i < n {
            let c = chars[i]

            // P1: $$ ... $$  (display)
            if c == "$" && i + 1 < n && chars[i + 1] == "$" {
                if let endIdx = findDelimiterPair(chars, from: i + 2, openerLen: 2, isCloser: { j in
                    chars[j] == "$" && j + 1 < n && chars[j + 1] == "$"
                }) {
                    let tex = String(chars[(i + 2)..<endIdx])
                    emit(tex, isDisplay: true)
                    i = endIdx + 2
                    continue
                }
                // unmatched $$ → literal
                out.append("$$")
                i += 2
                continue
            }

            // P2: \[ ... \]  (display)
            if c == "\\" && i + 1 < n && chars[i + 1] == "[" {
                if let endIdx = findDelimiterPair(chars, from: i + 2, openerLen: 2, isCloser: { j in
                    chars[j] == "\\" && j + 1 < n && chars[j + 1] == "]"
                }) {
                    let tex = String(chars[(i + 2)..<endIdx])
                    emit(tex, isDisplay: true)
                    i = endIdx + 2
                    continue
                }
            }

            // P3: \( ... \)  (inline)
            if c == "\\" && i + 1 < n && chars[i + 1] == "(" {
                if let endIdx = findDelimiterPair(chars, from: i + 2, openerLen: 2, isCloser: { j in
                    chars[j] == "\\" && j + 1 < n && chars[j + 1] == ")"
                }) {
                    let tex = String(chars[(i + 2)..<endIdx])
                    emit(tex, isDisplay: false)
                    i = endIdx + 2
                    continue
                }
            }

            // P4: $ ... $  (inline, single line, no nested $)
            if c == "$" {
                var j = i + 1
                var found = -1
                while j < n {
                    if chars[j] == "\n" { break }
                    if chars[j] == "$" { found = j; break }
                    j += 1
                }
                if found > i + 1 {
                    let tex = String(chars[(i + 1)..<found])
                    emit(tex, isDisplay: false)
                    i = found + 1
                    continue
                }
            }

            // P5: ( ... ) heuristic — inner contains \[a-zA-Z]+ command, no paragraph break
            if c == "(" {
                if let endIdx = balancedParensEnd(chars, start: i) {
                    let inner = String(chars[(i + 1)..<endIdx])
                    if containsTeXCommand(inner) {
                        emit(inner, isDisplay: false)
                        i = endIdx + 1
                        continue
                    }
                }
            }

            out.append(c)
            i += 1
        }
        return out
    }

    /// Scan forward from `start` looking for a delimiter pair. Returns the index of
    /// the first matching closer. Returns nil if not found within the same paragraph
    /// (`\n\n` breaks the scan).
    private static func findDelimiterPair(_ chars: [Character], from start: Int, openerLen: Int, isCloser: (Int) -> Bool) -> Int? {
        let n = chars.count
        var j = start
        while j < n {
            if chars[j] == "\n" && j + 1 < n && chars[j + 1] == "\n" { return nil }
            if isCloser(j) { return j }
            j += 1
        }
        return nil
    }

    /// Returns index of matching `)` for `(` at `start`. Depth-counted, does not cross `\n\n`.
    private static func balancedParensEnd(_ chars: [Character], start: Int) -> Int? {
        let n = chars.count
        var depth = 0
        var i = start
        while i < n {
            let c = chars[i]
            if c == "\n" && i + 1 < n && chars[i + 1] == "\n" { return nil }
            if c == "(" { depth += 1 }
            else if c == ")" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    private static func containsTeXCommand(_ s: String) -> Bool {
        var prevBackslash = false
        for c in s {
            if prevBackslash && c.isLetter { return true }
            prevBackslash = (c == "\\")
        }
        return false
    }

    // MARK: - Strip metas (Step 2)

    private static func stripMetaCommands(_ text: String) -> String {
        var s = text
        s = regexReplace(s, pattern: #"\\(?:label|ref|cite|bibliography|maketitle|tableofcontents)\{[^}]*\}"#, with: "")
        s = regexReplace(s, pattern: #"\\(?:pagebreak|newpage|noindent|hfill|vfill|smallskip|medskip|bigskip)\b"#, with: "")
        return s
    }

    // MARK: - Environments (Step 3)

    private static func transformEnvironments(_ text: String) -> String {
        var s = text
        // 反复跑直到没有 \begin{...}\end{...} 残留——惰性 .*? 配合多轮迭代 = 从内到外。
        guard let re = try? NSRegularExpression(
            pattern: #"\\begin\{([a-zA-Z*]+)\}(.*?)\\end\{\1\}"#,
            options: [.dotMatchesLineSeparators]
        ) else { return s }

        var iter = 0
        while iter < 32 {
            let ns = s as NSString
            let matches = re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            if matches.isEmpty { break }
            var working = ns
            for m in matches.reversed() {
                let envName = working.substring(with: m.range(at: 1))
                let body = working.substring(with: m.range(at: 2))
                let replaced = transformEnvBody(envName: envName, body: body)
                working = working.replacingCharacters(in: m.range, with: replaced) as NSString
            }
            let newS = working as String
            if newS == s { break }
            s = newS
            iter += 1
        }
        return s
    }

    private static func transformEnvBody(envName: String, body: String) -> String {
        switch envName {
        case "quote", "quotation":
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "\n\n" }
            let lines = trimmed.components(separatedBy: "\n")
            let quoted = lines.map { "> " + $0 }.joined(separator: "\n")
            return "\n\n" + quoted + "\n\n"
        case "itemize":
            return convertItemList(body, ordered: false)
        case "enumerate":
            return convertItemList(body, ordered: true)
        case "verbatim", "lstlisting":
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\n\n```\n" + trimmed + "\n```\n\n"
        case "center", "flushleft", "flushright":
            return body
        default:
            // 未知环境：保内容、丢标记。
            return body
        }
    }

    private static func convertItemList(_ body: String, ordered: Bool) -> String {
        let parts = body.components(separatedBy: "\\item")
        var items: [String] = []
        for (idx, raw) in parts.enumerated() {
            if idx == 0 { continue }
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.isEmpty { continue }
            items.append(item)
        }
        if items.isEmpty { return "\n\n" }
        var lines: [String] = []
        for (idx, item) in items.enumerated() {
            let prefix = ordered ? "\(idx + 1). " : "- "
            lines.append(prefix + item)
        }
        return "\n\n" + lines.joined(separator: "\n") + "\n\n"
    }

    // MARK: - Sections (Step 4)

    private static func transformSections(_ text: String) -> String {
        var s = text
        // 长前缀先匹配，避免 \section 误命中 \subsection。
        let mapping: [(String, String)] = [
            ("paragraph", "#### "),
            ("subsubsection", "### "),
            ("subsection", "## "),
            ("section", "# ")
        ]
        for (cmd, prefix) in mapping {
            s = replaceCommandWithBraceArg(s, command: cmd) { arg in
                return "\n\n" + prefix + arg.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
            }
        }
        return s
    }

    // MARK: - Atomic inline (Step 5)

    private static func transformAtomicInline(_ text: String) -> String {
        var s = text
        // 顺序敏感：长形式先做（\textbar{} 在 \textbar 之前）。
        // 用规则字符串（双反斜杠转义），避免 raw string 跟 # 起冲突。
        let atomics: [(String, String)] = [
            ("\\\\textbar\\{\\}", "|"),
            ("\\\\textbar\\b", "|"),
            ("\\\\textbackslash\\{\\}", "\\\\"),
            ("\\\\textbackslash\\b", "\\\\"),
            ("\\\\par\\b", "\n\n"),
            ("\\\\\\\\", "\n\n"),            // LaTeX \\ 行内换行
            ("\\\\&", "&"),
            ("\\\\%", "%"),
            ("\\\\#", "#"),
            ("\\\\_", "_"),
            ("\\\\\\{", "{"),
            ("\\\\\\}", "}"),
            ("\\\\\\$", "$"),
            ("~", "\u{00A0}")
        ]
        for (pat, rep) in atomics {
            s = regexReplace(s, pattern: pat, with: rep)
        }
        return s
    }

    // MARK: - Brace-balanced format commands (Step 6)

    private static func transformBraceBalancedFormat(_ text: String) -> String {
        var s = text
        // 嵌套支持：多轮直到稳定。
        let mapping: [(String, (String) -> String)] = [
            ("textbf", { "**" + $0 + "**" }),
            ("textit", { "*" + $0 + "*" }),
            ("emph", { "*" + $0 + "*" }),
            ("texttt", { "`" + $0 + "`" }),
            ("underline", { $0 })
        ]
        var iter = 0
        while iter < 16 {
            var changed = false
            for (cmd, transform) in mapping {
                let next = replaceCommandWithBraceArg(s, command: cmd, transform: transform)
                if next != s {
                    s = next
                    changed = true
                }
            }
            if !changed { break }
            iter += 1
        }
        return s
    }

    // MARK: - Fallback unknown (Step 7)

    private static func transformFallbackUnknown(_ text: String) -> String {
        var s = text
        var iter = 0
        while iter < 16 {
            let next = stripUnknownBracedCommandOnce(s)
            if next == s { break }
            s = next
            iter += 1
        }
        // 剩余无参 \cmd → 丢弃
        s = regexReplace(s, pattern: #"\\[a-zA-Z]+\b"#, with: "")
        return s
    }

    private static func stripUnknownBracedCommandOnce(_ text: String) -> String {
        let chars = Array(text)
        let n = chars.count
        var out = ""
        out.reserveCapacity(n)
        var i = 0
        while i < n {
            if chars[i] == "\\" && i + 1 < n && chars[i + 1].isLetter {
                var j = i + 1
                while j < n && chars[j].isLetter { j += 1 }
                let cmdName = String(chars[(i + 1)..<j])
                if j < n && chars[j] == "{" {
                    if let (arg, endIdx) = extractBraceArg(chars, openBraceIdx: j) {
                        #if DEBUG
                        NSLog("[LaTeXPreprocessor] unknown braced cmd: \\%@ (kept content)", cmdName)
                        #endif
                        out.append(arg)
                        i = endIdx + 1
                        continue
                    }
                }
                // 无 brace 参数 → 留给最后一轮 \cmd → "" 处理
                out.append("\\")
                out.append(contentsOf: cmdName)
                i = j
                continue
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    // MARK: - Whitespace cleanup

    private static func cleanupWhitespace(_ text: String) -> String {
        var s = text
        s = regexReplace(s, pattern: "\n{3,}", with: "\n\n")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Brace helpers

    /// 在 text 中查找 `\command{...}` 并用 transform 替换。command 后必须不接字母
    /// （避免 \sub 误中 \subsection）。brace-balanced 匹配，支持嵌套。
    private static func replaceCommandWithBraceArg(_ text: String, command: String, transform: (String) -> String) -> String {
        let chars = Array(text)
        let n = chars.count
        let needle = Array("\\" + command)
        let needleLen = needle.count
        var out = ""
        out.reserveCapacity(n)
        var i = 0
        while i < n {
            if i + needleLen < n {
                var match = true
                for k in 0..<needleLen {
                    if chars[i + k] != needle[k] { match = false; break }
                }
                if match {
                    let after = chars[i + needleLen]
                    if !after.isLetter && after == "{" {
                        if let (arg, endIdx) = extractBraceArg(chars, openBraceIdx: i + needleLen) {
                            out.append(transform(arg))
                            i = endIdx + 1
                            continue
                        }
                    }
                }
            }
            out.append(chars[i])
            i += 1
        }
        return out
    }

    /// 从 `{` 开始按深度匹配到对应的 `}`，处理 `\{` `\}` 转义。返回 (内容, `}` 下标)。
    private static func extractBraceArg(_ chars: [Character], openBraceIdx: Int) -> (String, Int)? {
        let n = chars.count
        guard openBraceIdx < n, chars[openBraceIdx] == "{" else { return nil }
        var depth = 0
        var i = openBraceIdx
        while i < n {
            let c = chars[i]
            if c == "\\" && i + 1 < n {
                i += 2  // 跳过转义字符（\{ \} \\ 等）
                continue
            }
            if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 {
                    let arg = String(chars[(openBraceIdx + 1)..<i])
                    return (arg, i)
                }
            }
            i += 1
        }
        return nil
    }

    private static func regexReplace(_ s: String, pattern: String, with replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return s }
        let range = NSRange(s.startIndex..., in: s)
        let escaped = NSRegularExpression.escapedTemplate(for: replacement)
        return re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: escaped)
    }

    // MARK: - Math placeholder replacement (Phase 2: iosMath 图片 + Phase 1 monospace 回退)

    /// 在 attr 里把所有 \u{FFFC} 占位符（按出现顺序对应 segments）替换成：
    ///   优先：iosMath 渲染的数学公式图片（NSTextAttachment，基线对齐）
    ///   失败：等宽字体 + 浅背景的 TeX 源文本（Phase 1 回退）
    /// 占位符所在 run 的段落样式 + 前景色都会被继承，确保嵌在 heading/quote/list 时
    /// 行高与悬挂缩进与现有 markdown 一致。
    @objc public static func replaceMathPlaceholdersIn(_ attr: NSMutableAttributedString,
                                                       segments: [WKLaTeXMathSegment],
                                                       fontSize: CGFloat,
                                                       isDark: Bool) {
        guard segments.count > 0, attr.length > 0 else { return }
        let codeFont = UIFont(name: "Menlo", size: fontSize - 1)
            ?? UIFont(name: "Courier", size: fontSize - 1)
            ?? UIFont.systemFont(ofSize: fontSize - 1)
        let codeBg: UIColor = isDark
            ? UIColor(white: 1, alpha: 0.1)
            : UIColor(white: 0, alpha: 0.06)
        let fallbackColor: UIColor = isDark ? .white : .black

        let ns = attr.string as NSString
        var positions: [Int] = []
        var search = NSRange(location: 0, length: ns.length)
        while search.length > 0 {
            let r = ns.range(of: kMathPlaceholderString, options: [], range: search)
            if r.location == NSNotFound { break }
            positions.append(r.location)
            search.location = r.location + r.length
            search.length = ns.length - search.location
        }

        let count = min(positions.count, segments.count)
        // 从后往前替换，确保前面位置不被偏移。
        for idx in stride(from: count - 1, through: 0, by: -1) {
            let pos = positions[idx]
            let seg = segments[idx]
            let runAttrs = attr.attributes(at: pos, effectiveRange: nil)
            let textColor = (runAttrs[.foregroundColor] as? UIColor) ?? fallbackColor
            let paraStyle = runAttrs[.paragraphStyle] as? NSParagraphStyle

            let replacement: NSAttributedString
            if let mathResult = WKMathImageRenderer.render(tex: seg.tex,
                                                           fontSize: fontSize,
                                                           textColor: textColor,
                                                           isDisplay: seg.isDisplay) {
                replacement = makeMathAttachmentString(mathResult,
                                                       isDisplay: seg.isDisplay,
                                                       paragraphStyle: paraStyle)
            } else {
                replacement = makeMonospaceFallbackString(seg: seg,
                                                          codeFont: codeFont,
                                                          codeBg: codeBg,
                                                          runAttrs: runAttrs)
            }
            attr.replaceCharacters(in: NSRange(location: pos, length: 1), with: replacement)
        }
    }

    /// 用 iosMath 图片构造一个 NSTextAttachment。基线偏移用 displayList 提供的
    /// descent，让数学公式跟周围中文/英文文本的 baseline 自然对齐。
    private static func makeMathAttachmentString(_ result: WKMathImageResult,
                                                  isDisplay: Bool,
                                                  paragraphStyle: NSParagraphStyle?) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = result.image
        // bounds.origin.y 是 baseline 相对位置（负数 = 向下穿过基线）。
        // 用 -descent 让公式底部恰好等于文本 descent 线。
        attachment.bounds = CGRect(x: 0,
                                   y: -result.descent,
                                   width: result.width,
                                   height: result.ascent + result.descent)
        let attachmentStr = NSAttributedString(attachment: attachment)
        let mutable = NSMutableAttributedString(attributedString: attachmentStr)
        if let ps = paragraphStyle {
            mutable.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: mutable.length))
        }
        if isDisplay {
            // display 公式独占一行：前后包换行
            let result = NSMutableAttributedString()
            result.append(NSAttributedString(string: "\n"))
            result.append(mutable)
            result.append(NSAttributedString(string: "\n"))
            if let ps = paragraphStyle {
                result.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: result.length))
            }
            return result
        }
        return mutable
    }

    /// Phase 1 回退：等宽样式 TeX 源文本。
    private static func makeMonospaceFallbackString(seg: WKLaTeXMathSegment,
                                                     codeFont: UIFont,
                                                     codeBg: UIColor,
                                                     runAttrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attrs = runAttrs
        attrs[.font] = codeFont
        attrs[.backgroundColor] = codeBg
        let body = seg.isDisplay ? " $$" + seg.tex + "$$ " : " $" + seg.tex + "$ "
        return NSAttributedString(string: body, attributes: attrs)
    }
}
