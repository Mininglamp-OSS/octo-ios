//
//  SwiftLegacyACSupport.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

// Legacy serialization rule standardization and extensions.

// MARK: - Core Protocols

/// Protocol for any object that can be serialized to/from JSON
protocol JSONSerializable {
    /// Convert to a JSON dictionary
    func toJSON() throws -> [String: Any]
    
    /// Convert to a JSON string
    func toJSONString() throws -> String
    
    /// Determine if the object has enough data to be serialized
    func shouldSerialize() -> Bool
}

/// Protocol for legacy JSON conversion methods
protocol LegacyJSONConvertible: JSONSerializable {
    associatedtype Element
    
    /// Deserialize from a JSON dictionary
    static func fromJSON(_ json: [String: Any]) throws -> Element?
    
    /// Deserialize from a JSON string
    static func fromJSONString(_ jsonString: String) throws -> Element?
}

/// Protocol for Adaptive Card elements with legacy support
protocol AdaptiveCardLegacySerializable: LegacyJSONConvertible {
    /// Serialize to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any]
    
    /// Populate known properties set
    func populateKnownPropertiesSet()
}

// MARK: - Generic Legacy Support Implementation

/// Generic implementation of legacy serialization/deserialization for any Codable type
struct LegacySupport<T: Codable> {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a generic type T
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> T {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    /// Deserializes string into a generic type T
    static public func deserialize(from jsonString: String) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a generic type T to JSON dictionary
    static func serializeToJson(_ element: T, baseJson: [String: Any] = [:]) throws -> [String: Any] {
        let data = try JSONEncoder().encode(element)
        guard let jsonObj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw EncodingError.invalidValue(element, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON dictionary"))
        }
        
        // Merge with baseJson
        var result = baseJson
        for (key, value) in jsonObj {
            result[key] = value
        }
        
        return result
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ element: T) throws -> String {
        let json = try serializeToJson(element)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - Extension Methods for Codable Types

extension Encodable {
    /// Basic JSON serialization for any Encodable type
    func jsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    /// Convert to dictionary
    func asDictionary() throws -> [String: Any] {
        let data = try self.jsonData()
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to dictionary"))
        }
        return dictionary
    }
}

// MARK: - Default Implementation for Core Protocols

extension JSONSerializable {
    func toJSONString() throws -> String {
        let json = try toJSON()
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
    
    func shouldSerialize() -> Bool {
        return true
    }
}

extension LegacyJSONConvertible where Self: Codable, Element == Self {
    static func fromJSON(_ json: [String: Any]) throws -> Self? {
        return try LegacySupport<Self>.deserialize(from: json)
    }
    
    static func fromJSONString(_ jsonString: String) throws -> Self? {
        return try LegacySupport<Self>.deserialize(from: jsonString)
    }
    
    func toJSON() throws -> [String: Any] {
        return try LegacySupport<Self>.serializeToJson(self)
    }
}

// MARK: - Generic Parser Implementation

/// Generic parser for any Adaptive Card element
struct GenericCardElementParser<T: SwiftAdaptiveCardElementProtocol & Codable> : SwiftBaseCardElementParser {
    private let expectedType: SwiftCardElementType
    
    init(elementType: SwiftCardElementType) {
        self.expectedType = elementType
    }
    
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: expectedType)
        return try LegacySupport<T>.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<T>.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<T>.deserialize(from: value)
    }
}

// MARK: - Consolidated SwiftImage Legacy Support

/// Unified legacy support for SwiftImage parsing and serialization
// MARK: - SwiftImage Extension for Protocol Conformance

extension SwiftImage: AdaptiveCardLegacySerializable {
    typealias Element = SwiftImage
    
    // This function is already defined but needs to be exposed publicly
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        var json = superResult
        
        // Set required properties
        json["type"] = "Image"
        json["url"] = self.url
        
        // Only include style if it's not the default value
        if self.imageStyle != .defaultImageStyle {
            json["style"] = self.imageStyle.rawValue
        }
        
        // Only include size if it's not None
        if self.imageSize != .none {
            json["size"] = SwiftImageSize.toString(self.imageSize)
        }
        
        // Add optional properties
        if let alignment = self.hAlignment {
            json["horizontalAlignment"] = alignment.rawValue.lowercased()
        }
        
        // Only add non-empty strings
        if !self.backgroundColor.isEmpty {
            json["backgroundColor"] = self.backgroundColor
        }
        
        if !self.altText.isEmpty {
            json["altText"] = self.altText
        }
        
        // Add action if present
        if let action = self.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(action)
        }
        
        // Don't include spacing if it's .none or .default (which is the default behavior)
        if self.spacing != .none && self.spacing != .default {
            json["spacing"] = self.spacing.rawValue.lowercased()
        }
        
        // Don't include separator if it's nil or false
        if let separator = self.separator, separator == true {
            json["separator"] = separator
        }
        
        return json
    }
    
    // This function is already defined but needs to be exposed publicly
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("altText")
        self.knownProperties.insert("backgroundColor")
        self.knownProperties.insert("height")
        self.knownProperties.insert("horizontalAlignment")
        self.knownProperties.insert("selectAction")
        self.knownProperties.insert("size")
        self.knownProperties.insert("style")
        self.knownProperties.insert("url")
        self.knownProperties.insert("width")
    }
    
    // Resource information method (keeping this from your original code)
    func getResourceInformation(_ resourceInfo: inout [SwiftRemoteResourceInformation]) {
        let info = SwiftRemoteResourceInformation(url: self.url, mimeType: "image")
        resourceInfo.append(info)
    }
    
    // All other serialization methods are now provided by protocol extensions!
    
    // If any custom behavior is needed, you can override the protocol methods:
    func shouldSerialize() -> Bool {
        return !url.isEmpty // Only serialize if we have a URL
    }
}

// MARK: - Updated Parser Implementation

/// Parses Image elements in an Adaptive Card
struct SwiftImageParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.image)
        return try LegacySupport<SwiftImage>.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<SwiftImage>.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<SwiftImage>.deserialize(from: value)
    }
}


