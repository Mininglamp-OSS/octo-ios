//
//  ExpressionModels.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - Configuration and Options

public struct ExpressionOptions: Sendable {
    public let allowAssignment: Bool
    
    public init(allowAssignment: Bool = false) {
        self.allowAssignment = allowAssignment
    }
}

/// A Sendable-safe box for a non-Sendable `Any?` value.
/// This uses a closure to capture the value, making it safe to pass across concurrency domains.
/// The original value is preserved exactly without any type conversion.
public struct SendableAnyBox: Sendable {
    private let _unbox: @Sendable () -> Any?

    public init(_ value: Any?) {
        // Store the original value directly without any conversion
        // This preserves integers, nested dictionaries, and all original types
        self._unbox = { value }
    }

    public func unbox() -> Any? {
        return _unbox()
    }
}

public struct EvaluationContextConfig: Sendable {
    public let groupId: String?
    // The stored property is now Sendable.
    private let rootBox: SendableAnyBox?
    public let functions: [FunctionDeclaration]

    /// The public `root` property returns the original value without any conversion.
    /// This preserves the exact optional semantics and data types from the original input.
    public var root: Any? {
        return rootBox?.unbox()
    }

    public init(groupId: String? = nil, root: Any? = nil, functions: [FunctionDeclaration] = []) {
        self.groupId = groupId
        // Store without conversion - preserve original types including integers
        self.rootBox = root.map(SendableAnyBox.init)
        self.functions = functions
    }
}

// MARK: - Function and Cache Models

public struct FunctionDeclaration: Sendable {
    public let name: String
    public let cacheResultFor: Int64? // Cache duration in milliseconds
    public let callback: FunctionCallback
    
    public init(name: String, cacheResultFor: Int64? = nil, callback: @escaping FunctionCallback) {
        self.name = name
        self.cacheResultFor = cacheResultFor
        self.callback = callback
    }
}

// MARK: - Context State

public struct ContextState: Sendable {
    public let data: SendableValue?
    public let index: Int
    public let variableScope: [String: SendableValue]
    
    public init(data: SendableValue? = nil, index: Int = 0, variableScope: [String: SendableValue] = [:]) {
        self.data = data
        self.index = index
        self.variableScope = variableScope
    }
}

// MARK: - Sendable Value Wrapper

public enum SendableValue: Sendable {
    case string(String)
    case number(Double)
    case integer(Int64)
    case boolean(Bool)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case null
    
    public var anyValue: Any? {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .integer(let value): return value
        case .boolean(let value): return value
        case .array(let values): return values.map { $0.anyValue }
        case .dictionary(let dict): return dict.mapValues { $0.anyValue }
        case .null: return nil
        }
    }
    
    // Made internal - implementation detail for converting Any to SendableValue
    internal static func from(_ value: Any?) -> SendableValue {
        guard let value = value else { return .null }
        
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFNumberIsFloatType(number) {
                return .number(number.doubleValue)
            } else {
                return .integer(number.int64Value)
            }
        case let double as Double:
            return .number(double)
        case let int as Int:
            return .integer(Int64(int))
        case let int64 as Int64:
            return .integer(int64)
        case let bool as Bool:
            return .boolean(bool)
        case let array as [Any?]:
            return .array(array.map { SendableValue.from($0) })
        case let dict as [String: Any?]:
            return .dictionary(dict.mapValues { SendableValue.from($0) })
        default:
            return .string(String(describing: value))
        }
    }
}

// MARK: - Token Models

public struct TokenizerRule: Sendable {
    public let tokenType: Token?
    // Made internal - implementation detail for regex matching
    internal let regEx: NSRegularExpression
    
    public init(tokenType: Token?, pattern: String) throws {
        do {
            self.tokenType = tokenType
            self.regEx = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            throw TokenizerError.invalidRegexPattern(pattern)
        }
    }
}

public struct TokenInfo: Sendable {
    public let type: Token
    public let value: String
    public let originalPosition: Int
    
    public init(type: Token, value: String, originalPosition: Int) {
        self.type = type
        self.value = value
        self.originalPosition = originalPosition
    }
}

// MARK: - Evaluation Models

public struct EvaluationResultWrapper: Sendable {
    // Made internal - wrapped value accessed via anyValue
    internal let value: SendableValue
    
    public init(value: Any?) {
        self.value = SendableValue.from(value)
    }
    
    // Made internal - factory method for internal use
    internal static func from(result: EvaluationResult) -> EvaluationResultWrapper {
        return EvaluationResultWrapper(value: result)
    }
    
    public var anyValue: Any? {
        return value.anyValue
    }
}

public struct EvaluationContextState: Sendable {
    // Made internal - wrapped values accessed via anyData
    internal let data: SendableValue?
    internal let index: Int
    
    public init(data: Any?, index: Int) {
        self.data = SendableValue.from(data)
        self.index = index
    }
    
    public var anyData: Any? {
        return data?.anyValue
    }
}
