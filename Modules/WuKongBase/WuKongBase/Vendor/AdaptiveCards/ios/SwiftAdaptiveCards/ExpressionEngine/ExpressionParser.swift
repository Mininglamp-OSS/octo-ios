//
//  ExpressionParser.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - ExpressionParser

public class ExpressionParser {
    
    private let arithmeticOperatorTokens = ["+", "-", "*", "/"]
    private let comparisonOperatorTokens = ["==", "!=", "<", "<=", ">", ">=", "&&", "||"]
    private let membershipOperatorTokens = ["in"]
    
    private var binaryOperatorTokens: [String] {
        return arithmeticOperatorTokens + comparisonOperatorTokens + membershipOperatorTokens
    }
    
    private let tokens: [TokenInfo]
    private var index = 0
    
    private var eof: Bool {
        return index >= tokens.count
    }
    
    private var current: TokenInfo? {
        guard index < tokens.count else { return nil }
        return tokens[index]
    }
    
    public init(expression: String) throws {
        self.tokens = try Tokenizer.parse(expression: expression)
    }
    
    // MARK: - Parsing Utilities
    
    private func moveNext() {
        index += 1
    }
    
    private func parseToken(_ expectedTokenTypes: Token...) throws -> TokenInfo {
        guard let curr = current else {
            throw TokenizerError.unexpectedCharacter("Unexpected end of expression.")
        }
        if !expectedTokenTypes.contains(curr.type) {
            throw TokenizerError.unexpectedCharacter("Unexpected token \(curr.value) at position \(curr.originalPosition). Expected one of: \(expectedTokenTypes)")
        }
        moveNext()
        return curr
    }
    
    private func parseOptionalToken(_ expectedTokenTypes: Token...) -> Bool {
    guard let curr = current, expectedTokenTypes.contains(curr.type) else { return false }
    moveNext()
    return true
    }
    
    // MARK: - Node Parsing Methods
    
    private func parseFunctionCall(functionName: String) throws -> FunctionCallNode {
        let result = FunctionCallNode(functionName: functionName)
        _ = try parseToken("(")
        if let curr = current, curr.type != ")" {
            result.addParameter(try parseExpression())
            while parseOptionalToken(",") {
                result.addParameter(try parseExpression())
            }
        }
        _ = try parseToken(")")
        return result
    }
    
    private func parseIdentifier() throws -> IdentifierNode {
        let token = try parseToken("identifier")
        return IdentifierNode(identifier: token.value)
    }
    
    private func parseIndexer() throws -> IndexerNode {
        let result = IndexerNode()
        _ = try parseToken("[")
        result.index = try parseExpression()
        _ = try parseToken("]")
        return result
    }
    
    private func parseArray() throws -> ArrayNode {
        let result = ArrayNode()
        _ = try parseToken("[")
        if let curr = current, curr.type != "]" {
            result.addItem(try parseExpression())
            while parseOptionalToken(",") {
                result.addItem(try parseExpression())
            }
        }
        _ = try parseToken("]")
        return result
    }
    
    private func parsePath() throws -> PathNode {
        let result = PathNode()
        var expectedNextTokenTypes: [Token] = ["identifier", "("]
        var canEnd = false
        while let curr = current {
            if !expectedNextTokenTypes.contains(curr.type) {
                if result.isEmpty || !canEnd {
                    throw TokenizerError.unexpectedCharacter("Unexpected token \(curr.value) at position \(curr.originalPosition).")
                } else {
                    return result
                }
            }
            canEnd = false
            switch curr.type {
            case "(":
                if result.isEmpty {
                    moveNext()
                    result.addPart(try parseExpression())
                    _ = try parseToken(")")
                } else {
                    let functionName = result.getIdentifierNames().joined(separator: ".")
                    result.clearParts()
                    result.addPart(try parseFunctionCall(functionName: functionName))
                }
                expectedNextTokenTypes = [".", "["]
                canEnd = true
            case "[":
                result.addPart(try parseIndexer())
                expectedNextTokenTypes = [".", "(", "["]
                canEnd = true
            case "identifier":
                result.addPart(try parseIdentifier())
                expectedNextTokenTypes = [".", "(", "["]
                canEnd = true
            case ".":
                moveNext()
                expectedNextTokenTypes = ["identifier"]
                canEnd = false
            default:
                throw TokenizerError.unexpectedCharacter("Unexpected token \(curr.value) at position \(curr.originalPosition).")
            }
        }
        if !result.isEmpty && canEnd { return result }
        return result
    }
    
    private func parsePrimary() throws -> EvaluationNode {
        guard let curr = current else {
            throw TokenizerError.unexpectedCharacter("Unexpected end of expression.")
        }
        switch curr.type {
        case "identifier", "(":
            return try parsePath()
        case "[":
            return try parseArray()
        case "string":
            let value = curr.value
            moveNext()
            return LiteralNode(value: value)
        case "number":
            let value = Double(curr.value) ?? 0.0
            moveNext()
            return LiteralNode(value: value)
        case "boolean":
            let value = curr.value == "true"
            moveNext()
            return LiteralNode(value: value)
        default:
            throw TokenizerError.unexpectedCharacter("Unexpected token \(curr.value) at position \(curr.originalPosition).")
        }
    }
    
    // MARK: - Main Parsing Methods
    
    public func parseExpression() throws -> ExpressionNode {
        let result = ExpressionNode()
        if parseOptionalToken("-") {
            result.addNode(LiteralNode(value: -1.0))
            result.addNode(BinaryOperatorNode(operatorType: .multiplication))
        } else {
            _ = parseOptionalToken("+")
        }
        result.addNode(try parsePrimary())
        while let curr = current, binaryOperatorTokens.contains(curr.type) {
            guard let operatorType = BinaryOperatorType(from: curr.type) else {
                throw TokenizerError.unexpectedCharacter("Invalid binary operator '\(curr.type)' at position \(curr.originalPosition).")
            }
            result.addNode(BinaryOperatorNode(operatorType: operatorType))
            moveNext()
            if parseOptionalToken("-") {
                result.addNode(LiteralNode(value: -1.0))
                result.addNode(BinaryOperatorNode(operatorType: .multiplication))
            } else {
                _ = parseOptionalToken("+")
            }
            result.addNode(try parsePrimary())
        }
        return result
    }
    
    public func parse() throws -> ExpressionNode {
        let result = try parseExpression()
        if !eof {
            throw TokenizerError.unexpectedCharacter("Unexpected end of expression.")
        }
        return result
    }
    
    public func parseBinding() throws -> (ExpressionNode, Bool) {
        _ = try parseToken("${")
        let allowNull = parseOptionalToken("?#")
        let expression = try parseExpression()
        _ = try parseToken("}")
        if !eof {
            throw TokenizerError.unexpectedCharacter("Unexpected end of expression.")
        }
        return (expression, allowNull)
    }
}
