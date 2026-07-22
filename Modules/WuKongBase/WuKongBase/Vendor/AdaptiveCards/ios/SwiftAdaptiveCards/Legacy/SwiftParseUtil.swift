//
//  SwiftParseUtil.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

public struct SwiftParseUtil {
    
    // MARK: – Core JSON Conversion
    
    public static func jsonToString(_ json: [String: Any]) throws -> String {
        let unwrapped = unwrapAnyCodable(from: json)
        let jsonData = try JSONSerialization.data(withJSONObject: unwrapped, options: [.sortedKeys])
        return "\(String(data: jsonData, encoding: .utf8) ?? "{}")\n"
    }

    static func jsonToString(_ json: [String: SwiftAnyCodable]) throws -> String {
        return try jsonToString(json.mapValues { $0.value })
    }
    
    static func jsonToString(_ value: Any) throws -> String {
        if let str = value as? String {
            // If it's already a string, return it JSON-encoded
            let data = try JSONSerialization.data(withJSONObject: str, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? ""
        } else {
            // For dictionaries and other types, use standard JSON serialization
            let data = try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    public static func throwIfNotJsonObject(_ json: Any) throws {
        guard json is [String: Any] else {
            throw ParsingError.invalidType(expected: "JSON object", found: "\(type(of: json))")
        }
    }
    
    // MARK: – Type & Value Retrieval
    
    public static func getJsonValue(from string: String) -> [String: Any] {
        guard let data = string.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            return [:]
        }
        return jsonDict
    }
    
    public static func getTypeAsString(from json: [String: Any]) throws -> String {
        guard let type = json["type"] as? String else {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: "type")
        }
        return type
    }
    
    public static func tryGetTypeAsString(from json: [String: Any]) -> String {
        return (try? getTypeAsString(from: json)) ?? ""
    }
    
    public static func getString(from json: [String: Any], key: String, required: Bool = false) throws -> String {
        guard let value = json[key] as? String else {
            if required {
                throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
            }
            return ""
        }
        return value
    }
    
    static func getOptionalString(from json: [String: Any], key: String) -> String? {
        return json[key] as? String
    }
    
    public static func getBool(from json: [String: Any], key: String, defaultValue: Bool, required: Bool) throws -> Bool {
        guard let value = json[key] as? Bool else {
            if required {
                throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
            }
            return defaultValue
        }
        return value
    }
    
    static func getOptionalBool(from json: [String: Any], key: String) -> Bool? {
        return json[key] as? Bool
    }
    
    public static func getInt(from json: [String: Any], key: String, defaultValue: Int, required: Bool) throws -> Int {
        guard let value = json[key] as? Int else {
            if required {
                throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
            }
            return defaultValue
        }
        return value
    }
    
    public static func getOptionalInt(from json: [String: Any], key: String) -> Int? {
        return json[key] as? Int
    }
    
    public static func getUInt(from json: [String: Any], key: String, defaultValue: UInt, required: Bool) throws -> UInt {
        if let val = json[key] {
            // If the value is NSNull, treat it as missing.
            if val is NSNull {
                if required {
                    throw SwiftAdaptiveCardParseException(
                        statusCode: .requiredPropertyMissing,
                        message: "Could not parse required key: \(key). It was not found"
                    )
                }
                return defaultValue
            }
            if let number = val as? NSNumber {
                let intValue = number.intValue
                if intValue < 0 {
                    throw SwiftAdaptiveCardParseException(
                        statusCode: .invalidPropertyValue,
                        message: "Could not parse specified key: \(key). It was not a valid unsigned integer"
                    )
                }
                return number.uintValue
            }
        }
        if required {
            throw SwiftAdaptiveCardParseException(
                statusCode: .requiredPropertyMissing,
                message: "Could not parse required key: \(key). It was not found"
            )
        }
        return defaultValue
    }
    
    // MARK: – JSON Dictionary & Value Extraction
    
    public static func getJsonDictionary(from jsonString: String) throws -> [String: Any] {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let dict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "JSON is not a dictionary")
        }
        return dict
    }
    
    public static func getJsonValueFromString(_ jsonString: String) throws -> [String: Any] {
        return try getJsonDictionary(from: jsonString)
    }
    
    public static func extractJsonValue(from json: [String: Any], key: String, required: Bool) throws -> Any? {
        if let value = json[key] {
            return value
        } else {
            if required {
                throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
            }
            return nil
        }
    }
    
    // MARK: – Enum Helpers
    
    static func getEnumValue<T: RawRepresentable>(
        from json: [String: Any],
        key: String,
        defaultValue: T,
        converter: (String) -> T?
    ) throws -> T where T.RawValue == String {
        if let value = json[key] as? String, let enumValue = converter(value) {
            return enumValue
        }
        return defaultValue
    }
    
    static func getOptionalEnumValue<T: RawRepresentable>(
        from json: [String: Any],
        key: String,
        converter: (String) -> T?
    ) throws -> T? where T.RawValue == String {
        if let value = json[key] as? String {
            return converter(value)
        }
        return nil
    }
    
    // MARK: – Collection Helpers
    
    public static func getArray(from json: [String: Any], key: String, required: Bool = false) throws -> [[String: Any]] {
        // First, try to see if the value is already an array of dictionaries.
        if let arrayOfDicts = json[key] as? [[String: Any]] {
            if required && arrayOfDicts.isEmpty {
                throw SwiftAdaptiveCardParseException(
                    statusCode: .requiredPropertyMissing,
                    message: "Could not parse required key: \(key). It was not found"
                )
            }
            return arrayOfDicts
        }
        // Otherwise, if the value is any array...
        if let array = json[key] as? [Any] {
            // Wrap each element in a dictionary with key "0".
            var wrapped: [[String: Any]] = []
            for element in array {
                wrapped.append(["0": element])
            }
            if required && wrapped.isEmpty {
                throw SwiftAdaptiveCardParseException(
                    statusCode: .requiredPropertyMissing,
                    message: "Could not parse required key: \(key). It was not found"
                )
            }
            return wrapped
        }
        // If no value is found for the key...
        if required {
            throw SwiftAdaptiveCardParseException(
                statusCode: .requiredPropertyMissing,
                message: "Could not parse required key: \(key). It was not found"
            )
        }
        return []
    }
    
    static func getActionCollection(from json: [String: Any], key: String) throws -> [SwiftBaseActionElement] {
        let array = try getArray(from: json, key: key, required: false)
        return try array.map { try SwiftBaseActionElement.deserializeAction(from: $0) }
    }
    
    public static func getAction(from json: [String: Any], key: String, context: SwiftParseContext) throws -> SwiftBaseActionElement? {
        guard let actionJson = json[key] as? [String: Any] else {
            return nil
        }
        return try SwiftBaseActionElement.deserializeAction(from: actionJson)
    }
    
    static func getElementCollectionOfSingleType<T>(
        from json: [String: Any],
        key: String,
        context: SwiftParseContext,
        defaultValue: [T] = [],
        converter: (SwiftParseContext, [String: Any]) throws -> T
    ) throws -> [T] {
        guard let array = json[key] as? [[String: Any]] else {
            return defaultValue
        }
        var results: [T] = []
        for item in array {
            let parsedItem = try converter(context, item)
            results.append(parsedItem)
        }
        return results
    }
    
    static func getElementCollection(isTopToBottomContainer: Bool,
                                     context: SwiftParseContext,
                                     json: [String: Any],
                                     key: String,
                                     required: Bool) throws -> [SwiftBaseCardElement] {
        let array = try getArray(from: json, key: key, required: required)
        var elements: [SwiftBaseCardElement] = []
        for rawItem in array {
            // Recursively remove AnyCodable wrappers before passing to deserialize
            let unwrappedAny = unwrapAnyCodable(from: rawItem)
            guard let unwrappedDict = unwrappedAny as? [String: Any] else {
                throw AdaptiveCardParseError.invalidJson
            }
            let element = try SwiftBaseCardElement.deserialize(from: unwrappedDict)
            elements.append(element)
        }
        return elements
    }

    static func getValueAsString(from json: [String: Any], key: String) -> String {
        return json[key] as? String ?? ""
    }
    
    // MARK: – Type Checking
    
    public static func expectTypeString(_ json: [String: Any], expected: SwiftCardElementType) throws {
        let actual = try getTypeAsString(from: json)
        if actual != expected.rawValue {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: "Expected type \(expected.rawValue) but found \(actual)")
        }
    }
    
    // MARK: – Additional Helpers Matching the C++ API
    
    /// Calls the provided callback on the JSON value associated with the given key.
    /// Throws if the key is nil, missing, or if the callback throws.
    public static func expectKeyAndValueType(_ json: [String: Any], _ key: String?, callback: (Any) throws -> Void) throws {
        guard let key = key else {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: "Key is nil")
        }
        guard let value = json[key] else {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
        }
        try callback(value)
    }
    
    /// Converts the JSON value for the given key to a JSON string and appends a newline.
    /// For string values it adds quotes.
    public static func getJsonString(from json: [String: Any], key: String, required: Bool) throws -> String {
        guard let value = json[key] else {
            if required {
                throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: key)
            }
            return ""
        }
        if let str = value as? String {
            return "\"\(str)\"\n"
        } else if let number = value as? NSNumber {
            return "\(number)\n"
        } else if let dict = value as? [String: Any] {
            let jsonStr = try jsonToString(dict)
            return jsonStr + "\n"
        } else if let arr = value as? [Any] {
            let data = try JSONSerialization.data(withJSONObject: arr, options: [.sortedKeys])
            guard let result = String(data: data, encoding: .utf8) else {
                throw SwiftAdaptiveCardParseException(statusCode: .serializationFailed, message: "Unable to convert array to JSON string")
            }
            return result + "\n"
        }
        return "\(value)\n"
    }
    
    static func unwrapAnyCodable(from object: Any) -> Any {
        if let anyCodable = object as? SwiftAnyCodable {
            // Recursively unwrap the inner value.
            return unwrapAnyCodable(from: anyCodable.value)
        } else if let array = object as? [Any] {
            return array.map { unwrapAnyCodable(from: $0) }
        } else if let dict = object as? [String: Any] {
            var newDict = [String: Any]()
            for (key, value) in dict {
                newDict[key] = unwrapAnyCodable(from: value)
            }
            return newDict
        } else if let dict = object as? [String: SwiftAnyCodable] {
            var newDict = [String: Any]()
            for (key, value) in dict {
                newDict[key] = unwrapAnyCodable(from: value)
            }
            return newDict
        } else {
            return object
        }
    }
}
