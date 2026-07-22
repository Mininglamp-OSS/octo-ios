//
//  SwiftMarkDownHTMLGenerator.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/19/24.
//

import Foundation

// MARK: - Types and Enums

enum SwiftDelimiterType {
    case initType, alphanumeric, punctuation, escape, whiteSpace, underscore, asterisk
}

enum SwiftMarkDownBlockType {
    case containerBlock, unorderedList, orderedList
}

extension Character {
    var isSpace: Bool { return self.isWhitespace }
    var isPunctuation: Bool {
        return CharacterSet.punctuationCharacters.contains(self.unicodeScalars.first!)
    }
    var isAlnum: Bool { return self.isLetter || self.isNumber }
}

// MARK: - HTML Generator Classes

class SwiftMarkDownHtmlGenerator {
    var token: String
    var isHead: Bool = false
    var isTail: Bool = false
    var tags: [String] = []
    
    init(token: String) {
        self.token = token
    }
    
    func makeItHead() { isHead = true }
    func makeItTail() { isTail = true }
    
    func generateHtmlString() -> String {
        fatalError("Must override in subclass")
    }
    
    func getBlockType() -> SwiftMarkDownBlockType { .containerBlock }
}

class SwiftMarkDownStringHtmlGenerator: SwiftMarkDownHtmlGenerator {
    override func generateHtmlString() -> String {
        var result = token
        if isHead { result = "<p>" + result }
        if isTail { result += "</p>" }
        return result
    }
}

class SwiftMarkDownNewLineHtmlGenerator: SwiftMarkDownStringHtmlGenerator {
    override func generateHtmlString() -> String { super.generateHtmlString() }
}

class SwiftMarkDownEmphasisHtmlGenerator: SwiftMarkDownHtmlGenerator {
    var numberOfUnusedDelimiters: Int
    var directionType: Int = 1  // 0 = left; 1 = right
    var type: SwiftDelimiterType
    
    init(token: String, sizeOfEmphasisDelimiterRun: Int, type: SwiftDelimiterType, tags: [String] = []) {
        self.numberOfUnusedDelimiters = sizeOfEmphasisDelimiterRun
        self.type = type
        super.init(token: token)
        self.tags = tags
    }
    
    func isRightEmphasis() -> Bool { return directionType == 1 }
    func isLeftEmphasis() -> Bool { return directionType == 0 }
    func isLeftAndRightEmphasis() -> Bool { return false }
    
    func pushItalicTag() { tags.append("<em>") }
    func pushBoldTag() { tags.append("<strong>") }
    
    func isMatch(_ emphasisToken: SwiftMarkDownEmphasisHtmlGenerator) -> Bool {
        if self.type == emphasisToken.type {
            if (self.isLeftAndRightEmphasis() || emphasisToken.isLeftAndRightEmphasis()) &&
                ((self.numberOfUnusedDelimiters + emphasisToken.numberOfUnusedDelimiters) % 3 == 0) {
                return false
            }
            return true
        }
        return false
    }
    
    func adjustEmphasisCounts(leftOver: Int, rightToken: SwiftMarkDownEmphasisHtmlGenerator) -> Int {
        let delimiterCount: Int
        if leftOver >= 0 {
            delimiterCount = self.numberOfUnusedDelimiters - leftOver
            self.numberOfUnusedDelimiters = leftOver
            rightToken.numberOfUnusedDelimiters = 0
        } else {
            delimiterCount = self.numberOfUnusedDelimiters
            rightToken.numberOfUnusedDelimiters = -leftOver
            self.numberOfUnusedDelimiters = 0
        }
        return delimiterCount
    }
    
    func generateTags(with token: SwiftMarkDownEmphasisHtmlGenerator) -> Bool {
        let leftOver = self.numberOfUnusedDelimiters - token.numberOfUnusedDelimiters
        let delimiterCount = adjustEmphasisCounts(leftOver: leftOver, rightToken: token)
        let hasHtmlTags = delimiterCount > 0
        if delimiterCount % 2 != 0 {
            self.pushItalicTag()
            token.pushItalicTag()
        }
        for _ in 0..<(delimiterCount / 2) {
            self.pushBoldTag()
            token.pushBoldTag()
        }
        return hasHtmlTags
    }
    
    func changeDirectionToLeft() { self.directionType = 0 }
    
    func isSameType(_ other: SwiftMarkDownEmphasisHtmlGenerator) -> Bool {
        return self.type == other.type
    }
    
    func isDone() -> Bool { return self.numberOfUnusedDelimiters == 0 }
    
    override func generateHtmlString() -> String {
        var html = ""
        if isHead { html += "<p>" }
        html += tags.joined()
        if numberOfUnusedDelimiters > 0 {
            html += String(token.suffix(numberOfUnusedDelimiters))
        }
        if isTail { html += "</p>" }
        return html
    }
}

class SwiftMarkDownLeftEmphasisHtmlGenerator: SwiftMarkDownEmphasisHtmlGenerator {
    override func isLeftEmphasis() -> Bool { return true }
    override func generateHtmlString() -> String {
        var html = ""
        if isHead { html += "<p>" }
        if numberOfUnusedDelimiters > 0 { html += String(token.suffix(numberOfUnusedDelimiters)) }
        html += tags.reversed().joined()
        if isTail { html += "</p>" }
        return html
    }
}

class SwiftMarkDownRightEmphasisHtmlGenerator: SwiftMarkDownEmphasisHtmlGenerator {
    override func isRightEmphasis() -> Bool { return directionType == 1 }
    override func isLeftEmphasis() -> Bool { return directionType == 0 }
    override func generateHtmlString() -> String {
        var html = ""
        if isHead { html += "<p>" }
        html += tags.joined()
        if numberOfUnusedDelimiters > 0 { html += String(token.suffix(numberOfUnusedDelimiters)) }
        if isTail { html += "</p>" }
        return html
    }
    override func pushItalicTag() { tags.append("</em>") }
    override func pushBoldTag() { tags.append("</strong>") }
}

class SwiftMarkDownLeftAndRightEmphasisHtmlGenerator: SwiftMarkDownRightEmphasisHtmlGenerator {
    override func isLeftAndRightEmphasis() -> Bool { return true }
    override func pushItalicTag() { tags.append(directionType == 0 ? "<em>" : "</em>") }
    override func pushBoldTag() { tags.append(directionType == 0 ? "<strong>" : "</strong>") }
}

class SwiftMarkDownListHtmlGenerator: SwiftMarkDownStringHtmlGenerator {
    override func generateHtmlString() -> String {
        var result = token
        if isHead { result = "<ul>" + result }
        if isTail { result += "</ul>" }
        return result
    }
    override func getBlockType() -> SwiftMarkDownBlockType { return .unorderedList }
}

class SwiftMarkDownOrderedListHtmlGenerator: SwiftMarkDownStringHtmlGenerator {
    var numberString: String
    init(token: String, numberString: String) {
        self.numberString = numberString
        super.init(token: token)
    }
    override func generateHtmlString() -> String {
        var result = token
        if isHead { result = "<ol start=\"\(numberString)\">" + result }
        if isTail { result += "</ol>" }
        return result
    }
    override func getBlockType() -> SwiftMarkDownBlockType { return .orderedList }
}

class SwiftMarkDownAnchorHtmlGenerator: SwiftMarkDownHtmlGenerator {
    var href: String
    var linkText: String
    init(linkText: String, href: String) {
        self.linkText = linkText
        self.href = href
        super.init(token: "")
    }
    override func generateHtmlString() -> String {
        var html = ""
        if isHead { html += "<p>" }
        html += "<a href=\"\(href)\">\(linkText)</a>"
        if isTail { html += "</p>" }
        return html
    }
}

// MARK: - String Iterator

struct SwiftStringIterator {
    let text: [Character]
    var index: Int = 0
    init(_ text: String) { self.text = Array(text) }
    mutating func next() -> Character? {
        guard index < text.count else { return nil }
        let ch = text[index]
        index += 1
        return ch
    }
    func peek() -> Character? {
        return index < text.count ? text[index] : nil
    }
    mutating func putBack() {
        if index > 0 { index -= 1 }
    }
    var isAtEnd: Bool { return index >= text.count }
}

// MARK: - Block Parsing Protocol

protocol SwiftMarkDownBlockParser {
    var parsedResult: SwiftMarkDownParsedResult { get set }
    func match(stream: inout SwiftStringIterator)
}

extension SwiftMarkDownBlockParser {
    mutating func parseBlock(stream: inout SwiftStringIterator) {
        guard let peekChar = stream.peek() else { return }
        switch peekChar {
        case "[":
            var linkParser = SwiftLinkParser()
            linkParser.match(stream: &stream)
            parsedResult.appendParseResult(linkParser.parsedResult)
        case "]", ")":
            if let ch = stream.next() { parsedResult.addNewTokenToParsedResult(ch) }
        case "\n", "\r":
            if let ch = stream.next() { parsedResult.addNewLineTokenToParsedResult(ch) }
        case "-", "+", "*":
            var listParser = SwiftListParser()
            listParser.match(stream: &stream)
            parsedResult.appendParseResult(listParser.parsedResult)
        case "0"..."9":
            var orderedListParser = SwiftOrderedListParser()
            orderedListParser.match(stream: &stream)
            parsedResult.appendParseResult(orderedListParser.parsedResult)
        default:
            var emphasisParser = SwiftEmphasisParser()
            emphasisParser.match(stream: &stream)
            parsedResult.appendParseResult(emphasisParser.getParsedResult())
        }
    }
}

// MARK: - EmphasisParser

class SwiftEmphasisParser: SwiftMarkDownBlockParser {
    var parsedResult = SwiftMarkDownParsedResult()
    private var currentToken: String = ""
    private var lookBehind: Character? = nil

    /// Returns true if the delimiter is valid for emphasis.
    private func isValidDelimiter(_ ch: Character, previous: Character?, next: Character?) -> Bool {
        if ch == "_" {
            // For underscore, if both adjacent are alnum, do not treat as emphasis.
            if let pre = previous, let fol = next, pre.isAlnum && fol.isAlnum { return false }
            if let fol = next, fol.isSpace { return false }
        } else if ch == "*" {
            // For asterisk, if the previous is alnum and next is punctuation, treat it as literal.
            if let pre = previous, pre.isAlnum, let fol = next, fol.isPunctuation { return false }
        }
        return true
    }

    func match(stream: inout SwiftStringIterator) {
        while let ch = stream.peek() {
            if ch == "\\" {
                _ = stream.next()
                if let escaped = stream.next() {
                    currentToken.append(escaped)
                    lookBehind = escaped
                }
            } else if ch == "*" || ch == "_" {
                flushToken()
                let delimChar = ch
                let (delimStr, count) = consumeDelimiterRun(stream: &stream, delimiter: delimChar)
                let prev = lookBehind
                let next = stream.peek()
                let canOpen = (next != nil && !next!.isSpace) && (prev == nil || prev!.isSpace || prev!.isPunctuation)
                let canClose = (prev != nil && !prev!.isSpace) && (next == nil || next!.isSpace || next!.isPunctuation)
                if !isValidDelimiter(delimChar, previous: prev, next: next) {
                    currentToken.append(delimStr)
                    lookBehind = delimStr.last
                    continue
                }
                let direction: Int
                if canClose && !canOpen {
                    direction = 1
                } else if canOpen && !canClose {
                    direction = 0
                } else {
                    if delimChar == "_" {
                        direction = (prev != nil && prev!.isAlnum) ? 1 : 0
                    } else {
                        direction = 0
                    }
                }
                var emphasisToken = SwiftMarkDownLeftAndRightEmphasisHtmlGenerator(token: delimStr, sizeOfEmphasisDelimiterRun: count, type: (delimChar == "*" ? .asterisk : .underscore))
                emphasisToken.directionType = direction
                parsedResult.appendToLookUpTable(emphasisToken)
                parsedResult.appendToTokens(emphasisToken)
                lookBehind = delimChar
            } else if isSpecialChar(ch) {
                flushToken()
                if let special = stream.next() {
                    parsedResult.addNewTokenToParsedResult(special)
                    lookBehind = special
                }
            } else {
                currentToken.append(stream.next()!)
                lookBehind = currentToken.last
            }
        }
        flushToken()
    }
    
    private func flushToken() {
        if !currentToken.isEmpty {
            parsedResult.addNewTokenToParsedResult(currentToken)
            currentToken = ""
        }
    }
    
    private func consumeDelimiterRun(stream: inout SwiftStringIterator, delimiter: Character) -> (String, Int) {
        var delimStr = ""
        var count = 0
        while let ch = stream.peek(), ch == delimiter {
            delimStr.append(stream.next()!)
            count += 1
        }
        return (delimStr, count)
    }
    
    private func isSpecialChar(_ ch: Character) -> Bool {
        return ch == "[" || ch == "]" || ch == "(" || ch == ")" || ch == "\n" || ch == "\r"
    }
    
    func getParsedResult() -> SwiftMarkDownParsedResult { return parsedResult }
}

// MARK: - LinkParser

struct SwiftLinkParserConstants {
    static let openingBracket: Character = "["
    static let closingBracket: Character = "]"
    static let openingParen: Character = "("
    static let closingParen: Character = ")"
}

class SwiftLinkParser: SwiftMarkDownBlockParser {
    var parsedResult = SwiftMarkDownParsedResult()
    func match(stream: inout SwiftStringIterator) {
        guard let ch = stream.next(), ch == SwiftLinkParserConstants.openingBracket else { return }
        var linkText = ""
        // In link text, we do not process emphasis.
        while let c = stream.peek(), c != SwiftLinkParserConstants.closingBracket {
            linkText.append(stream.next()!)
        }
        guard stream.next() != nil else {
            parsedResult.addNewTokenToParsedResult("[" + linkText)
            return
        }
        guard let next = stream.peek(), next == SwiftLinkParserConstants.openingParen else {
            parsedResult.addNewTokenToParsedResult("[" + linkText + "]")
            return
        }
        _ = stream.next() // consume '('
        var url = ""
        while let c = stream.peek(), c != SwiftLinkParserConstants.closingParen {
            if c == "\\" {
                _ = stream.next()
                if let esc = stream.next() { url.append(esc) }
            } else {
                url.append(stream.next()!)
            }
        }
        _ = stream.next() // consume ')'
        let innerHtml = SwiftMarkDownParser(linkText).transformToHtml()
        let trimmed = innerHtml.replacingOccurrences(of: "^<p>|</p>$", with: "", options: .regularExpression)
        let anchorToken = SwiftMarkDownAnchorHtmlGenerator(linkText: trimmed, href: url)
        parsedResult.appendToTokens(anchorToken)
    }
}

// MARK: - ListParser

class SwiftListParser: SwiftMarkDownBlockParser {
    var parsedResult = SwiftMarkDownParsedResult()
    func match(stream: inout SwiftStringIterator) {
        guard let marker = stream.next() else { return }
        if stream.peek() != " " {
            stream.putBack()
            var emphasisParser = SwiftEmphasisParser()
            emphasisParser.match(stream: &stream)
            parsedResult.appendParseResult(emphasisParser.getParsedResult())
            return
        }
        _ = stream.next() // consume space
        var items: [String] = []
        repeat {
            var listText = ""
            while let c = stream.peek(), c != "\n", c != "\r" {
                listText.append(stream.next()!)
            }
            items.append("<li>" + listText + "</li>")
            while let c = stream.peek(), c == "\n" || c == "\r" { _ = stream.next() }
        } while stream.peek() == marker
        let combined = items.joined()
        let listToken = SwiftMarkDownListHtmlGenerator(token: combined)
        listToken.makeItHead(); listToken.makeItTail()
        parsedResult.appendToTokens(listToken)
    }
}

// MARK: - OrderedListParser

class SwiftOrderedListParser: SwiftMarkDownBlockParser {
    var parsedResult = SwiftMarkDownParsedResult()
    func match(stream: inout SwiftStringIterator) {
        let startIndex = stream.index
        var numberString = ""
        while let c = stream.peek(), c.isNumber {
            numberString.append(stream.next()!)
        }
        guard let dot = stream.peek(), dot == "." else {
            stream.index = startIndex
            var emphasisParser = SwiftEmphasisParser()
            emphasisParser.match(stream: &stream)
            parsedResult.appendParseResult(emphasisParser.getParsedResult())
            return
        }
        _ = stream.next() // consume '.'
        if let space = stream.peek(), space == " " { _ = stream.next() }
        let startNumber = numberString
        var items: [String] = []
        repeat {
            var listText = ""
            while let c = stream.peek(), c != "\n", c != "\r" {
                listText.append(stream.next()!)
            }
            items.append("<li>" + listText + "</li>")
            while let c = stream.peek(), c == "\n" || c == "\r" { _ = stream.next() }
            var tempIndex = stream.index
            var nextNumber = ""
            while let c = stream.peek(), c.isNumber {
                nextNumber.append(stream.next()!)
            }
            if let dot = stream.peek(), dot == "." {
                stream.index = tempIndex
            } else {
                stream.index = tempIndex; break
            }
        } while true
        let combined = items.joined()
        let orderedToken = SwiftMarkDownOrderedListHtmlGenerator(token: combined, numberString: startNumber)
        orderedToken.makeItHead(); orderedToken.makeItTail()
        parsedResult.appendToTokens(orderedToken)
    }
}

// MARK: - Parsed Result

class SwiftMarkDownParsedResult {
    var codeGenTokens: [SwiftMarkDownHtmlGenerator] = []
    var emphasisLookUpTable: [SwiftMarkDownEmphasisHtmlGenerator] = []
    private var isHTMLTagsAdded: Bool = false
    private var isCaptured: Bool = false
    
    func translate() {
        matchLeftAndRightEmphasises()
    }
    
    func addBlockTags() {
        codeGenTokens.first?.makeItHead()
        codeGenTokens.last?.makeItTail()
    }
    
    private func markTags(_ x: SwiftMarkDownHtmlGenerator) {
        if let lastToken = codeGenTokens.last, lastToken.getBlockType() != x.getBlockType() {
            if lastToken.generateHtmlString().last == "\n" { codeGenTokens.removeLast() }
            if !codeGenTokens.isEmpty { codeGenTokens.last?.makeItTail() }
            x.makeItHead()
        }
    }
    
    func appendParseResult(_ other: SwiftMarkDownParsedResult) {
        if !codeGenTokens.isEmpty, !other.codeGenTokens.isEmpty {
            markTags(other.codeGenTokens.first!)
        }
        codeGenTokens.append(contentsOf: other.codeGenTokens)
        emphasisLookUpTable.append(contentsOf: other.emphasisLookUpTable)
        isHTMLTagsAdded = isHTMLTagsAdded || other.hasHtmlTags()
        isCaptured = other.isCaptured
    }
    
    func appendToTokens(_ token: SwiftMarkDownHtmlGenerator) {
        if !codeGenTokens.isEmpty { markTags(token) }
        codeGenTokens.append(token)
    }
    
    func appendToLookUpTable(_ token: SwiftMarkDownEmphasisHtmlGenerator) {
        emphasisLookUpTable.append(token)
    }
    
    func popFront() { if !codeGenTokens.isEmpty { codeGenTokens.removeFirst() } }
    func popBack() { if !codeGenTokens.isEmpty { codeGenTokens.removeLast() } }
    func clear() { codeGenTokens.removeAll(); emphasisLookUpTable.removeAll() }
    
    func addNewTokenToParsedResult(_ ch: Character) {
        let token = SwiftMarkDownStringHtmlGenerator(token: String(ch))
        appendToTokens(token)
    }
    
    func addNewTokenToParsedResult(_ word: String) {
        let token = SwiftMarkDownStringHtmlGenerator(token: word)
        appendToTokens(token)
    }
    
    func addNewLineTokenToParsedResult(_ ch: Character) {
        let token = SwiftMarkDownNewLineHtmlGenerator(token: String(ch))
        appendToTokens(token)
    }
    
    func generateHtmlString() -> String {
        return codeGenTokens.map { $0.generateHtmlString() }.joined()
    }
    
    private func matchLeftAndRightEmphasises() {
        var leftEmphasisToExplore: [SwiftMarkDownEmphasisHtmlGenerator] = []
        var currentEmphasisIndex = 0
        while currentEmphasisIndex < emphasisLookUpTable.count {
            let currentEmphasis = emphasisLookUpTable[currentEmphasisIndex]
            if currentEmphasis.isLeftEmphasis() ||
                (currentEmphasis.isLeftAndRightEmphasis() && leftEmphasisToExplore.isEmpty) {
                if currentEmphasis.isLeftAndRightEmphasis() && currentEmphasis.isRightEmphasis() {
                    currentEmphasis.changeDirectionToLeft()
                }
                leftEmphasisToExplore.append(currentEmphasis)
                currentEmphasisIndex += 1
            } else if !leftEmphasisToExplore.isEmpty {
                let currentLeftEmphasis = leftEmphasisToExplore.removeLast()
                if !currentLeftEmphasis.isMatch(currentEmphasis) {
                    var isFound = false
                    var storedLeftTokens: [SwiftMarkDownEmphasisHtmlGenerator] = []
                    while !leftEmphasisToExplore.isEmpty && !isFound {
                        let leftToken = leftEmphasisToExplore.removeLast()
                        if leftToken.isMatch(currentEmphasis) {
                            isFound = true
                            leftEmphasisToExplore.append(leftToken)
                        } else {
                            storedLeftTokens.append(leftToken)
                        }
                    }
                    if !isFound, let lastLeft = leftEmphasisToExplore.last, lastLeft.isSameType(currentEmphasis) {
                        currentEmphasis.changeDirectionToLeft()
                    } else {
                        for token in storedLeftTokens.reversed() {
                            leftEmphasisToExplore.append(token)
                        }
                        currentEmphasisIndex += 1
                        continue
                    }
                }
                isHTMLTagsAdded = currentLeftEmphasis.generateTags(with: currentEmphasis) || isHTMLTagsAdded
                currentLeftEmphasis.numberOfUnusedDelimiters = 0
                currentEmphasis.numberOfUnusedDelimiters = 0
                if currentEmphasis.isDone() { currentEmphasisIndex += 1 }
            } else {
                currentEmphasisIndex += 1
            }
        }
    }
    
    func hasHtmlTags() -> Bool { return isHTMLTagsAdded }
    func foundHtmlTags() { isHTMLTagsAdded = true }
    func getIsCaptured() -> Bool { return isCaptured }
    func setIsCaptured(_ val: Bool) { isCaptured = val }
    
    func lastPlainTextCharacter() -> Character? {
        for token in codeGenTokens.reversed() {
            if let stringToken = token as? SwiftMarkDownStringHtmlGenerator, !stringToken.token.isEmpty {
                return stringToken.token.last
            }
        }
        return nil
    }
}

// MARK: - Main Parser

public class SwiftMarkDownParser {
    private let text: String
    private var parsedResult = SwiftMarkDownParsedResult()
    private var hasHTMLTag: Bool = false
    private var isEscaped: Bool = false
    
    public init(_ text: String) { self.text = text }
    
    public func transformToHtml() -> String {
        if text.isEmpty { return "<p></p>" }
        parseBlock()
        parsedResult.translate()
        parsedResult.addBlockTags()
        hasHTMLTag = parsedResult.hasHtmlTags()
        return parsedResult.generateHtmlString()
    }
    
    public func getRawText() -> String { return text }
    public func hasHtmlTags() -> Bool { return hasHTMLTag }
    public func isEscapedText() -> Bool { return isEscaped }
    
    private func parseBlock() {
        let escapedText = escapeText()
        var stream = SwiftStringIterator(escapedText)
        while stream.peek() != nil {
            switch stream.peek()! {
            case "[":
                var linkParser = SwiftLinkParser()
                linkParser.match(stream: &stream)
                parsedResult.appendParseResult(linkParser.parsedResult)
            case "]", ")":
                if let ch = stream.next() { parsedResult.addNewTokenToParsedResult(ch) }
            case "\n", "\r":
                if let ch = stream.next() { parsedResult.addNewLineTokenToParsedResult(ch) }
            case "-", "+", "*":
                var listParser = SwiftListParser()
                listParser.match(stream: &stream)
                parsedResult.appendParseResult(listParser.parsedResult)
            case "0"..."9":
                var orderedListParser = SwiftOrderedListParser()
                orderedListParser.match(stream: &stream)
                parsedResult.appendParseResult(orderedListParser.parsedResult)
            default:
                var emphasisParser = SwiftEmphasisParser()
                emphasisParser.match(stream: &stream)
                parsedResult.appendParseResult(emphasisParser.getParsedResult())
            }
        }
    }
    
    private func escapeText() -> String {
        var escaped = ""
        var nonEscapedCounts = 0
        for char in text {
            switch char {
            case "<": escaped.append("&lt;")
            case ">": escaped.append("&gt;")
            case "\"": escaped.append("&quot;")
            case "&": escaped.append("&amp;")
            default:
                escaped.append(char)
                nonEscapedCounts += 1
            }
        }
        isEscaped = (nonEscapedCounts != text.count)
        return escaped
    }
}
