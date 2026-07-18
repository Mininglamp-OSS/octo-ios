//
//  SwiftBaseElement.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

/// Represents a base element in an adaptive card.
open class SwiftBaseElement: Codable {
    // MARK: - Properties
    var typeString: String
    public var id: String?
    public let internalId: SwiftInternalId
    public var additionalProperties: [String: SwiftAnyCodable]?
    let requires: [String: SwiftSemanticVersion]?
    var fallbackType: SwiftFallbackType?
    public var fallbackContent: SwiftBaseElement?
    var canFallbackToAncestor: Bool?
    
    // Add knownProperties for use in subclasses.
    var knownProperties: Set<String> = []
    
    // MARK: - Shared Parse Context
    // Singleton ParseContext instance
    private static var sharedParseContext: SwiftParseContext = {
        let context = SwiftParseContext()
        return context
    }()
    
    // Public getter for the shared context
    static var parseContext: SwiftParseContext {
        return sharedParseContext
    }
    
    // Reset method for testing
    static func resetParseContext() {
        sharedParseContext = SwiftParseContext()
    }

    // MARK: - Initializer
    init(
        typeString: String,
        id: String? = nil,
        internalId: SwiftInternalId = SwiftInternalId.current(),
        additionalProperties: [String: SwiftAnyCodable]? = nil,
        requires: [String: SwiftSemanticVersion]? = nil,
        fallbackType: SwiftFallbackType? = nil,
        fallbackContent: SwiftBaseElement? = nil,
        canFallbackToAncestor: Bool? = nil
    ) {
        self.typeString = typeString
        self.id = id
        self.internalId = internalId
        self.additionalProperties = additionalProperties
        self.requires = requires
        self.fallbackType = fallbackType
        self.fallbackContent = fallbackContent
        self.canFallbackToAncestor = canFallbackToAncestor
    }
    
    // MARK: - Codable Implementation
    public required init(from decoder: Decoder) throws {
        // First decode all keys using a dynamic container.
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var rawDict = [String: SwiftAnyCodable]()
        for key in dynamicContainer.allKeys {
            rawDict[key.stringValue] = try dynamicContainer.decode(SwiftAnyCodable.self, forKey: key)
        }
        
        // Now decode known properties.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeString = try container.decode(String.self, forKey: .typeString)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        internalId = try container.decodeIfPresent(SwiftInternalId.self, forKey: .internalId) ?? SwiftInternalId.current()
        requires = try container.decodeIfPresent([String: SwiftSemanticVersion].self, forKey: .requires)
        fallbackType = try container.decodeIfPresent(SwiftFallbackType.self, forKey: .fallbackType)
        fallbackContent = try container.decodeIfPresent(SwiftBaseElement.self, forKey: .fallbackContent)
        canFallbackToAncestor = try container.decodeIfPresent(Bool.self, forKey: .canFallbackToAncestor)
        
        if container.contains(.fallback) {
            if let fallbackString = try? container.decode(String.self, forKey: .fallback) {
                if fallbackString.lowercased() == "drop" {
                    fallbackType = .drop
                }
            } else if let rawFallback = try? container.decode([String: SwiftAnyCodable].self, forKey: .fallback) {
                let fallbackDict = rawFallback.mapValues { $0.value }
                fallbackContent = try SwiftBaseCardElement.deserialize(from: fallbackDict)
            }
        }
        
        // Remove all keys that are declared in CodingKeys.
        for key in SwiftBaseElement.CodingKeys.allCases {
            rawDict.removeValue(forKey: key.rawValue)
        }
        
        // Set additional properties if there are any remaining
        additionalProperties = rawDict.isEmpty ? nil : rawDict
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode typeString using the key "type"
        try container.encode(typeString, forKey: .typeString)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(internalId, forKey: .internalId)
        try container.encodeIfPresent(additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(requires, forKey: .requires)
        try container.encodeIfPresent(fallbackType, forKey: .fallbackType)
        try container.encodeIfPresent(fallbackContent, forKey: .fallbackContent)
        try container.encodeIfPresent(canFallbackToAncestor, forKey: .canFallbackToAncestor)
    }
    
    // MARK: - Serialization
    /// Serializes the BaseCardElement into a JSON dictionary.
    func serializeToJsonValue() throws -> [String: Any] {
        return try serializeToLegacyJsonFormat()
    }
    
    /// CodingKeys for the base element.
    public enum CodingKeys: String, CodingKey {
        case typeString = "type"
        case id
        case internalId
        case additionalProperties
        case requires
        case fallbackType
        case fallbackContent
        case canFallbackToAncestor
        case fallback  // <-- For "fallback" key
    }
    
    /// Converts the element into a JSON dictionary.
    func toJSON() -> [String: Any] {
        do {
            return try serializeToJsonValue()
        } catch {
            // Fallback to basic conversion if serialization fails
            var json: [String: Any] = ["type": typeString]
            if let id = id {
                json["id"] = id
            }
            return json
        }
    }
}
