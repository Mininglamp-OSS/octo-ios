//
//  ExpressionErrors.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Error Types

public enum EvaluationError: Error, LocalizedError {
    case invalidOperand(String)
    case incompatibleOperator(String)
    case incompatibleTypes(String)
    case unsupportedOperation(String)
    case invalidPath(String)
    case undefinedVariable(String)
    case noStateToRestore
    case unknownFunction(String)
    case invalidParameters([Any?])
    case executionFailed(Error)
    case cacheMiss
    
    public var errorDescription: String? {
        switch self {
        case .invalidOperand(let message):
            return "Invalid operand: \(message)"
        case .incompatibleOperator(let message):
            return "Incompatible operator: \(message)"
        case .incompatibleTypes(let message):
            return "Incompatible types: \(message)"
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        case .invalidPath(let message):
            return "Invalid path: \(message)"
        case .undefinedVariable(let message):
            return "Undefined variable: \(message)"
        case .noStateToRestore:
            return "No state to restore"
        case .unknownFunction(let name):
            return "Unknown function: \(name)"
        case .invalidParameters(let params):
            return "Invalid parameters: \(params)"
        case .executionFailed(let error):
            return "Function execution failed: \(error.localizedDescription)"
        case .cacheMiss:
            return "Cache miss"
        }
    }
}

public enum TokenizerError: Error, LocalizedError {
    case invalidRegexPattern(String)
    case tooManyGroups(String)
    case unexpectedCharacter(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidRegexPattern(let message):
            return "Invalid regex pattern: \(message)"
        case .tooManyGroups(let message):
            return "Too many groups: \(message)"
        case .unexpectedCharacter(let message):
            return "Unexpected character: \(message)"
        }
    }
}

public enum ExpressionError: Error, LocalizedError {
    case bindingReturnedNull(String)
    
    public var errorDescription: String? {
        switch self {
        case .bindingReturnedNull(let message):
            return "Binding returned null: \(message)"
        }
    }
}

public enum EvaluationContextError: Error, LocalizedError {
    case unknownFunction(String)
    
    public var errorDescription: String? {
        switch self {
        case .unknownFunction(let message):
            return "Unknown function: \(message)"
        }
    }
}

public enum BuiltInFunctionError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidDate(String)
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .invalidDate(let message):
            return "Invalid date: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
