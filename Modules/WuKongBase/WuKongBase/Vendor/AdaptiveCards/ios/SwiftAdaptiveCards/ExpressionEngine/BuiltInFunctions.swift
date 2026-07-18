//
//  BuiltInFunctions.swift
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//


import Foundation

// MARK: - Core Protocols

public protocol FunctionCategory {
    var functions: [String: FunctionDeclaration] { get }
    var categoryName: String { get }
}

// MARK: - Error Handling

public enum FunctionError: Error, CustomStringConvertible {
    case invalidParameterCount(expected: Int, actual: Int)
    case invalidParameterType(parameter: Int, expected: String, actual: String)
    case executionError(String)
    case functionNotFound(String)

   public var description: String {
        switch self {
        case .invalidParameterCount(let expected, let actual):
            return "Expected \(expected) parameters, got \(actual)"
        case .invalidParameterType(let param, let expected, let actual):
            return "Parameter \(param): expected \(expected), got \(actual)"
        case .executionError(let message):
            return "Execution error: \(message)"
        case .functionNotFound(let name):
            return "Function '\(name)' not found"
        }
    }
}

// MARK: - Parameter Validation

public struct ParameterValidator {
    
    public init() {}
    
   public static func validateCount(_ params: [Any?], expected: Int) throws {
        guard params.count == expected else {
            throw FunctionError.invalidParameterCount(expected: expected, actual: params.count)
        }
    }
    
    public static func validateMinCount(_ params: [Any?], minimum: Int) throws {
        guard params.count >= minimum else {
            throw FunctionError.invalidParameterCount(expected: minimum, actual: params.count)
        }
    }
    
    public static func extractNumber(_ param: Any?, at index: Int) throws -> Double {
        guard let number = param as? NSNumber else {
            throw FunctionError.invalidParameterType(
                parameter: index,
                expected: "Number",
                actual: String(describing: type(of: param))
            )
        }
        return number.doubleValue
    }
    
    public static func extractString(_ param: Any?, at index: Int) throws -> String {
        guard let string = param as? String else {
            throw FunctionError.invalidParameterType(
                parameter: index,
                expected: "String",
                actual: String(describing: type(of: param))
            )
        }
        return string
    }
    
    public static func extractInt(_ param: Any?, at index: Int) throws -> Int {
        guard let number = param as? NSNumber else {
            throw FunctionError.invalidParameterType(
                parameter: index,
                expected: "Integer",
                actual: String(describing: type(of: param))
            )
        }
        return number.intValue
    }
}

// MARK: - Math Functions

public class MathFunctions: FunctionCategory {
    public let categoryName = "Math"
    
    public init() {}
    
    public var functions: [String: FunctionDeclaration] {
        return [
            "round": FunctionDeclaration(name: "round", callback: roundFunction),
            "ceil": FunctionDeclaration(name: "ceil", callback: ceilFunction),
            "floor": FunctionDeclaration(name: "floor", callback: floorFunction)
        ]
    }
    
    private let roundFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let value = try ParameterValidator.extractNumber(params[0], at: 0)
        return Foundation.round(value)
    }
    
    private let ceilFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let value = try ParameterValidator.extractNumber(params[0], at: 0)
        return Foundation.ceil(value)
    }
    
    private let floorFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let value = try ParameterValidator.extractNumber(params[0], at: 0)
        return Foundation.floor(value)
    }
}

// MARK: - String Functions

public class StringFunctions: FunctionCategory {
    public let categoryName = "String"
    
    public init() {}
    
    public var functions: [String: FunctionDeclaration] {
        return [
            "toUpper": FunctionDeclaration(name: "toUpper", callback: toUpperFunction),
            "toLower": FunctionDeclaration(name: "toLower", callback: toLowerFunction),
            "substr": FunctionDeclaration(name: "substr", callback: substrFunction)
        ]
    }
    
    private let toUpperFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let string = try ParameterValidator.extractString(params[0], at: 0)
        return string.uppercased()
    }
    
    private let toLowerFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let string = try ParameterValidator.extractString(params[0], at: 0)
        return string.lowercased()
    }
    
    private let substrFunction: FunctionCallback = { params in
        try ParameterValidator.validateMinCount(params, minimum: 2)
        
        let string = try ParameterValidator.extractString(params[0], at: 0)
        let start = try ParameterValidator.extractInt(params[1], at: 1)
        let end = params.count > 2 ? try? ParameterValidator.extractInt(params[2], at: 2) : nil
        
        let startIndex = max(0, start)
        
        guard startIndex < string.count else {
            throw FunctionError.executionError("Start index \(startIndex) is out of bounds for string length \(string.count)")
        }
        
        let startStringIndex = string.index(string.startIndex, offsetBy: startIndex)
        
        if let endIndex = end {
            let clampedEnd = min(string.count, endIndex)
            guard startIndex <= clampedEnd else {
                throw FunctionError.executionError("Start index \(startIndex) must be <= end index \(clampedEnd)")
            }
            let endStringIndex = string.index(string.startIndex, offsetBy: clampedEnd)
            return String(string[startStringIndex..<endStringIndex])
        } else {
            return String(string[startStringIndex...])
        }
    }
}

// MARK: - Conversion Functions

public class ConversionFunctions: FunctionCategory {
    public let categoryName = "Conversion"
    
    public init() {}
    
    public var functions: [String: FunctionDeclaration] {
        return [
            "parseFloat": FunctionDeclaration(name: "parseFloat", callback: parseFloatFunction),
            "parseInt": FunctionDeclaration(name: "parseInt", callback: parseIntFunction),
            "toString": FunctionDeclaration(name: "toString", callback: toStringFunction)
        ]
    }
    
    private let parseFloatFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let input = params[0]
        
        if let number = input as? NSNumber {
            return number.doubleValue
        }
        if let string = input as? String, let double = Double(string) {
            return double
        }
        throw FunctionError.executionError("Cannot parse '\(String(describing: input))' as float")
    }
    
    private let parseIntFunction: FunctionCallback = { params in
        try ParameterValidator.validateMinCount(params, minimum: 1)
        let input = params[0]
        let radix = params.count > 1 ? try? ParameterValidator.extractInt(params[1], at: 1) : 10
        
        if let number = input as? NSNumber {
            return number.int64Value
        }
        if let string = input as? String, let int64 = Int64(string, radix: radix ?? 10) {
            return int64
        }
        throw FunctionError.executionError("Cannot parse '\(String(describing: input))' as integer")
    }
    
    private let toStringFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let input = params[0]
        
        // Handle nil case
        guard let value = input else {
            return ""
        }
        
        // Convert any value to string representation
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let bool as Bool:
            return String(bool)
        default:
            return String(describing: value)
        }
    }
}

// MARK: - Utility Functions

public class UtilityFunctions: FunctionCategory {
    public let categoryName = "Utility"
    
    public init() {}
    
    public var functions: [String: FunctionDeclaration] {
        return [
            "if": FunctionDeclaration(name: "if", callback: ifFunction),
            "length": FunctionDeclaration(name: "length", callback: lengthFunction)
        ]
    }
    
    private let ifFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 3)
        let condition = params[0] as? Bool ?? false
        return condition ? params[1] : params[2]
    }
    
    private let lengthFunction: FunctionCallback = { params in
        try ParameterValidator.validateCount(params, expected: 1)
        let input = params[0]
        
        if let string = input as? String {
            return string.count
        }
        if let array = input as? [Any] {
            return array.count
        }
        if let dict = input as? [String: Any] {
            return dict.count
        }
        throw FunctionError.executionError("Length function requires string, array, or dictionary")
    }
}

// MARK: - Date Functions

public class DateFunctions: FunctionCategory {
    public let categoryName = "Date"
    
    public init() {}
    
    public var functions: [String: FunctionDeclaration] {
        return [
            "Date.format": FunctionDeclaration(name: "Date.format", callback: formatDateFunction),
            "Time.format": FunctionDeclaration(name: "Time.format", callback: formatTimeFunction)
        ]
    }
    
    private func parseDateInput(_ input: Any?) throws -> Int64 {
        if let number = input as? NSNumber {
            return number.int64Value
        }
        if let string = input as? String {
            let formatter = ISO8601DateFormatter()
            guard let date = formatter.date(from: string) else {
                throw FunctionError.executionError("Date string '\(string)' is not a valid ISO-8601 format")
            }
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        throw FunctionError.executionError("Date input must be a Number (epoch ms) or String (ISO-8601)")
    }
    
    private lazy var formatDateFunction: FunctionCallback = { [weak self] params in
        try ParameterValidator.validateMinCount(params, minimum: 1)
        guard let self = self else { throw FunctionError.executionError("Date function instance deallocated") }
        
        let timestamp = try self.parseDateInput(params[0])
        let format = params.count > 1 ? (params[1] as? String ?? "compact") : "compact"
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        
        switch format.lowercased() {
        case "long":
            formatter.dateStyle = .long
        case "short":
            formatter.dateStyle = .short
        case "compact":
            formatter.dateStyle = .medium
        default:
            formatter.dateStyle = .medium
        }
        
        return formatter.string(from: date)
    }
    
    private lazy var formatTimeFunction: FunctionCallback = { [weak self] params in
        try ParameterValidator.validateCount(params, expected: 1)
        guard let self = self else { throw FunctionError.executionError("Date function instance deallocated") }
        
        let timestamp = try self.parseDateInput(params[0])
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return formatter.string(from: date)
    }
}

// MARK: - Function Registry

public class FunctionRegistry {
    private let categories: [FunctionCategory]
    private lazy var allFunctions: [String: FunctionDeclaration] = {
        return categories.reduce(into: [:]) { result, category in
            result.merge(category.functions) { _, new in new }
        }
    }()
    
    public init(categories: [FunctionCategory] = [
        MathFunctions(),
        StringFunctions(),
        ConversionFunctions(),
        UtilityFunctions(),
        DateFunctions()
    ]) {
        self.categories = categories
    }
    
    public func getFunction(name: String) -> FunctionDeclaration? {
        return allFunctions[name]
    }
    
    public func getAllFunctions() -> [String: FunctionDeclaration] {
        return allFunctions
    }
    
    public func getFunctionsByCategory(_ categoryName: String) -> [String: FunctionDeclaration] {
        return categories.first { $0.categoryName == categoryName }?.functions ?? [:]
    }
    
    public func getAllCategories() -> [String] {
        return categories.map { $0.categoryName }
    }
}

public class BuiltInFunctions: FunctionProvider {
    private let registry: FunctionRegistry
    
    public init(customCategories: [FunctionCategory] = []) {
        let defaultCategories: [FunctionCategory] = [
            MathFunctions(),
            StringFunctions(),
            ConversionFunctions(),
            UtilityFunctions(),
            DateFunctions()
        ]
        self.registry = FunctionRegistry(categories: defaultCategories + customCategories)
    }
    
    /// Returns a copy of all available functions - external modifications won't affect internal registry
    public var functions: [String: FunctionDeclaration] {
        return registry.getAllFunctions() // Returns a copy for encapsulation
    }
    
    public func getFunction(name: String) -> FunctionDeclaration? {
        return registry.getFunction(name: name)
    }
    
    // MARK: - Registry Access
    
    /// Get functions by category name
    public func getFunctionsByCategory(_ categoryName: String) -> [String: FunctionDeclaration] {
        return registry.getFunctionsByCategory(categoryName)
    }
    
    /// Get all available categories
    public func getAllCategories() -> [String] {
        return registry.getAllCategories()
    }
    
    /// Check if a function exists (more efficient than accessing functions dictionary)
    public func hasFunction(name: String) -> Bool {
        return registry.getFunction(name: name) != nil
    }
    
    /// Get available function names (more efficient than getting full functions dictionary)
    public var availableFunctionNames: [String] {
        return Array(registry.getAllFunctions().keys)
    }
}
