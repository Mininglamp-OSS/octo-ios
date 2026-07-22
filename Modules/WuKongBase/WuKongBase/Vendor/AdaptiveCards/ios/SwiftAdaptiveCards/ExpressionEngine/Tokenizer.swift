//
//  Tokenizer.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Tokenizer

public class Tokenizer {
    // Rules are processed in order. More specific rules must come first.
    public static let rules: [TokenizerRule] = {
        do {
            return [
                try TokenizerRule(tokenType: nil, pattern: "^\\s+"),
                try TokenizerRule(tokenType: "${", pattern: "^\\$\\{"),
                try TokenizerRule(tokenType: "?#", pattern: "^\\?#"),
                try TokenizerRule(tokenType: "}", pattern: "^\\}"),
                try TokenizerRule(tokenType: "[", pattern: "^\\["),
                try TokenizerRule(tokenType: "]", pattern: "^\\]"),
                try TokenizerRule(tokenType: "(", pattern: "^\\("),
                try TokenizerRule(tokenType: ")", pattern: "^\\)"),
                try TokenizerRule(tokenType: "boolean", pattern: "^true|^false"),
                try TokenizerRule(tokenType: ".", pattern: "^\\."),
                try TokenizerRule(tokenType: ",", pattern: "^,"),
                try TokenizerRule(tokenType: "+", pattern: "^\\+"),
                try TokenizerRule(tokenType: "-", pattern: "^-"),
                try TokenizerRule(tokenType: "*", pattern: "^\\*"),
                try TokenizerRule(tokenType: "/", pattern: "^/"),
                try TokenizerRule(tokenType: "==", pattern: "^=="),
                try TokenizerRule(tokenType: "!=", pattern: "^!="),
                try TokenizerRule(tokenType: "<=", pattern: "^<="),
                try TokenizerRule(tokenType: "<", pattern: "^<"),
                try TokenizerRule(tokenType: ">=", pattern: "^>="),
                try TokenizerRule(tokenType: ">", pattern: "^>"),
                try TokenizerRule(tokenType: "&&", pattern: "^&&"),
                try TokenizerRule(tokenType: "||", pattern: "^\\|\\|"),
                try TokenizerRule(tokenType: "in", pattern: "^in\\b"),
                try TokenizerRule(tokenType: "string", pattern: "^\"([^\"]*)\""),
                try TokenizerRule(tokenType: "string", pattern: "^'([^']*)'"),
                try TokenizerRule(tokenType: "number", pattern: "^\\d*\\.?\\d+"),
                try TokenizerRule(tokenType: "identifier", pattern: "^[_a-zA-Z$][_a-zA-Z0-9$]*")
            ]
        } catch {
            // If any regex pattern is invalid, fall back to empty rules array
            // This should never happen in practice with valid patterns
            fatalError("Failed to initialize tokenizer rules: \(error)")
        }
    }()
    
    public static func parse(expression: String) throws -> [TokenInfo] {
        var result: [TokenInfo] = []
        var i = 0
        
        while i < expression.count {
            let startIndex = expression.index(expression.startIndex, offsetBy: i)
            let subExpression = String(expression[startIndex...])
            var matchFound = false
            
            for rule in rules {
                let range = NSRange(location: 0, length: subExpression.count)
                if let match = rule.regEx.firstMatch(in: subExpression, options: [], range: range),
                   match.range.location == 0 {
                    
                    if match.numberOfRanges > 2 {
                        throw TokenizerError.tooManyGroups("A tokenizer rule matched more than one group.")
                    }
                    
                    if let tokenType = rule.tokenType {
                        let value: String
                        if match.numberOfRanges > 1 {
                            let groupRange = match.range(at: 1)
                            if groupRange.location != NSNotFound {
                                let groupStartIndex = subExpression.index(subExpression.startIndex, offsetBy: groupRange.location)
                                let groupEndIndex = subExpression.index(groupStartIndex, offsetBy: groupRange.length)
                                value = String(subExpression[groupStartIndex..<groupEndIndex])
                            } else {
                                let matchStartIndex = subExpression.index(subExpression.startIndex, offsetBy: match.range.location)
                                let matchEndIndex = subExpression.index(matchStartIndex, offsetBy: match.range.length)
                                value = String(subExpression[matchStartIndex..<matchEndIndex])
                            }
                        } else {
                            let matchStartIndex = subExpression.index(subExpression.startIndex, offsetBy: match.range.location)
                            let matchEndIndex = subExpression.index(matchStartIndex, offsetBy: match.range.length)
                            value = String(subExpression[matchStartIndex..<matchEndIndex])
                        }
                        result.append(TokenInfo(type: tokenType, value: value, originalPosition: i))
                    }
                    
                    i += match.range.length
                    matchFound = true
                    break
                }
            }
            
            if !matchFound {
                let charIndex = expression.index(expression.startIndex, offsetBy: i)
                let char = expression[charIndex]
                throw TokenizerError.unexpectedCharacter("Unexpected character \"\(char)\" at position \(i).")
            }
        }
        return result
    }
}
