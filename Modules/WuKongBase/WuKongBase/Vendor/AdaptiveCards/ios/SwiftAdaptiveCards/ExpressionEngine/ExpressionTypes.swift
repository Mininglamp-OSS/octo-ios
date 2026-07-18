//
//  ExpressionTypes.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Type Aliases

public typealias EvaluationResult = Any?
public typealias FunctionCallback = @Sendable ([Any?]) async throws -> EvaluationResult
public typealias Token = String
public typealias BinaryOperatorToken = String

public enum BinaryOperatorType: String, CaseIterable {
    case addition = "+"
    case subtraction = "-"
    case multiplication = "*"
    case division = "/"
    case equality = "=="
    case inequality = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case logicalAnd = "&&"
    case logicalOr = "||"
    case inclusion = "in"
    
    init?(from token: BinaryOperatorToken) {
        self.init(rawValue: token)
    }
    
    static func isValid(_ token: BinaryOperatorToken) -> Bool {
        return BinaryOperatorType(rawValue: token) != nil
    }
}

// MARK: - Core Protocols

public protocol EvaluationNode {
    func evaluate(context: EvaluationContext) async throws -> EvaluationResult
}

public protocol ExpressionCacheable {
    func isOutdated() -> Bool
}

public protocol FunctionProvider {
    var functions: [String: FunctionDeclaration] { get }
    func getFunction(name: String) -> FunctionDeclaration?
}

// MARK: - Expression Engine Protocols

/// Protocol for evaluating expressions
public protocol ExpressionEvaluating {
    func evaluate(_ expression: String, with data: Any?) async -> EvaluationResult
    func evaluateBinding(_ template: String, with data: Any?) async -> EvaluationResult
}

/// Protocol for creating expressions and bindings
public protocol ExpressionCreating {
    func createExpression(_ expression: String, allowAssignment: Bool) throws -> Expression
    func createBinding(_ template: String) throws -> Binding
}

/// Protocol for managing evaluation contexts
public protocol ContextManaging {
    func createContext(with data: Any?) async -> EvaluationContext
    func createDefaultContext(with data: Any?) async -> EvaluationContext
}

/// Protocol for bridging to Objective-C
public protocol ObjCBridging {
    func callEvaluationFromObjC(expression: Expression, context: EvaluationContext?) async -> EvaluationResultWrapper
}

/// Main protocol that combines all expression engine capabilities
public protocol ExpressionEngineProtocol: ExpressionEvaluating, ExpressionCreating, ContextManaging, ObjCBridging {
    var version: String { get }
    var buildDate: String { get }
}
