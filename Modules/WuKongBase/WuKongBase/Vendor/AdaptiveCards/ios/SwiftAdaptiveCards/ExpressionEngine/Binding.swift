//
//  Binding.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Binding

public class Binding {
    private let expressionNode: ExpressionNode
    private let allowNull: Bool
    private let expressionString: String
    
    public init(expressionString: String) throws {
        self.expressionString = expressionString
        let parser = try ExpressionParser(expression: expressionString)
        let (expr, allow) = try parser.parseBinding()
        self.expressionNode = expr
        self.allowNull = allow
    }
    
    public func evaluate(context: EvaluationContext? = nil) async throws -> EvaluationResult {
        var evaluationContext: EvaluationContext
        if let context = context {
            evaluationContext = context
        } else {
            evaluationContext = await EvaluationContext(config: nil)
        }

        do {
            let result = try await expressionNode.evaluate(context: evaluationContext)
            if !allowNull && result == nil {
                throw ExpressionError.bindingReturnedNull("Binding expression '\(expressionString)' returned null but allowNull is false.")
            }
            return result
        } catch let error as EvaluationError {
            // If allowNull is true, we should suppress undefinedVariable errors and return nil.
            if case .undefinedVariable = error, allowNull {
                return nil
            }
            // Otherwise, rethrow the original error.
            throw error
        }
    }
}
