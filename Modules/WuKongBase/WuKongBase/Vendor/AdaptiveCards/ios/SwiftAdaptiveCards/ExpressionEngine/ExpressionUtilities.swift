//
//  ExpressionUtilities.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

import Foundation

// MARK: - ExpressionUtilities

/// Utility struct providing type conversion and comparison operations for expression evaluation
public struct ExpressionUtilities {

    // MARK: - Type Assertion

    /// Ensures proper type handling for expression evaluation values
    /// - Parameter value: The value to assert type for
    /// - Returns: The value with proper type assertion applied
    public static func assertValueType(value: Any?) -> Any? {
        if let newVal = value as? [String: Any], !(value is [Any]) {
            return newVal
        }
        return value
    }

    // MARK: - Type Conversions

    /// Safely converts any value to a Double number
    /// - Parameter value: The value to convert
    /// - Returns: Double representation if conversion is possible, nil otherwise
    public static func toNumber(_ value: Any?) -> Double? {
        if let num = value as? NSNumber {
            return num.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        return nil
    }

    /// Safely converts any value to a Boolean
    /// - Parameter value: The value to convert
    /// - Returns: Boolean representation
    public static func toBool(_ value: Any?) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        return false
    }

    // MARK: - Comparison Operations

    /// Performs equality comparison between two values
    /// - Parameters:
    ///   - lhs: Left-hand side value
    ///   - rhs: Right-hand side value
    /// - Returns: true if values are considered equal, false otherwise
    public static func areEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        if lhs == nil && rhs == nil { return true }
        if lhs == nil || rhs == nil { return false }
        
        if let lhsObj = lhs as? NSObject, let rhsObj = rhs as? NSObject {
            return lhsObj.isEqual(rhsObj)
        }
        
        return String(describing: lhs) == String(describing: rhs)
    }

    /// Compares two values and returns comparison result
    /// - Parameters:
    ///   - lhs: Left-hand side value
    ///   - rhs: Right-hand side value
    /// - Returns: -1 if lhs < rhs, 0 if equal, 1 if lhs > rhs
    /// - Throws: EvaluationError.incompatibleTypes if values cannot be compared
    public static func compareValues(_ lhs: any Comparable, _ rhs: Any) throws -> Int {
        // Handle numeric comparisons (Int, Double, NSNumber)
        if let lhsNum = toNumber(lhs), let rhsNum = toNumber(rhs) {
            if lhsNum < rhsNum { return -1 }
            if lhsNum > rhsNum { return 1 }
            return 0
        }
        
        // Handle string comparisons
        if let rhsComp = rhs as? String, let lhsString = lhs as? String {
            return lhsString.compare(rhsComp).rawValue
        }
        
        throw EvaluationError.incompatibleTypes("Cannot compare incompatible types: \(type(of: lhs)) vs \(type(of: rhs))")
    }
}
