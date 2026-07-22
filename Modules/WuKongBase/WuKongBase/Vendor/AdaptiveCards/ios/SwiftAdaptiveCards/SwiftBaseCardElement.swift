//
//  SwiftBaseCardElement.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

/// A protocol that represents an adaptive card element.
/// Both card and action elements must provide these basic properties.
public protocol SwiftAdaptiveCardElementProtocol: Codable {
    var typeString: String { get set }
    var id: String? { get set }
}

/// Represents a base element in an Adaptive Card.
public class SwiftBaseCardElement: SwiftBaseElement, SwiftAdaptiveCardElementProtocol {
    // MARK: - Properties
    public let type: SwiftCardElementType
    public var spacing: SwiftSpacing = .default
    public var height: SwiftHeightType = .auto
    public var targetWidth: SwiftTargetWidthType?
    public var separator: Bool?
    public var isVisible: Bool = true
    public var areaGridName: String?
    public var parentalId: SwiftInternalId?
    
    /// Properties to track if values were explicitly set in JSON
    private var spacingWasExplicitlySet: Bool = false
    private var heightWasExplicitlySet: Bool = false
    
    override public var typeString: String {
        get { return type.rawValue }
        set { /* Optionally update type if needed */ }
    }
    
    /// Returns the element type as a CardElementType (or .unknown if it can't be parsed)
    public var elementTypeVal: SwiftCardElementType {
        // Use the normal conversion
        let baseType = SwiftCardElementType.fromString(self.typeString) ?? .unknown
        // But if this is a TableRow or TableCell that came in as an orphan, return .unknown.
        if baseType == .tableRow || baseType == .tableCell {
            return .unknown
        }
        return baseType
    }

    // MARK: - Initializers
    public init(
        type: SwiftCardElementType,
        spacing: SwiftSpacing = .default,
        height: SwiftHeightType = .auto,
        targetWidth: SwiftTargetWidthType? = nil,
        separator: Bool? = nil,
        isVisible: Bool = true,
        areaGridName: String? = nil,
        parentalId: SwiftInternalId? = nil,
        id: String? = nil
    ) {
        self.type = type
        self.spacing = spacing
        self.height = height
        self.targetWidth = targetWidth
        self.separator = separator
        self.isVisible = isVisible
        self.areaGridName = areaGridName
        self.parentalId = parentalId
        
        // When programmatically creating elements, spacing and height are 
        // considered explicitly set only if they're not default values
        self.spacingWasExplicitlySet = (spacing != .default)
        self.heightWasExplicitlySet = (height != .auto)
        
        super.init(typeString: type.rawValue, id: id)
    }

    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case type
        case spacing
        case height
        case targetWidth
        case separator
        case isVisible
        case areaGridName
        case parentalId
    }

    /// Deserializes a BaseCardElement from JSON.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode the local properties.
        let typeRaw = try container.decode(String.self, forKey: .type)
        let decodedType: SwiftCardElementType
        
        if typeRaw.hasPrefix("Action.") {
            // For actions, map to a generic type (e.g. .custom)
            decodedType = .custom
        } else if let validType = SwiftCardElementType(rawValue: typeRaw) {
            decodedType = validType
        } else {
            throw AdaptiveCardParseError.invalidType
        }
        
        self.type = decodedType
        
        // Track if spacing was explicitly set and decode it
        if let spacingString = try container.decodeIfPresent(String.self, forKey: .spacing) {
            self.spacingWasExplicitlySet = true
            self.spacing = SwiftSpacing(rawValue: spacingString) ?? .default
        } else {
            self.spacingWasExplicitlySet = false
            self.spacing = .default
        }
        
        // Track if height was explicitly set and decode it
        if let heightString = try container.decodeIfPresent(String.self, forKey: .height) {
            self.heightWasExplicitlySet = true
            self.height = SwiftHeightType(rawValue: heightString) ?? .auto
        } else {
            self.heightWasExplicitlySet = false
            self.height = .auto
        }
        
        self.targetWidth = try container.decodeIfPresent(String.self, forKey: .targetWidth).flatMap { SwiftTargetWidthType(rawValue: $0) }
        self.separator = try container.decodeIfPresent(Bool.self, forKey: .separator)
        self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        self.areaGridName = try container.decodeIfPresent(String.self, forKey: .areaGridName)
        self.parentalId = try container.decodeIfPresent(SwiftInternalId.self, forKey: .parentalId)
        
        // Decode the BaseElement properties.
        try super.init(from: decoder)
    }
    
    /// Serializes the BaseCardElement into JSON.
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        
        // Only encode spacing if it was explicitly set OR is not default
        if spacingWasExplicitlySet || spacing != .default {
            try container.encode(spacing.rawValue, forKey: .spacing)
        }
        
        // Only encode height if it was explicitly set OR is not default
        if heightWasExplicitlySet || height != .auto {
            try container.encode(height.rawValue, forKey: .height)
        }
        
        try container.encodeIfPresent(targetWidth?.rawValue, forKey: .targetWidth)
        try container.encodeIfPresent(separator, forKey: .separator)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encodeIfPresent(areaGridName, forKey: .areaGridName)
        try container.encodeIfPresent(parentalId, forKey: .parentalId)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization
    override func serializeToJsonValue() throws -> [String: Any] {
        var json = try super.serializeToJsonValue()
        
        // Ensure type is set correctly
        json["type"] = typeString
        
        // Only add optional properties if they were explicitly set or are not default values
        // Include spacing if it was explicitly set OR if it's not the default value
        if spacingWasExplicitlySet || spacing != .default {
            json["spacing"] = spacing.rawValue
        }
        
        // Include height if it was explicitly set OR if it's not the default value
        if heightWasExplicitlySet || height != .auto {
            json["height"] = height.rawValue
        }
        
        // Don't include targetWidth if it's nil
        if let targetWidth = targetWidth, targetWidth != .default {
            json["targetWidth"] = targetWidth.rawValue
        }
        
        // Don't include separator if it's nil or false
        if let separator = separator, separator == true {
            json["separator"] = separator
        }
        
        // Don't include isVisible if it's true (default value)
        if !isVisible {
            json["isVisible"] = isVisible
        }
        
        // Don't include areaGridName if it's nil
        if let areaGridName = areaGridName, !areaGridName.isEmpty {
            json["areaGridName"] = areaGridName
        }
        
        // Don't include parentalId if it's nil
        if let parentalId = parentalId {
            json["parentalId"] = parentalId
        }
        
        return json
    }
    
    /// Convenience serialize method that returns a JSON string.
    public func serialize() throws -> String {
        return try SwiftParseUtil.jsonToString(self.serializeToJsonValue())
    }
}
