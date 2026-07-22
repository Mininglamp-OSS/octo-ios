//
//  Expression.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//


import Foundation

// MARK: - Expression

public class Expression {
    private let rootNode: ExpressionNode
    private var assignResultTo: String?
    
    public init(expressionString: String, options: ExpressionOptions? = nil) throws {
        var finalExpression = expressionString
        let allowAssignment = options?.allowAssignment ?? false
        self.assignResultTo = nil
        
        if allowAssignment {
            let identifierAssignmentPattern = "^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*:=\\s*"
            let regex = try NSRegularExpression(pattern: identifierAssignmentPattern, options: [])
            let range = NSRange(location: 0, length: expressionString.count)
            
            if let match = regex.firstMatch(in: expressionString, options: [], range: range) {
                let matchRange = match.range(at: 1)
                if matchRange.location != NSNotFound {
                    let startIndex = expressionString.index(expressionString.startIndex, offsetBy: matchRange.location)
                    let endIndex = expressionString.index(startIndex, offsetBy: matchRange.length)
                    self.assignResultTo = String(expressionString[startIndex..<endIndex])
                    
                    let remainingStartIndex = expressionString.index(expressionString.startIndex, offsetBy: match.range.location + match.range.length)
                    finalExpression = String(expressionString[remainingStartIndex...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        let parser = try ExpressionParser(expression: finalExpression)
        self.rootNode = try parser.parse()
    }
    
    /// Evaluates the expression and returns a Result indicating success or failure
    public func evaluateResult(context: EvaluationContext? = nil) async -> Result<EvaluationResult, Error> {
        let evaluationContext: EvaluationContext
        if let context = context {
            evaluationContext = context
        } else {
            evaluationContext = await EvaluationContext(config: nil)
        }
        
        do {
            let result = try await rootNode.evaluate(context: evaluationContext)
            if let assignTo = assignResultTo {
                await evaluationContext.setVariable(assignTo, value: result)
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
}
