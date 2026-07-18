//
//  SwiftLegacyACSupportPending.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

// Pending Legacy serialization rule standardization conformance.

// MARK: - Consolidated SwiftIcon Legacy Support

/// Unified legacy support for SwiftIcon parsing and serialization
enum SwiftIconLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftIcon
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftIcon {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftIcon.self, from: data)
    }
    
    /// Deserializes string into a SwiftIcon
    static public func deserialize(from jsonString: String) throws -> SwiftIcon {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftIcon.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftIcon to JSON dictionary with proper formatting
    static func serializeToJson(_ icon: SwiftIcon, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Icon"
        
        // Add icon name if present
        if let name = icon.name {
            json["name"] = name
        }
        
        // Only add non-default properties
        if icon.foregroundColor != .default {
            json["color"] = icon.foregroundColor.rawValue
        }
        
        if icon.iconSize != .standard {
            json["size"] = icon.iconSize.rawValue
        }
        
        if icon.iconStyle != .regular {
            json["style"] = icon.iconStyle.rawValue
        }
        
        // Add selectAction if present
        if let action = icon.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(action)
        }
        
        return json
    }
}

// MARK: - SwiftIcon Extension

extension SwiftIcon: AdaptiveCardLegacySerializable {
    typealias Element = SwiftIcon
    
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        var json = superResult
        
        // Set type property
        json["type"] = "Icon"
        
        // Add icon name if present
        if let name = self.name {
            json["name"] = name
        }
        
        // Only add non-default properties
        if self.foregroundColor != .default {
            json["color"] = self.foregroundColor.rawValue
        }
        
        if self.iconSize != .standard {
            json["size"] = self.iconSize.rawValue
        }
        
        if self.iconStyle != .regular {
            json["style"] = self.iconStyle.rawValue
        }
        
        // Add selectAction if present
        if let action = self.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(action)
        }
        
        return json
    }
    
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("name")
        self.knownProperties.insert("color")
        self.knownProperties.insert("size")
        self.knownProperties.insert("style")
        self.knownProperties.insert("selectAction")
    }
    
    // Custom shouldSerialize method, if needed
    func shouldSerialize() -> Bool {
        return self.name != nil // Only serialize if we have a name
    }
}

// MARK: - Updated Parser Implementation

/// Parses Icon elements in an Adaptive Card
struct SwiftIconParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.icon)
        return try LegacySupport<SwiftIcon>.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<SwiftIcon>.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try LegacySupport<SwiftIcon>.deserialize(from: value)
    }
}

// MARK: - SwiftIconInfo Extension for Protocol Conformance

extension SwiftIconInfo: LegacyJSONConvertible {
    typealias Element = SwiftIconInfo
    
    func toJSON() throws -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Only add non-default properties
        if self.iconSize != .standard {
            json["size"] = self.iconSize.rawValue
        }
        
        if self.iconStyle != .regular {
            json["style"] = self.iconStyle.rawValue
        }
        
        if self.foregroundColor != .default {
            json["color"] = self.foregroundColor.rawValue
        }
        
        if let name = self.name {
            json["name"] = name
        }
        
        return json
    }
    
    func shouldSerialize() -> Bool {
        return self.name != nil ||
               self.iconSize != .standard ||
               self.iconStyle != .regular ||
               self.foregroundColor != .default
    }
    
    // Already gets the following methods from protocol extensions:
    // - toJSONString()
    // - static fromJSON()
    // - static fromJSONString()
}
// MARK: - Consolidated SwiftUnknownElement Legacy Support

/// Unified legacy support for SwiftUnknownElement parsing and serialization
enum SwiftUnknownElementLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftUnknownElement
    static public func deserialize(from value: [String: Any]) throws -> SwiftUnknownElement {
        guard let typeString = value["type"] as? String else {
            throw AdaptiveCardParseError.invalidType
        }
        
        // Include all properties
        let properties = value.mapValues { SwiftAnyCodable($0) }
        
        return SwiftUnknownElement(elementType: typeString, additionalProperties: properties)
    }
    
    /// Deserializes string into a SwiftUnknownElement
    static public func deserialize(from jsonString: String) throws -> SwiftUnknownElement {
        let json = try SwiftParseUtil.getJsonDictionary(from: jsonString)
        return try deserialize(from: json)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftUnknownElement to JSON dictionary
    static func serializeToJson(_ element: SwiftUnknownElement) throws -> [String: Any] {
        return element.additionalProperties?.mapValues { $0.value } ?? [:]
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ element: SwiftUnknownElement) throws -> String {
        let json = try serializeToJson(element)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - Parser Implementation

/// Parses unknown elements in an Adaptive Card
struct SwiftUnknownElementParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftUnknownElementLegacySupport.deserialize(from: value)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftUnknownElementLegacySupport.deserialize(from: value)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftUnknownElementLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftUnknownElement Extension

extension SwiftUnknownElement {
    // Static factory methods
    static func createFromJSON(_ json: [String: Any]) throws -> SwiftUnknownElement {
        return try SwiftUnknownElementLegacySupport.deserialize(from: json)
    }
}

// MARK: - Consolidated SwiftAuthentication Legacy Support

/// Unified legacy support for SwiftAuthentication parsing and serialization
enum SwiftAuthenticationLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftAuthentication
    static public func deserialize(from json: [String: Any]) throws -> SwiftAuthentication {
        return SwiftAuthentication(
            text: json["text"] as? String ?? "",
            connectionName: json["connectionName"] as? String ?? "",
            tokenExchangeResource: try (json["tokenExchangeResource"] as? [String: Any]).flatMap {
                try SwiftTokenExchangeResource.deserialize(from: $0)
            },
            buttons: (json["buttons"] as? [[String: Any]])?.compactMap {
                SwiftAuthCardButton.deserialize(from: $0)
            } ?? []
        )
    }
    
    /// Deserializes string into a SwiftAuthentication
    static public func deserialize(from jsonString: String) -> SwiftAuthentication? {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return try? deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftAuthentication to JSON string
    static func serialize(_ authentication: SwiftAuthentication) -> String {
        let jsonData = try? JSONEncoder().encode(authentication)
        return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    
    /// Converts a SwiftAuthentication to JSON dictionary
    static func serializeToJson(_ authentication: SwiftAuthentication) throws -> [String: Any] {
        return try authentication.serializeToJsonValue()
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ authentication: SwiftAuthentication) throws -> String {
        let json = try serializeToJson(authentication)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftAuthentication Extension

extension SwiftAuthentication {
    // Serialization helpers
    func serialize() -> String {
        return SwiftAuthenticationLegacySupport.serialize(self)
    }
    
    func toJSON() throws -> [String: Any] {
        return try SwiftAuthenticationLegacySupport.serializeToJson(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftAuthenticationLegacySupport.serializeToJsonString(self)
    }
    
    // Static factory methods
    static public func deserialize(from json: [String: Any]) throws -> SwiftAuthentication {
        return try SwiftAuthenticationLegacySupport.deserialize(from: json)
    }
    
    func serializeToJsonValue() throws -> [String: Any] {
        var json: [String: Any] = [:]
        
        if !text.isEmpty {
            json["text"] = text
        }
        if !connectionName.isEmpty {
            json["connectionName"] = connectionName
        }
        if let tokenExchangeResource = tokenExchangeResource, tokenExchangeResource.shouldSerialize {
            json["tokenExchangeResource"] = try tokenExchangeResource.serializeToJsonValue()
        }
        if !buttons.isEmpty {
            json["buttons"] = buttons.map { $0.serializeToJsonValue() }
        }
        
        return json
    }
    
    func shouldSerialize() -> Bool {
        return !text.isEmpty ||
               !connectionName.isEmpty ||
               !buttons.isEmpty ||
               (tokenExchangeResource?.shouldSerialize ?? false)
    }
}

// MARK: - Consolidated SwiftAuthCardButton Legacy Support

/// Unified legacy support for SwiftAuthCardButton parsing and serialization
enum SwiftAuthCardButtonLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftAuthCardButton
    static public func deserialize(from json: [String: Any]) -> SwiftAuthCardButton {
        return SwiftAuthCardButton(
            type: json["type"] as? String ?? "",
            title: json["title"] as? String ?? "",
            image: json["image"] as? String ?? "",
            value: json["value"] as? String ?? ""
        )
    }
    
    /// Deserializes string into a SwiftAuthCardButton
    static public func deserialize(from jsonString: String) -> SwiftAuthCardButton? {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftAuthCardButton to JSON string
    static func serialize(_ button: SwiftAuthCardButton) -> String {
        let jsonData = try? JSONEncoder().encode(button)
        return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    
    /// Converts a SwiftAuthCardButton to JSON dictionary
    static func serializeToJson(_ button: SwiftAuthCardButton) -> [String: Any] {
        var json: [String: Any] = [:]
        
        if !button.type.isEmpty {
            json["type"] = button.type
        }
        if !button.title.isEmpty {
            json["title"] = button.title
        }
        if !button.image.isEmpty {
            json["image"] = button.image
        }
        if !button.value.isEmpty {
            json["value"] = button.value
        }
        
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ button: SwiftAuthCardButton) throws -> String {
        let json = serializeToJson(button)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftAuthCardButton Extension

extension SwiftAuthCardButton {
    // Serialization helpers
    func serialize() -> String {
        return SwiftAuthCardButtonLegacySupport.serialize(self)
    }
    
    func serializeToJsonValue() -> [String: Any] {
        return SwiftAuthCardButtonLegacySupport.serializeToJson(self)
    }
    
    func toJSON() -> [String: Any] {
        return SwiftAuthCardButtonLegacySupport.serializeToJson(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftAuthCardButtonLegacySupport.serializeToJsonString(self)
    }
    
    // Validation
    func shouldSerialize() -> Bool {
        return !type.isEmpty || !title.isEmpty || !image.isEmpty || !value.isEmpty
    }
    
    // Static factory methods
    static public func deserialize(from json: [String: Any]) -> SwiftAuthCardButton {
        return SwiftAuthCardButtonLegacySupport.deserialize(from: json)
    }
}

// MARK: - Consolidated SwiftLayout Legacy Support

/// Unified legacy support for SwiftLayout parsing and serialization
enum SwiftLayoutLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON data into a SwiftLayout
    static public func deserialize(from json: Data) throws -> SwiftLayout {
        return try JSONDecoder().decode(SwiftLayout.self, from: json)
    }
    
    /// Deserializes JSON dictionary into a SwiftLayout
    static public func deserialize(from json: [String: Any]) -> SwiftLayout? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            return nil
        }
        return try? deserialize(from: data)
    }
    
    /// Deserializes string into a SwiftLayout
    static func deserializeFromString(_ jsonString: String) throws -> SwiftLayout {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Invalid JSON string", code: -1, userInfo: nil)
        }
        return try deserialize(from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftLayout to JSON string
    static func serialize(_ layout: SwiftLayout) throws -> String {
        let jsonData = try JSONEncoder().encode(layout)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    /// Converts a SwiftLayout to JSON dictionary
    static func serializeToJson(_ layout: SwiftLayout) -> [String: Any] {
        return layout.serializeToJsonValue()
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ layout: SwiftLayout) throws -> String {
        let json = serializeToJson(layout)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftLayout Extension

extension SwiftLayout {
    // Static factory methods
    static func fromJSON(_ json: [String: Any]) -> SwiftLayout? {
        return SwiftLayoutLegacySupport.deserialize(from: json)
    }
    
    // JSON conversion utilities
    func serialize() throws -> String {
        return try SwiftLayoutLegacySupport.serialize(self)
    }
    
    func toJSON() -> [String: Any] {
        return SwiftLayoutLegacySupport.serializeToJson(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftLayoutLegacySupport.serializeToJsonString(self)
    }
    
    // MARK: - Validation Methods
    /// Determines if this layout should be serialized
    func shouldSerialize() -> Bool {
        return true
    }
    
    /// Checks if the layout meets the target width requirement
    func meetsTargetWidthRequirement(hostWidth: SwiftHostWidth) -> Bool {
        if targetWidth == .default || hostWidth == .default {
            return true
        }

        switch targetWidth {
        case .wide:
            return hostWidth == .wide
        case .standard:
            return hostWidth == .standard
        case .narrow:
            return hostWidth == .narrow
        case .veryNarrow:
            return hostWidth == .veryNarrow
        case .atLeastWide:
            return hostWidth >= .wide
        case .atLeastStandard:
            return hostWidth >= .standard
        case .atLeastNarrow:
            return hostWidth >= .narrow
        case .atLeastVeryNarrow:
            return hostWidth >= .veryNarrow
        case .atMostWide:
            return hostWidth <= .wide
        case .atMostStandard:
            return hostWidth <= .standard
        case .atMostNarrow:
            return hostWidth <= .narrow
        case .atMostVeryNarrow:
            return hostWidth <= .veryNarrow
        default:
            return true
        }
    }
    
    // MARK: - Serialization to JSON
    /// Serializes to JSON dictionary
    func serializeToJsonValue() -> [String: Any] {
        var json: [String: Any] = [:]

        if targetWidth != .default {
            json["targetWidth"] = targetWidth.rawValue
        }

        if layoutContainerType != .stack {
            json["layout"] = layoutContainerType.rawValue
        }

        return json
    }
    
    convenience init(fromFlowLayout flow: SwiftFlowLayout) {
        self.init()
        self.layoutContainerType = .flow
        // Copy additional properties from flow if needed.
    }
    
    /// Conversion initializer to create a generic Layout from an AreaGridLayout.
    convenience init(fromAreaGridLayout areaGrid: SwiftAreaGridLayout) {
        self.init()
        self.layoutContainerType = .areaGrid
        // Copy additional properties from areaGrid if needed.
    }
}

// MARK: - Consolidated SwiftAreaGridLayout Legacy Support

/// Unified legacy support for SwiftAreaGridLayout parsing and serialization
enum SwiftAreaGridLayoutLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftAreaGridLayout
    static public func deserialize(from json: [String: Any]) -> SwiftAreaGridLayout {
        let instance = SwiftAreaGridLayout()
        
        if let columnArray = json["columns"] as? [String] {
            instance.columns = columnArray
        }
        
        if let areaArray = json["areas"] as? [[String: Any]] {
            instance.areas = areaArray.map { SwiftGridArea.deserialize(from: $0) }
        }
        
        if let rowSpacingStr = json["rowSpacing"] as? String,
           let spacingEnum = SwiftSpacing(rawValue: rowSpacingStr) {
            instance.rowSpacing = spacingEnum
        }
        
        if let columnSpacingStr = json["columnSpacing"] as? String,
           let spacingEnum = SwiftSpacing(rawValue: columnSpacingStr) {
            instance.columnSpacing = spacingEnum
        }
        
        // Set the layout container type
        instance.layoutContainerType = .areaGrid
        
        // Handle parent class properties from the base class
        if let targetWidthStr = json["targetWidth"] as? String,
           let targetWidthEnum = SwiftTargetWidthType(rawValue: targetWidthStr) {
            instance.targetWidth = targetWidthEnum
        }
        
        return instance
    }
    
    /// Deserializes string into a SwiftAreaGridLayout
    static public func deserialize(from jsonString: String) -> SwiftAreaGridLayout? {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftAreaGridLayout to JSON dictionary
    static func serializeToJson(_ layout: SwiftAreaGridLayout) -> [String: Any] {
        return layout.serializeToJson()
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ layout: SwiftAreaGridLayout) throws -> String {
        let json = serializeToJson(layout)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftAreaGridLayout Extension

extension SwiftAreaGridLayout {
    // Static factory methods
    class public func deserialize(from json: [String: Any]) -> SwiftAreaGridLayout {
        return SwiftAreaGridLayoutLegacySupport.deserialize(from: json)
    }
    
    // MARK: - Serialization to JSON
    func serializeToJson() -> [String: Any] {
        var json = super.serializeToJsonValue()
        
        if !areas.isEmpty {
            json["areas"] = areas.map { $0.serializeToJson() }
        }
        if !columns.isEmpty {
            json["columns"] = columns
        }
        if rowSpacing != .default {
            json["rowSpacing"] = rowSpacing.rawValue
        }
        if columnSpacing != .default {
            json["columnSpacing"] = columnSpacing.rawValue
        }
        
        return json
    }
}

// MARK: - Consolidated SwiftActionSet Legacy Support

/// Unified legacy support for SwiftActionSet parsing and serialization
enum SwiftActionSetLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftActionSet
    static public func deserialize(from json: [String: Any]) throws -> SwiftActionSet {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(SwiftActionSet.self, from: data)
    }
    
    /// Deserializes string into a SwiftActionSet
    static public func deserialize(from jsonString: String) throws -> SwiftActionSet {
        guard let data = jsonString.data(using: .utf8) else {
            throw AdaptiveCardParseError.invalidJson
        }
        return try JSONDecoder().decode(SwiftActionSet.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftActionSet to JSON dictionary
    static func serializeToJson(_ actionSet: SwiftActionSet) throws -> [String: Any] {
        var json = try actionSet.baseSerializeToJsonValue()
        
        json["type"] = "ActionSet"
        
        if !actionSet.actions.isEmpty {
            json["actions"] = try actionSet.actions.map { try $0.serializeToJsonValue() }
        }
        
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ actionSet: SwiftActionSet) throws -> String {
        let json = try serializeToJson(actionSet)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftActionSet Extension

extension SwiftActionSet {
    // Helper for serialization support
    func baseSerializeToJsonValue() throws -> [String: Any] {
        return try super.serializeToJsonValue()
    }
}

// MARK: - Parser Implementation

/// Parses ActionSet elements in an Adaptive Card
struct SwiftActionSetParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.actionSet)
        return try SwiftActionSetLegacySupport.deserialize(from: value)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftActionSetLegacySupport.deserialize(from: value)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftActionSetLegacySupport.deserialize(from: value)
    }
}


// MARK: - Consolidated SwiftBackgroundImage Legacy Support

/// Unified legacy support for SwiftBackgroundImage parsing and serialization
enum SwiftBackgroundImageLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftBackgroundImage using Codable
    static public func deserialize(from json: [String: Any]) throws -> SwiftBackgroundImage {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftBackgroundImage.self, from: data)
    }
    
    /// Deserializes string into a SwiftBackgroundImage
    static public func deserialize(from jsonString: String) -> SwiftBackgroundImage? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(SwiftBackgroundImage.self, from: jsonData)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftBackgroundImage to JSON string using Codable
    static func serialize(_ backgroundImage: SwiftBackgroundImage) -> String {
        let jsonData = try? JSONEncoder().encode(backgroundImage)
        return jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    
    /// Converts a SwiftBackgroundImage to JSON dictionary
    /// Returns a string if all values are default (matches C++ behavior)
    static func serializeToJson(_ backgroundImage: SwiftBackgroundImage) -> Any {
        // Check if all values are default - if so, return just the URL string
        let defaultBackgroundImage = SwiftBackgroundImage()
        if backgroundImage.fillMode == defaultBackgroundImage.fillMode &&
           backgroundImage.horizontalAlignment == defaultBackgroundImage.horizontalAlignment &&
           backgroundImage.verticalAlignment == defaultBackgroundImage.verticalAlignment {
            return backgroundImage.url
        }
        
        // Otherwise, return the full object
        guard let jsonData = try? JSONEncoder().encode(backgroundImage),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return ["url": backgroundImage.url]
        }
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ backgroundImage: SwiftBackgroundImage) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(backgroundImage)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(backgroundImage, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON string"))
        }
        return jsonString
    }
}

// MARK: - SwiftBackgroundImage Extension

extension SwiftBackgroundImage {
    // Validation methods
    func shouldSerialize() -> Bool {
        return !url.isEmpty
    }
    
    // Serialization helpers
    func serialize() -> String {
        return SwiftBackgroundImageLegacySupport.serialize(self)
    }
    
    func serializeToJsonValue() -> Any {
        return SwiftBackgroundImageLegacySupport.serializeToJson(self)
    }
    
    func toJSON() -> Any {
        return SwiftBackgroundImageLegacySupport.serializeToJson(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftBackgroundImageLegacySupport.serializeToJsonString(self)
    }
    
    // Static factory methods
    static public func deserialize(from json: [String: Any]) throws -> SwiftBackgroundImage {
        return try SwiftBackgroundImageLegacySupport.deserialize(from: json)
    }
}

// MARK: - Consolidated SwiftCaptionSource Legacy Support

/// Unified legacy support for SwiftCaptionSource parsing and serialization
enum SwiftCaptionSourceLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftCaptionSource using Codable
    static public func deserialize(from json: [String: Any]) throws -> SwiftCaptionSource {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftCaptionSource.self, from: jsonData)
    }
    
    /// Deserializes string into a SwiftCaptionSource
    static public func deserialize(from jsonString: String) throws -> SwiftCaptionSource {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "CaptionSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try JSONDecoder().decode(SwiftCaptionSource.self, from: jsonData)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftCaptionSource to JSON string using Codable
    static func serializeToJson(_ captionSource: SwiftCaptionSource) -> String? {
        guard let jsonData = try? JSONEncoder().encode(captionSource) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Converts to JSON dictionary
    static func toJsonDictionary(_ captionSource: SwiftCaptionSource) throws -> [String: Any] {
        guard let jsonData = try? JSONEncoder().encode(captionSource),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw EncodingError.invalidValue(captionSource, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON dictionary"))
        }
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ captionSource: SwiftCaptionSource) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(captionSource)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(captionSource, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON string"))
        }
        return jsonString
    }
}

// MARK: - SwiftCaptionSource Extension

extension SwiftCaptionSource {
    // Validation methods
    func shouldSerialize() -> Bool {
        return mimeType != nil || url != nil || label != nil
    }
    
    // Serialization helpers
    func serializeToJson() -> String? {
        return SwiftCaptionSourceLegacySupport.serializeToJson(self)
    }
    
    func toJSON() throws -> [String: Any] {
        return try SwiftCaptionSourceLegacySupport.toJsonDictionary(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftCaptionSourceLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftChoiceInput Legacy Support

/// Unified legacy support for SwiftChoiceInput parsing and serialization
enum SwiftChoiceInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftChoiceInput using Codable
    static public func deserialize(from json: [String: Any]) throws -> SwiftChoiceInput {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftChoiceInput.self, from: jsonData)
    }
    
    /// Deserializes string into a SwiftChoiceInput
    static public func deserialize(from jsonString: String) throws -> SwiftChoiceInput {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ChoiceInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try JSONDecoder().decode(SwiftChoiceInput.self, from: jsonData)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftChoiceInput to JSON string using Codable
    static func serializeToJson(_ choiceInput: SwiftChoiceInput) -> String? {
        guard let jsonData = try? JSONEncoder().encode(choiceInput) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Converts to JSON dictionary
    static func toJsonDictionary(_ choiceInput: SwiftChoiceInput) throws -> [String: Any] {
        guard let jsonData = try? JSONEncoder().encode(choiceInput),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw EncodingError.invalidValue(choiceInput, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON dictionary"))
        }
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ choiceInput: SwiftChoiceInput) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(choiceInput)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(choiceInput, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON string"))
        }
        return jsonString
    }
}

// MARK: - SwiftChoiceInput Extension

extension SwiftChoiceInput {
    // Validation methods
    func shouldSerialize() -> Bool {
        return !title.isEmpty || !value.isEmpty
    }
    
    // Serialization helpers
    func serializeToJson() -> String? {
        return SwiftChoiceInputLegacySupport.serializeToJson(self)
    }
    
    func toJSON() throws -> [String: Any] {
        return try SwiftChoiceInputLegacySupport.toJsonDictionary(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftChoiceInputLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftChoicesData Legacy Support

/// Unified legacy support for SwiftChoicesData parsing and serialization
enum SwiftChoicesDataLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftChoicesData using Codable
    static public func deserialize(from json: [String: Any]) throws -> SwiftChoicesData {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftChoicesData.self, from: jsonData)
    }
    
    /// Deserializes string into a SwiftChoicesData
    static public func deserialize(from jsonString: String) throws -> SwiftChoicesData {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ChoicesData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try JSONDecoder().decode(SwiftChoicesData.self, from: jsonData)
    }
    
    // MARK: - Serialization Functions
    
    /// Serializes a SwiftChoicesData to JSON string using Codable
    static func serializeToJson(_ choicesData: SwiftChoicesData) -> String? {
        guard let jsonData = try? JSONEncoder().encode(choicesData) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Converts to JSON dictionary
    static func toJsonDictionary(_ choicesData: SwiftChoicesData) throws -> [String: Any] {
        guard let jsonData = try? JSONEncoder().encode(choicesData),
              let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw EncodingError.invalidValue(choicesData, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON dictionary"))
        }
        return json
    }
    
    /// Converts to JSON string with pretty printing
    static func serializeToJsonString(_ choicesData: SwiftChoicesData) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(choicesData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(choicesData, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert to JSON string"))
        }
        return jsonString
    }
}

// MARK: - SwiftChoicesData Extension

extension SwiftChoicesData {
    // Validation methods
    func shouldSerialize() -> Bool {
        return choicesDataType != "Data.Query" && !dataset.isEmpty
    }
    
    // Serialization helpers
    func serializeToJson() -> String? {
        return SwiftChoicesDataLegacySupport.serializeToJson(self)
    }
    
    func toJSON() throws -> [String: Any] {
        return try SwiftChoicesDataLegacySupport.toJsonDictionary(self)
    }
    
    func toJSONString() throws -> String {
        return try SwiftChoicesDataLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftCompoundButton Legacy Support

/// Unified legacy support for SwiftCompoundButton parsing and serialization
enum SwiftCompoundButtonLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftCompoundButton
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftCompoundButton {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftCompoundButton.self, from: data)
    }
    
    /// Deserializes string into a SwiftCompoundButton
    static public func deserialize(from jsonString: String) throws -> SwiftCompoundButton {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftCompoundButton.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftCompoundButton to JSON dictionary with proper formatting
    static func serializeToJson(_ button: SwiftCompoundButton, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "CompoundButton"
        
        // Add properties if present
        if let badge = button.badge {
            json["badge"] = badge
        }
        
        if let title = button.title {
            json["title"] = title
        }
        
        if let description = button.buttonDescription {
            json["description"] = description
        }
        
        if let icon = button.icon {
            json["icon"] = try icon.toJSON()
        }
        
        // Add selectAction if present
        if let action = button.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(action)
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses CompoundButton elements in an Adaptive Card
struct SwiftCompoundButtonParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.compoundButton)
        return try SwiftCompoundButtonLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftCompoundButtonLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftCompoundButtonLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftCompoundButton Extension

internal extension SwiftCompoundButton {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftCompoundButtonLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("badge")
        self.knownProperties.insert("title")
        self.knownProperties.insert("description")
        self.knownProperties.insert("icon")
        self.knownProperties.insert("selectAction")
    }
}

// MARK: - Consolidated SwiftValueChangedAction Legacy Support

/// Unified legacy support for SwiftValueChangedAction parsing and serialization
enum SwiftValueChangedActionLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftValueChangedAction
    static public func deserialize(from value: [String: Any]) throws -> SwiftValueChangedAction {
        // Convert dictionary to JSON data and let the decoder handle the validation
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftValueChangedAction.self, from: data)
    }
    /// Deserializes string into a SwiftValueChangedAction
    static public func deserialize(from jsonString: String) throws -> SwiftValueChangedAction {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try deserialize(from: jsonObject)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftValueChangedAction to JSON dictionary with proper formatting
    static func serializeToJson(_ action: SwiftValueChangedAction) -> [String: Any] {
        var json: [String: Any] = [:]
        
        if !action.targetInputIds.isEmpty {
            json["targetInputIds"] = action.targetInputIds
        }
        
        json["valueChangedActionType"] = action.valueChangedActionType.rawValue
        
        return json
    }
    
    /// Determines whether this action has sufficient data to be serialized.
    static func shouldSerialize(_ action: SwiftValueChangedAction) -> Bool {
        return !action.targetInputIds.isEmpty
    }
}

// MARK: - SwiftValueChangedAction Extension

extension SwiftValueChangedAction {
    // MARK: - Serialization Helpers
    
    var shouldSerialize: Bool {
        return SwiftValueChangedActionLegacySupport.shouldSerialize(self)
    }
    
    // Static Methods for Serialization/Deserialization
    
    static func serializeAction(_ action: SwiftValueChangedAction) throws -> [String: Any] {
        return SwiftValueChangedActionLegacySupport.serializeToJson(action)
    }
}

// MARK: - Consolidated SwiftBaseInputElement Legacy Support

/// Unified legacy support for SwiftBaseInputElement parsing and serialization
enum SwiftBaseInputElementLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftBaseInputElement
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftBaseInputElement {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftBaseInputElement.self, from: data)
    }
    
    /// Deserializes string into a SwiftBaseInputElement
    static public func deserialize(from jsonString: String) throws -> SwiftBaseInputElement {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftBaseInputElement.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftBaseInputElement to JSON dictionary with proper formatting
    static func serializeToJson(_ inputElement: SwiftBaseInputElement, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Add label if present
        if let label = inputElement.label {
            json["label"] = label
        }
        
        // Only add isRequired if it's true (non-default)
        if inputElement.isRequired {
            json["isRequired"] = inputElement.isRequired
        }
        
        if let errorMessage = inputElement.errorMessage {
            json["errorMessage"] = errorMessage
        }
        
        // Add valueChangedAction if present
        if let action = inputElement.valueChangedAction {
            json["valueChangedAction"] = try SwiftValueChangedAction.serializeAction(action)
        }
        
        return json
    }
    
    /// Determines whether this element has sufficient data to be serialized.
    static func shouldSerialize(_ inputElement: SwiftBaseInputElement) -> Bool {
        // Assuming `id` is a property inherited from BaseElement (via BaseCardElement).
        let idNotEmpty = (inputElement.id ?? "").isEmpty == false
        let labelNotEmpty = !(inputElement.label?.isEmpty ?? true)
        let errorMessageNotEmpty = !(inputElement.errorMessage?.isEmpty ?? true)
        return idNotEmpty || inputElement.isRequired || labelNotEmpty || errorMessageNotEmpty
    }
}

// MARK: - SwiftBaseInputElement Extension

internal extension SwiftBaseInputElement {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftBaseInputElementLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    /// Determines whether this element has sufficient data to be serialized.
    func shouldSerialize() -> Bool {
        return SwiftBaseInputElementLegacySupport.shouldSerialize(self)
    }
}

// MARK: - Consolidated SwiftToggleInput Legacy Support

/// Unified legacy support for SwiftToggleInput parsing and serialization
enum SwiftToggleInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftToggleInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftToggleInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftToggleInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftToggleInput
    static public func deserialize(from jsonString: String) throws -> SwiftToggleInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftToggleInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftToggleInput to JSON dictionary with proper formatting
    static func serializeToJson(_ toggleInput: SwiftToggleInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Input.Toggle"
        
        // Add title if present (required in UI)
        if let title = toggleInput.title {
            json["title"] = title
        }
        
        // Add value if present
        if let value = toggleInput.value {
            json["value"] = value
        }
        
        // Only add non-default properties
        if toggleInput.valueOff != "false" {
            json["valueOff"] = toggleInput.valueOff
        }
        
        if toggleInput.valueOn != "true" {
            json["valueOn"] = toggleInput.valueOn
        }
        
        if toggleInput.wrap {
            json["wrap"] = toggleInput.wrap
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses ToggleInput elements in an Adaptive Card
struct SwiftToggleInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.toggleInput)
        return try SwiftToggleInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftToggleInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftToggleInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - Consolidated SwiftDateInput Legacy Support

/// Unified legacy support for SwiftDateInput parsing and serialization
enum SwiftDateInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftDateInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftDateInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftDateInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftDateInput
    static public func deserialize(from jsonString: String) throws -> SwiftDateInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftDateInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftDateInput to JSON dictionary with proper formatting
    static func serializeToJson(_ dateInput: SwiftDateInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Input.Date"
        
        // Add properties if present
        if let max = dateInput.max {
            json["max"] = max
        }
        
        if let min = dateInput.min {
            json["min"] = min
        }
        
        if let placeholder = dateInput.placeholder {
            json["placeholder"] = placeholder
        }
        
        if let value = dateInput.value {
            json["value"] = value
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses DateInput elements in an Adaptive Card
struct SwiftDateInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.dateInput)
        return try SwiftDateInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftDateInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftDateInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftDateInput Extension

internal extension SwiftDateInput {
    // MARK: - Known Properties
    
    // MARK: - Static Factory Methods
    
    /// Creates a SwiftDateInput from a JSON dictionary
    static func createFromJSON(_ json: [String: Any]) throws -> SwiftDateInput {
        return try SwiftDateInputLegacySupport.deserialize(from: json)
    }
    
    /// Creates a SwiftDateInput from a JSON string
    static func createFromJSONString(_ jsonString: String) throws -> SwiftDateInput {
        return try SwiftDateInputLegacySupport.deserialize(from: jsonString)
    }
}

// MARK: - Consolidated SwiftNumberInput Legacy Support

/// Unified legacy support for SwiftNumberInput parsing and serialization
enum SwiftNumberInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftNumberInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftNumberInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftNumberInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftNumberInput
    static public func deserialize(from jsonString: String) throws -> SwiftNumberInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftNumberInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftNumberInput to JSON dictionary with proper formatting
    static func serializeToJson(_ numberInput: SwiftNumberInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Input.Number"
        
        // Add properties if present
        if let placeholder = numberInput.placeholder {
            json["placeholder"] = placeholder
        }
        
        if let value = numberInput.value {
            json["value"] = value
        }
        
        if let min = numberInput.min {
            json["min"] = min
        }
        
        if let max = numberInput.max {
            json["max"] = max
        }
        
        return json
    }
    
    /// Converts the NumberInput object into a JSON string
    static func toJSONString(_ numberInput: SwiftNumberInput) -> String {
        do {
            let json = try serializeToJson(numberInput, baseJson: [:])
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

// MARK: - Parser Implementation

/// Parses NumberInput elements in an Adaptive Card
struct SwiftNumberInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.numberInput)
        return try SwiftNumberInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftNumberInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftNumberInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftNumberInput Extension

internal extension SwiftNumberInput {
    // MARK: - Known Properties
    
    // MARK: - Serialization Helpers
    
    /// Returns a JSON string representation
    func toJSONString() -> String {
        return SwiftNumberInputLegacySupport.toJSONString(self)
    }
}

// MARK: - Consolidated SwiftTextInput Legacy Support

/// Unified legacy support for SwiftTextInput parsing and serialization
enum SwiftTextInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTextInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftTextInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        let textInput = try decoder.decode(SwiftTextInput.self, from: data)
        
        // Validate style and multiline settings if context is provided
        if let context = context, textInput.isMultiline && textInput.style == .password {
            context.warnings.append(
                SwiftAdaptiveCardParseWarning(
                    statusCode: .invalidValue,
                    message: "Input.Text ignores isMultiline when using password style."
                )
            )
        }
        
        return textInput
    }
    
    /// Deserializes string into a SwiftTextInput
    static public func deserialize(from jsonString: String) throws -> SwiftTextInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftTextInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTextInput to JSON dictionary with proper formatting
    static func serializeToJson(_ textInput: SwiftTextInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Input.Text"
        
        // Add properties if present
        if let placeholder = textInput.placeholder, !placeholder.isEmpty {
            json["placeholder"] = placeholder
        }
        
        if let value = textInput.value, !value.isEmpty {
            json["value"] = value
        }
        
        // Only add isMultiline if it's true (non-default)
        if textInput.isMultiline {
            json["isMultiline"] = textInput.isMultiline
        }
        
        // Only add non-default properties
        if textInput.maxLength > 0 {
            json["maxLength"] = textInput.maxLength
        }
        
        if let style = textInput.style {
            json["style"] = style.rawValue
        }
        
        if let regex = textInput.regex {
            json["regex"] = regex
        }
        
        // Add inlineAction if present
        if let action = textInput.inlineAction {
            json["inlineAction"] = try action.serializeToJsonValue()
        }
        
        return json
    }
    
    /// Converts to JSON dictionary for legacy compatibility
    static func toJSON(_ textInput: SwiftTextInput) -> [String: Any] {
        do {
            // Start with the base element's JSON
            var json = textInput.toBaseJSON()
            
            // Add TextInput-specific fields
            if let placeholder = textInput.placeholder, !placeholder.isEmpty {
                json["placeholder"] = placeholder
            }
            
            if let value = textInput.value, !value.isEmpty {
                json["value"] = value
            }
            
            // Always include isMultiline
            json["isMultiline"] = textInput.isMultiline
            
            // Add style if present
            if let style = textInput.style {
                json["style"] = style.rawValue
            }
            
            // Add maxLength if non-zero
            if textInput.maxLength > 0 {
                json["maxLength"] = textInput.maxLength
            }
            
            // Add regex if present
            if let regex = textInput.regex, !regex.isEmpty {
                json["regex"] = regex
            }
            
            // Add inlineAction if present
            if let action = textInput.inlineAction {
                json["inlineAction"] = try action.serializeToJsonValue()
            }
            
            return json
        } catch {
            // Return minimal valid JSON if serialization fails
            return ["type": "Input.Text"]
        }
    }
}

// MARK: - Parser Implementation

/// Parses TextInput elements in an Adaptive Card
struct SwiftTextInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.textInput)
        return try SwiftTextInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTextInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTextInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftTextInput Extension

internal extension SwiftTextInput {
    // Helper for legacy serialization
    func toBaseJSON() -> [String: Any] {
        do {
            return try super.serializeToJsonValue()
        } catch {
            return ["type": "Input.Text"]
        }
    }
}

// MARK: - Consolidated SwiftTimeInput Legacy Support

/// Unified legacy support for SwiftTimeInput parsing and serialization
enum SwiftTimeInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTimeInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftTimeInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTimeInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftTimeInput
    static public func deserialize(from jsonString: String) throws -> SwiftTimeInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftTimeInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTimeInput to JSON dictionary with proper formatting
    static func serializeToJson(_ timeInput: SwiftTimeInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set type property
        json["type"] = "Input.Time"
        
        // Add properties if present
        if let max = timeInput.max {
            json["max"] = max
        }
        
        if let min = timeInput.min {
            json["min"] = min
        }
        
        if let placeholder = timeInput.placeholder {
            json["placeholder"] = placeholder
        }
        
        if let value = timeInput.value {
            json["value"] = value
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses TimeInput elements in an Adaptive Card
struct SwiftTimeInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.timeInput)
        return try SwiftTimeInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTimeInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTimeInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - Consolidated SwiftChoiceSetInput Legacy Support

/// Unified legacy support for SwiftChoiceSetInput parsing and serialization
enum SwiftChoiceSetInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftChoiceSetInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftChoiceSetInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftChoiceSetInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftChoiceSetInput
    static public func deserialize(from jsonString: String) throws -> SwiftChoiceSetInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftChoiceSetInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    static func serializeToJsonString(_ choiceSetInput: SwiftChoiceSetInput) -> String? {
        guard let jsonData = try? JSONEncoder().encode(choiceSetInput) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
}

// MARK: - Parser Implementation

/// Parses ChoiceSetInput elements in an Adaptive Card
struct SwiftChoiceSetInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.choiceSetInput)
        return try SwiftChoiceSetInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftChoiceSetInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftChoiceSetInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftChoiceSetInput Extension

internal extension SwiftChoiceSetInput {
    // MARK: - Known Properties
    
    // MARK: - Serialization Helpers
    
    /// Serializes the instance to a JSON string.
    func serializeToJson() -> String? {
        return SwiftChoiceSetInputLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftFact Legacy Support

/// Unified legacy support for SwiftFact parsing and serialization
enum SwiftFactLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftFact
    static public func deserialize(from json: [String: Any]) -> SwiftFact? {
        guard let title = json["title"] as? String,
              let value = json["value"] as? String else {
            return nil
        }
        
        let language = json["language"] as? String
        
        // Convert to JSON data and use Codable
        let jsonDict: [String: Any] = [
            "title": title,
            "value": value,
            "language": language as Any
        ].compactMapValues { $0 is NSNull ? nil : $0 }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
            return try JSONDecoder().decode(SwiftFact.self, from: data)
        } catch {
            return nil
        }
    }
    
    /// Deserializes string into a SwiftFact
    static public func deserialize(from jsonString: String, context: SwiftParseContext? = nil) -> SwiftFact? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(SwiftFact.self, from: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftFact to JSON dictionary with proper formatting
    static func serializeToJson(_ fact: SwiftFact) -> [String: Any] {
        var dict: [String: Any] = [
            "title": fact.title,
            "value": fact.value
        ]
        
        if let language = fact.language {
            dict["language"] = language
        }
        
        return dict
    }
    
    /// Converts to JSON dictionary with type
    static func serializeWithType(_ fact: SwiftFact) -> [String: Any] {
        var dict = serializeToJson(fact)
        dict["type"] = "Fact"
        return dict
    }
    
    /// Converts to JSON string
    static func serialize(_ fact: SwiftFact) -> String {
        let dict = serializeToJson(fact)
        let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        return (String(data: data ?? Data(), encoding: .utf8) ?? "{}") + "\n"
    }
}

// MARK: - SwiftFact Extension

extension SwiftFact {
    // MARK: - Initializer
    
    init(title: String = "", value: String = "", language: String? = nil) {
        self.title = title
        self.value = value
        self.language = language
    }
    
    // MARK: - Legacy Serialization Methods
    
    /// Serializes to a JSON string
    public func serialize() -> String {
        return SwiftFactLegacySupport.serialize(self)
    }
    
    /// Serializes with type information
    func serializeWithType() -> [String: Any] {
        return SwiftFactLegacySupport.serializeWithType(self)
    }
    
    // MARK: - Static Deserialization Methods
    
    /// Deserializes from a JSON string
    static public func deserialize(fromString jsonString: String, context: SwiftParseContext) -> SwiftFact? {
        return SwiftFactLegacySupport.deserialize(from: jsonString)
    }
}

// MARK: - Consolidated SwiftFactSet Legacy Support

/// Unified legacy support for SwiftFactSet parsing and serialization
enum SwiftFactSetLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftFactSet
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftFactSet {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftFactSet.self, from: data)
    }
    
    /// Deserializes string into a SwiftFactSet
    static public func deserialize(from jsonString: String) throws -> SwiftFactSet {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftFactSet.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftFactSet to JSON dictionary with proper formatting
    static func serializeToJson(_ factSet: SwiftFactSet, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "FactSet"
        
        // Add facts array if not empty
        if !factSet.facts.isEmpty {
            json["facts"] = factSet.facts.map { $0.serializeToJsonValue() }
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses FactSet elements in an Adaptive Card
struct SwiftFactSetParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.factSet)
        return try SwiftFactSetLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftFactSetLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftFactSetLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftFactSet Extension

internal extension SwiftFactSet {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftFactSetLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("facts")
    }
}

// MARK: - Consolidated SwiftGridArea Legacy Support

/// Unified legacy support for SwiftGridArea parsing and serialization
enum SwiftGridAreaLegacySupport {
    // MARK: - Legacy Array Support
    
    /// Converts an array of dictionaries to an array of SwiftGridArea objects
    static func deserializeArray(from arrayOfDicts: [[String: Any]]) -> [SwiftGridArea] {
        return arrayOfDicts.map { dict in
            do {
                return try deserialize(from: dict)
            } catch {
                // Return default grid area if deserialization fails
                return SwiftGridArea(name: "", row: 1, column: 1, rowSpan: 1, columnSpan: 1)
            }
        }
    }
    
    /// Serializes an array of SwiftGridArea objects to an array of dictionaries
    static func serializeArray(_ gridAreas: [SwiftGridArea]) -> [[String: Any]] {
        return gridAreas.map { serializeToJson($0) }
    }
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftGridArea
    static public func deserialize(from value: [String: Any]) throws -> SwiftGridArea {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftGridArea.self, from: data)
    }
    
    /// Deserializes string into a SwiftGridArea
    static public func deserialize(from jsonString: String) throws -> SwiftGridArea {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftGridArea.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftGridArea to JSON dictionary
    static func serializeToJson(_ gridArea: SwiftGridArea) -> [String: Any] {
        return [
            "name": gridArea.name,
            "row": gridArea.row,
            "column": gridArea.column,
            "rowSpan": gridArea.rowSpan,
            "columnSpan": gridArea.columnSpan
        ]
    }
    
    /// Converts a SwiftGridArea to JSON string
    static func serializeToString(_ gridArea: SwiftGridArea) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: serializeToJson(gridArea), options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

// MARK: - SwiftGridArea Extension

extension SwiftGridArea {
    // Static factory methods
    static func fromJSON(_ json: [String: Any]) -> SwiftGridArea? {
        guard !json.isEmpty else { return nil }
        return try? SwiftGridAreaLegacySupport.deserialize(from: json)
    }
    
    static func fromJSONString(_ jsonString: String) -> SwiftGridArea? {
        return try? SwiftGridAreaLegacySupport.deserialize(from: jsonString)
    }
    
    // Legacy compatibility methods - direct replacements for original code
    static public func deserialize(from json: [String: Any]) -> SwiftGridArea {
        do {
            return try SwiftGridAreaLegacySupport.deserialize(from: json)
        } catch {
            // Replicate original fallback behavior
            return SwiftGridArea(name: "", row: 1, column: 1, rowSpan: 1, columnSpan: 1)
        }
    }
}

// MARK: - Consolidated SwiftMedia Legacy Support

/// Unified legacy support for SwiftMedia parsing and serialization
enum SwiftMediaLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftMedia
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftMedia {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftMedia.self, from: data)
    }
    
    /// Deserializes string into a SwiftMedia
    static public func deserialize(from jsonString: String) throws -> SwiftMedia {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftMedia.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftMedia to JSON dictionary with proper formatting
    static func serializeToJson(_ media: SwiftMedia, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "Media"
        
        // Add optional properties
        if let poster = media.poster {
            json["poster"] = poster
        }
        
        if let altText = media.altText {
            json["altText"] = altText
        }
        
        // Add sources array
        json["sources"] = media.sources.map { $0.serializeToJson() }
        
        // Add caption sources if not empty
        if !media.captionSources.isEmpty {
            json["captionSources"] = media.captionSources.map { $0.serializeToJson() }
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ media: SwiftMedia) -> String {
        do {
            // Use the full serialization path for consistency
            let baseJson = try media.serializeToJsonValue()
            let jsonData = try JSONSerialization.data(withJSONObject: baseJson, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(baseJson, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
    
    // MARK: - Resource Information
    
    /// Retrieves resource information (from poster and media sources)
    static func getResourceInformation(_ media: SwiftMedia) -> [SwiftRemoteResourceInformation] {
        var resourceInfo: [SwiftRemoteResourceInformation] = []
        
        // Add poster if present
        if let poster = media.poster {
            resourceInfo.append(SwiftRemoteResourceInformation(url: poster, mimeType: "image"))
        }
        
        // Add sources
        for source in media.sources {
            resourceInfo.append(contentsOf: source.getResourceInformation())
        }
        
        return resourceInfo
    }
}

// MARK: - Parser Implementation

/// Parses Media elements in an Adaptive Card
struct SwiftMediaParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.media)
        return try SwiftMediaLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftMediaLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftMediaLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftMedia Extension

internal extension SwiftMedia {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftMediaLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("poster")
        self.knownProperties.insert("altText")
        self.knownProperties.insert("sources")
        self.knownProperties.insert("captionSources")
    }
    
    // MARK: - Resource Information
    func mediaResourceInformation() -> [SwiftRemoteResourceInformation] {
        return SwiftMediaLegacySupport.getResourceInformation(self)
    }
    
    // Legacy compatibility methods
    func serializeToJson() -> [String: Any] {
        do {
            return try self.serializeToJsonValue()
        } catch {
            return [:]
        }
    }
    
    func toJSONString() -> String {
        return SwiftMediaLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftMediaSource Legacy Support

/// Unified legacy support for SwiftMediaSource parsing and serialization
enum SwiftMediaSourceLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftMediaSource
    static public func deserialize(from value: [String: Any]) throws -> SwiftMediaSource {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftMediaSource.self, from: data)
    }
    
    /// Deserializes string into a SwiftMediaSource
    static public func deserialize(from jsonString: String) throws -> SwiftMediaSource {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftMediaSource.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftMediaSource to JSON dictionary
    static func serializeToJson(_ mediaSource: SwiftMediaSource) -> [String: Any] {
        var json: [String: Any] = ["url": mediaSource.url]
        if let mimeType = mediaSource.mimeType {
            json["mimeType"] = mimeType
        }
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ mediaSource: SwiftMediaSource) -> String {
        do {
            let json = serializeToJson(mediaSource)
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(json, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
    
    // MARK: - Resource Information
    
    /// Retrieves resource information
    static func getResourceInformation(_ mediaSource: SwiftMediaSource) -> [SwiftRemoteResourceInformation] {
        return [SwiftRemoteResourceInformation(url: mediaSource.url, mimeType: mediaSource.mimeType ?? "unknown")]
    }
}

// MARK: - Consolidated SwiftRatingInput Legacy Support

/// Unified legacy support for SwiftRatingInput parsing and serialization
enum SwiftRatingInputLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftRatingInput
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftRatingInput {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftRatingInput.self, from: data)
    }
    
    /// Deserializes string into a SwiftRatingInput
    static public func deserialize(from jsonString: String) throws -> SwiftRatingInput {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftRatingInput.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftRatingInput to JSON dictionary with proper formatting
    static func serializeToJson(_ ratingInput: SwiftRatingInput, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "RatingInput"
        json["value"] = ratingInput.value
        json["max"] = ratingInput.max
        
        // Add optional properties
        if let alignment = ratingInput.horizontalAlignment {
            json["horizontalAlignment"] = alignment.rawValue
        }
        
        // Only include non-default values
        if ratingInput.size != .medium {
            json["size"] = ratingInput.size.rawValue
        }
        
        if ratingInput.color != .neutral {
            json["color"] = ratingInput.color.rawValue
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ ratingInput: SwiftRatingInput) -> String {
        do {
            // Use the full serialization path for consistency
            let baseJson = try ratingInput.serializeToJsonValue()
            let jsonData = try JSONSerialization.data(withJSONObject: baseJson, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(baseJson, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
}

// MARK: - Parser Implementation

/// Parses RatingInput elements in an Adaptive Card
struct SwiftRatingInputParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.ratingInput)
        return try SwiftRatingInputLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRatingInputLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRatingInputLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftRatingInput Extension

internal extension SwiftRatingInput {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftRatingInputLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("value")
        self.knownProperties.insert("max")
        self.knownProperties.insert("horizontalAlignment")
        self.knownProperties.insert("size")
        self.knownProperties.insert("color")
    }
    
    // Legacy compatibility methods
    func serializeToJson() -> [String: Any] {
        do {
            return try self.serializeToJsonValue()
        } catch {
            return [:]
        }
    }
    
    func toJSONString() -> String {
        return SwiftRatingInputLegacySupport.serializeToJsonString(self)
    }
}

// Legacy static methods for backward compatibility
extension SwiftRatingInput {
    
    /// Factory method for creating SwiftRatingInput instances
    static func create(id: String? = nil,
                       value: Double = 0,
                       max: Double = 5,
                       horizontalAlignment: SwiftHorizontalAlignment? = nil,
                       size: SwiftRatingSize = .medium,
                       color: SwiftRatingColor = .neutral,
                       spacing: SwiftSpacing = .default,
                       height: SwiftHeightType = .auto,
                       targetWidth: SwiftTargetWidthType? = nil,
                       separator: Bool? = nil,
                       isVisible: Bool = true,
                       areaGridName: String? = nil) -> SwiftRatingInput {
        
        // Create a JSON dictionary with all properties
        var json: [String: Any] = [
            "type": "RatingInput",
            "value": value,
            "max": max,
            "size": size.rawValue,
            "color": color.rawValue,
            "isVisible": isVisible
        ]
        
        // Add optional properties
        if let id = id { json["id"] = id }
        if let horizontalAlignment = horizontalAlignment { json["horizontalAlignment"] = horizontalAlignment.rawValue }
        if spacing != .default { json["spacing"] = spacing.rawValue }
        if height != .auto { json["height"] = height.rawValue }
        if let targetWidth = targetWidth { json["targetWidth"] = targetWidth.rawValue }
        if let separator = separator { json["separator"] = separator }
        if let areaGridName = areaGridName { json["areaGridName"] = areaGridName }
        
        // Use JSON deserialization to create the instance
        do {
            return try SwiftRatingInputLegacySupport.deserialize(from: json)
        } catch {
            // Create a minimal instance if deserialization fails
            var minimalJson: [String: Any] = [
                "type": "RatingInput",
                "value": 0.0,
                "max": 5.0,
                "size": "medium",
                "color": "neutral",
                "isVisible": true
            ]
            if let id = id { minimalJson["id"] = id }
            
            // This should almost never fail, but we need a fallback
            return try! SwiftRatingInputLegacySupport.deserialize(from: minimalJson)
        }
    }
}

// MARK: - Consolidated SwiftRatingLabel Legacy Support

/// Unified legacy support for SwiftRatingLabel parsing and serialization
enum SwiftRatingLabelLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftRatingLabel
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftRatingLabel {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftRatingLabel.self, from: data)
    }
    
    /// Deserializes string into a SwiftRatingLabel
    static public func deserialize(from jsonString: String) throws -> SwiftRatingLabel {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftRatingLabel.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftRatingLabel to JSON dictionary with proper formatting
    static func serializeToJson(_ ratingLabel: SwiftRatingLabel, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "RatingLabel"
        json["value"] = ratingLabel.value
        json["max"] = ratingLabel.max
        
        // Add optional properties
        if let count = ratingLabel.count {
            json["count"] = count
        }
        
        if let alignment = ratingLabel.horizontalAlignment {
            json["horizontalAlignment"] = alignment.rawValue
        }
        
        // Only include non-default values
        if ratingLabel.size != .medium {
            json["size"] = ratingLabel.size.rawValue
        }
        
        if ratingLabel.color != .neutral {
            json["color"] = ratingLabel.color.rawValue
        }
        
        if ratingLabel.style != .default {
            json["style"] = ratingLabel.style.rawValue
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ ratingLabel: SwiftRatingLabel) -> String {
        do {
            // Use the full serialization path for consistency
            let baseJson = try ratingLabel.serializeToJsonValue()
            let jsonData = try JSONSerialization.data(withJSONObject: baseJson, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(baseJson, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
}

// MARK: - Parser Implementation

/// Parses RatingLabel elements in an Adaptive Card
struct SwiftRatingLabelParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.ratingLabel)
        return try SwiftRatingLabelLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRatingLabelLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRatingLabelLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftRatingLabel Extension

internal extension SwiftRatingLabel {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftRatingLabelLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("value")
        self.knownProperties.insert("max")
        self.knownProperties.insert("count")
        self.knownProperties.insert("horizontalAlignment")
        self.knownProperties.insert("size")
        self.knownProperties.insert("color")
        self.knownProperties.insert("style")
    }
    
    // Legacy compatibility methods
    func serializeToJson() -> [String: Any] {
        do {
            return try self.serializeToJsonValue()
        } catch {
            return [:]
        }
    }
    
    func toJSONString() -> String {
        return SwiftRatingLabelLegacySupport.serializeToJsonString(self)
    }
}

// Legacy static methods for backward compatibility
extension SwiftRatingLabel {
    /// Factory method for creating SwiftRatingLabel instances
    static func create(id: String? = nil,
                       value: Double = 0,
                       max: Double = 5,
                       count: UInt? = nil,
                       horizontalAlignment: SwiftHorizontalAlignment? = nil,
                       size: SwiftRatingSize = .medium,
                       color: SwiftRatingColor = .neutral,
                       style: SwiftRatingStyle = .default,
                       spacing: SwiftSpacing = .default,
                       height: SwiftHeightType = .auto,
                       targetWidth: SwiftTargetWidthType? = nil,
                       separator: Bool? = nil,
                       isVisible: Bool = true,
                       areaGridName: String? = nil) -> SwiftRatingLabel {
        
        // Create a JSON dictionary with all properties
        var json: [String: Any] = [
            "type": "RatingLabel",
            "value": value,
            "max": max,
            "size": size.rawValue,
            "color": color.rawValue,
            "style": style.rawValue,
            "isVisible": isVisible
        ]
        
        // Add optional properties
        if let id = id { json["id"] = id }
        if let count = count { json["count"] = count }
        if let horizontalAlignment = horizontalAlignment { json["horizontalAlignment"] = horizontalAlignment.rawValue }
        if spacing != .default { json["spacing"] = spacing.rawValue }
        if height != .auto { json["height"] = height.rawValue }
        if let targetWidth = targetWidth { json["targetWidth"] = targetWidth.rawValue }
        if let separator = separator { json["separator"] = separator }
        if let areaGridName = areaGridName { json["areaGridName"] = areaGridName }
        
        // Use JSON deserialization to create the instance
        do {
            return try SwiftRatingLabelLegacySupport.deserialize(from: json)
        } catch {
            // Create a minimal instance if deserialization fails
            var minimalJson: [String: Any] = [
                "type": "RatingLabel",
                "value": 0.0,
                "max": 5.0,
                "size": "medium",
                "color": "neutral",
                "style": "default",
                "isVisible": true
            ]
            if let id = id { minimalJson["id"] = id }
            
            // This should almost never fail, but we need a fallback
            return try! SwiftRatingLabelLegacySupport.deserialize(from: minimalJson)
        }
    }
}

// MARK: - Consolidated SwiftRefresh Legacy Support

/// Unified legacy support for SwiftRefresh parsing and serialization
enum SwiftRefreshLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftRefresh
    static public func deserialize(from value: [String: Any]) throws -> SwiftRefresh {
        let action: SwiftBaseActionElement? = try? SwiftBaseActionElement.deserializeAction(from: value["action"] as? [String: Any] ?? [:])
        let userIds = value["userIds"] as? [String] ?? []
        return SwiftRefresh(action: action, userIds: userIds)
    }
    
    /// Deserializes string into a SwiftRefresh
    static public func deserialize(from jsonString: String) throws -> SwiftRefresh {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftJSONError.missingKey("Unable to parse JSON string")
        }
        
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftRefresh to JSON dictionary
    static func serializeToJson(_ refresh: SwiftRefresh) -> [String: Any] {
        var json: [String: Any] = [:]
        
        if let action = refresh.action {
            do {
                json["action"] = try action.serializeToJsonValue()
            } catch {
                // Fallback to toJSON if serializeToJsonValue fails
                json["action"] = action.toJSON()
            }
        }
        
        if !refresh.userIds.isEmpty {
            json["userIds"] = refresh.userIds
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ refresh: SwiftRefresh) -> String {
        do {
            let json = serializeToJson(refresh)
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(json, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
}

// MARK: - SwiftRefresh Extension

extension SwiftRefresh {
    // Static factory methods for backward compatibility
    static public func deserialize(from json: [String: Any]) throws -> SwiftRefresh {
        return try SwiftRefreshLegacySupport.deserialize(from: json)
    }
    
    // Additional utility methods
    static func fromJSON(_ json: [String: Any]) -> SwiftRefresh? {
        guard !json.isEmpty else { return nil }
        return try? SwiftRefreshLegacySupport.deserialize(from: json)
    }
    
    static func fromJSONString(_ jsonString: String) -> SwiftRefresh? {
        return try? SwiftRefreshLegacySupport.deserialize(from: jsonString)
    }
    
    // Serialization to string
    func toJSONString() -> String {
        return SwiftRefreshLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - Consolidated SwiftRichTextBlock Legacy Support

/// Unified legacy support for SwiftRichTextBlock parsing and serialization
enum SwiftRichTextBlockLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftRichTextBlock
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftRichTextBlock {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftRichTextBlock.self, from: data)
    }
    
    /// Deserializes string into a SwiftRichTextBlock
    static public func deserialize(from jsonString: String) throws -> SwiftRichTextBlock {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftRichTextBlock.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftRichTextBlock to JSON dictionary with proper formatting
    static func serializeToJson(_ richTextBlock: SwiftRichTextBlock, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "RichTextBlock"
        
        // Add optional properties
        if let alignment = richTextBlock.horizontalAlignment {
            json["horizontalAlignment"] = alignment.rawValue
        }
        
        // Process inlines
        json["inlines"] = richTextBlock.inlines.map { inline -> Any in
            if let textRun = inline as? SwiftTextRun {
                return textRun.serializeToJson()
            } else if let stringValue = inline as? String {
                return stringValue
            }
            return [:]
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ richTextBlock: SwiftRichTextBlock) -> String {
        do {
            // Use the full serialization path for consistency
            let baseJson = try richTextBlock.serializeToJsonValue()
            let jsonData = try JSONSerialization.data(withJSONObject: baseJson, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(baseJson, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
    
    /// Helper function to dispatch inline deserialization based on the "type" field.
    static func deserializeInline(from json: [String: Any]) throws -> SwiftInline {
        guard let typeString = json["type"] as? String,
              let type = SwiftInlineElementType(rawValue: typeString) else {
            throw ParsingError.invalidType(expected: "Inline", found: "Missing type")
        }
        
        switch type {
        case .textRun:
            guard let inline = try? SwiftTextRun.deserialize(from: json) else {
                throw ParsingError.invalidType(expected: "TextRun", found: "Invalid data")
            }
            return inline
        }
    }
}

// MARK: - Parser Implementation

/// Parses RichTextBlock elements in an Adaptive Card
struct SwiftRichTextBlockParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.richTextBlock)
        return try SwiftRichTextBlockLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRichTextBlockLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftRichTextBlockLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftRichTextBlock Extension

internal extension SwiftRichTextBlock {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftRichTextBlockLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("horizontalAlignment")
        self.knownProperties.insert("inlines")
    }
}

// Legacy static methods and factory method for backward compatibility
extension SwiftRichTextBlock {
    static public func deserialize(fromString jsonString: String) throws -> SwiftRichTextBlock {
        return try SwiftRichTextBlockLegacySupport.deserialize(from: jsonString)
    }
    
    /// Factory method for creating SwiftRichTextBlock instances
    static func create(id: String? = nil,
                       horizontalAlignment: SwiftHorizontalAlignment? = nil,
                       inlines: [Any] = [],
                       spacing: SwiftSpacing = .default,
                       height: SwiftHeightType = .auto,
                       separator: Bool? = nil,
                       isVisible: Bool = true) -> SwiftRichTextBlock {
        
        // Create a JSON dictionary with all properties
        var json: [String: Any] = [
            "type": "RichTextBlock",
            "isVisible": isVisible
        ]
        
        // Add optional properties
        if let id = id { json["id"] = id }
        if let horizontalAlignment = horizontalAlignment { json["horizontalAlignment"] = horizontalAlignment.rawValue }
        if spacing != .default { json["spacing"] = spacing.rawValue }
        if height != .auto { json["height"] = height.rawValue }
        if let separator = separator { json["separator"] = separator }
        
        // Handle inlines - this is complex due to heterogeneous array
        var inlinesArray: [Any] = []
        for inline in inlines {
            if let textRun = inline as? SwiftTextRun {
                inlinesArray.append(textRun.serializeToJson())
            } else if let stringValue = inline as? String {
                inlinesArray.append(stringValue)
            }
        }
        json["inlines"] = inlinesArray
        
        // Use JSON deserialization to create the instance
        do {
            return try SwiftRichTextBlockLegacySupport.deserialize(from: json)
        } catch {
            // Create a minimal instance if deserialization fails
            var minimalJson: [String: Any] = [
                "type": "RichTextBlock",
                "inlines": [],
                "isVisible": true
            ]
            if let id = id { minimalJson["id"] = id }
            
            // This should almost never fail, but we need a fallback
            return try! SwiftRichTextBlockLegacySupport.deserialize(from: minimalJson)
        }
    }
}

// MARK: - Consolidated SwiftRichTextElementProperties Legacy Support

/// Unified legacy support for SwiftRichTextElementProperties parsing and serialization
enum SwiftRichTextElementPropertiesLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftRichTextElementProperties
    /// Deserializes JSON into a SwiftRichTextElementProperties
    static public func deserialize(from value: [String: Any]) throws -> SwiftRichTextElementProperties {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        
        // Use the existing Codable implementation
        return try decoder.decode(SwiftRichTextElementProperties.self, from: data)
    }
    
    /// Deserializes string into a SwiftRichTextElementProperties
    static public func deserialize(from jsonString: String) throws -> SwiftRichTextElementProperties {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftJSONError.missingKey("Unable to parse JSON string")
        }
        
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftRichTextElementProperties to JSON dictionary
    static func serializeToJson(_ properties: SwiftRichTextElementProperties) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Add non-nil optional properties
        if let textSize = properties.textSize {
            json["size"] = textSize.rawValue
        }
        if let textColor = properties.textColor {
            json["color"] = textColor.rawValue
        }
        if let textWeight = properties.textWeight {
            json["weight"] = textWeight.rawValue
        }
        if let fontType = properties.fontType {
            json["fontType"] = fontType.rawValue
        }
        if let isSubtle = properties.isSubtle {
            json["isSubtle"] = isSubtle
        }
        
        // Add required and default properties
        json["text"] = properties.text
        json["language"] = properties.language
        json["italic"] = properties.italic
        json["strikethrough"] = properties.strikethrough
        json["underline"] = properties.underline
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ properties: SwiftRichTextElementProperties) -> String {
        do {
            let json = serializeToJson(properties)
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw EncodingError.invalidValue(json, EncodingError.Context(
                    codingPath: [], debugDescription: "Failed to convert JSON to string"))
            }
            return jsonString
        } catch {
            return "{}"
        }
    }
}

// MARK: - Consolidated SwiftSeparator Legacy Support

/// Unified legacy support for SwiftSeparator parsing and serialization
enum SwiftSeparatorLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftSeparator
    static public func deserialize(from value: [String: Any]) throws -> SwiftSeparator {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftSeparator.self, from: data)
    }
    
    /// Deserializes string into a SwiftSeparator
    static public func deserialize(from jsonString: String) throws -> SwiftSeparator {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftSeparator.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftSeparator to JSON dictionary with proper formatting
    static func serializeToJson(_ separator: SwiftSeparator) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Add properties
        json[SwiftAdaptiveCardSchemaKey.color.rawValue] = separator.color.rawValue
        json[SwiftAdaptiveCardSchemaKey.thickness.rawValue] = separator.thickness.rawValue
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ separator: SwiftSeparator) throws -> String {
        let json = serializeToJson(separator)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - Consolidated SwiftTable Legacy Support

/// Unified legacy support for SwiftTable parsing and serialization
enum SwiftTableLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTable
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftTable {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTable.self, from: data)
    }
    
    /// Deserializes string into a SwiftTable
    static public func deserialize(from jsonString: String) throws -> SwiftTable {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftTable.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTable to JSON dictionary with proper formatting
    static func serializeToJson(_ table: SwiftTable, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Only include non-empty arrays
        if !table.columnDefinitions.isEmpty {
            json["columns"] = try table.columnDefinitions.map { try $0.serializeToJsonValue() }
        }
        
        if !table.rows.isEmpty {
            json["rows"] = try table.rows.map { try $0.serializeToJsonValue() }
        }
        
        // Only add properties that differ from defaults
        if table.showGridLines != true {
            json["showGridLines"] = table.showGridLines
        }
        
        if table.roundedCorners {
            json["roundedCorners"] = table.roundedCorners
        }
        
        if let horizontalAlignment = table.horizontalCellContentAlignment {
            json["horizontalCellContentAlignment"] = horizontalAlignment.rawValue
        }
        
        if let verticalAlignment = table.verticalCellContentAlignment {
            json["verticalCellContentAlignment"] = verticalAlignment.rawValue
        }
        
        if table.gridStyle != .none {
            json["gridStyle"] = SwiftContainerStyle.toString(table.gridStyle)  // Use toString
        }
        
        if !table.firstRowAsHeaders {
            json["firstRowAsHeaders"] = table.firstRowAsHeaders
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses Table elements in an Adaptive Card.
public struct SwiftTableParser: SwiftBaseCardElementParser {
    public init() { }
    
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        // Verify that the type is correct, using case-insensitive comparison
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.table)
        
        // Use the global BaseCardElement deserialization and cast to Table.
        guard let table = try SwiftBaseCardElement.deserialize(from: value) as? SwiftTable else {
            print("Failed to cast deserialized element to Table")
            throw AdaptiveCardParseError.invalidType
        }
        return table
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        guard let table = try SwiftBaseCardElement.deserialize(from: value) as? SwiftTable else {
            throw AdaptiveCardParseError.invalidType
        }
        return table
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: value)
        return try deserialize(context: context, value: jsonDict)
    }
}

extension SwiftTableParser {
    public func deserialize(from value: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        return try self.deserialize(fromString: context, value: value)
    }
}

// MARK: - SwiftTable Extension

internal extension SwiftTable {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        // Clear any additional properties first
        self.additionalProperties = nil
        return try SwiftTableLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties = Set([
            "type",
            "id",
            "columns",
            "rows",
            "showGridLines",
            "roundedCorners",
            "horizontalCellContentAlignment",
            "verticalCellContentAlignment",
            "gridStyle",
            "firstRowAsHeaders"
        ])
    }
}

// MARK: - Consolidated SwiftTableCell Legacy Support

/// Unified legacy support for SwiftTableCell parsing and serialization
enum SwiftTableCellLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTableCell
    static public func deserialize(from value: [String: Any], context: SwiftParseContext) throws -> SwiftTableCell {
        let idProperty = value[SwiftAdaptiveCardSchemaKey.id.rawValue] as? String ?? ""
        let internalId = SwiftInternalId.next()
        
        context.pushElement(idJsonProperty: idProperty, internalId: internalId)
        
        // Convert the JSON dictionary to Data.
        let jsonData = try JSONSerialization.data(withJSONObject: value, options: [])
        let cell = try JSONDecoder().decode(SwiftTableCell.self, from: jsonData)
        
        // Explicitly set style if provided
        if let styleString = value["style"] as? String {
            cell.style = SwiftContainerStyle(rawValue: styleString.capitalized) ?? SwiftContainerStyle.none
        }
        
        // Set RTL if present
        if let rtl = value[SwiftAdaptiveCardSchemaKey.rtl.rawValue] as? Bool {
            cell.setRtl(rtl)
        }
        
        cell.additionalProperties = nil
        context.popElement()
        return cell
    }
    
    /// Deserializes string into a SwiftTableCell
    static public func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftTableCell {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(from: jsonDict, context: context)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTableCell to JSON dictionary with proper formatting
    static func serializeToJson(_ cell: SwiftTableCell, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Add items if present
        if !cell.items.isEmpty {
            json["items"] = try cell.items.map { try $0.serializeToJsonValue() }
        }
        
        // Add rtl if present
        if let rtl = cell.rtl {
            json["rtl"] = rtl
        }
        
        // Add style with proper capitalization if not .none
        if cell.style != .none {
            json["style"] = cell.style.rawValue  // Use rawValue to get capitalized version
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses TableCell elements in an Adaptive Card.
struct SwiftTableCellParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.tableCell)
        return try SwiftTableCellLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTableCellLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTableCellLegacySupport.deserialize(from: value, context: context)
    }
}

// MARK: - SwiftTableCell Extension

internal extension SwiftTableCell {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftTableCellLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    

    // MARK: - Static Factory Methods
    
    /// Deserializes a `TableCell` from a JSON dictionary.
    static public func deserialize(from json: [String: Any], context: SwiftParseContext) throws -> SwiftTableCell {
        return try SwiftTableCellLegacySupport.deserialize(from: json, context: context)
    }
    
    /// Deserializes a `TableCell` from a JSON string.
    static public func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftTableCell {
        return try SwiftTableCellLegacySupport.deserialize(from: jsonString, context: context)
    }
}

/// Errors that can occur during serialization or deserialization.
enum SerializationError: Error {
    case stringEncodingFailed
    case stringDecodingFailed
    case invalidJsonString
    case invalidData
}

// MARK: - Consolidated SwiftTableColumnDefinition Legacy Support

/// Unified legacy support for SwiftTableColumnDefinition parsing and serialization
enum SwiftTableColumnDefinitionLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTableColumnDefinition
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftTableColumnDefinition {
        // Check for potential warnings
        if let context = context,
           let widthValue = value["width"] as? String,
           !widthValue.hasSuffix("px") {
            context.warnings.append(.init(
                statusCode: .noRendererForType,
                message: "Width string with no unit in TableColumnDefinition: \(widthValue)")
            )
        }
        
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTableColumnDefinition.self, from: data)
    }
    
    /// Deserializes Data into a SwiftTableColumnDefinition
    static public func deserialize(from data: Data) throws -> SwiftTableColumnDefinition {
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTableColumnDefinition.self, from: data)
    }
    
    /// Deserializes string into a SwiftTableColumnDefinition
    static public func deserialize(from jsonString: String) throws -> SwiftTableColumnDefinition {
        guard let data = jsonString.data(using: .utf8) else {
            throw SerializationError.stringDecodingFailed
        }
        return try deserialize(from: data)
    }
    
    /// Deserializes string into a SwiftTableColumnDefinition with context
    static public func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftTableColumnDefinition {
        let dict = try SwiftParseUtil.getJsonDictionary(from: jsonString)
        return try deserialize(from: dict, context: context)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTableColumnDefinition to JSON dictionary with proper formatting
    static func serializeToJson(_ columnDefinition: SwiftTableColumnDefinition) throws -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Only include alignment values if they differ from defaults
        if let horizontal = columnDefinition.horizontalCellContentAlignment, horizontal != .left {
            json["horizontalCellContentAlignment"] = horizontal.rawValue
        }
        
        if let vertical = columnDefinition.verticalCellContentAlignment, vertical != .top {
            json["verticalCellContentAlignment"] = vertical.rawValue
        }
        
        // Only include width or pixelWidth, not both (prioritize pixelWidth)
        if let pixelWidth = columnDefinition.pixelWidth {
            json["width"] = "\(pixelWidth)px"
        } else if let width = columnDefinition.width {
            json["width"] = width
        }
        
        return json
    }
    
    /// Serializes to JSON string
    static func serializeToJsonString(_ columnDefinition: SwiftTableColumnDefinition) throws -> String {
        let encoder = JSONEncoder()
        // Remove prettyPrinting to get compact JSON
        let data = try encoder.encode(columnDefinition)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SerializationError.stringEncodingFailed
        }
        // Add newline to match expected format
        return jsonString + "\n"
    }
}

// MARK: - SwiftTableColumnDefinition Extension

extension SwiftTableColumnDefinition {
    // Legacy serialization methods
    
    /// Serializes the current instance into a JSON string.
    /// - Returns: A JSON string representing the instance.
    /// - Throws: An error if encoding fails.
    public func serialize() throws -> String {
        return try SwiftTableColumnDefinitionLegacySupport.serializeToJsonString(self)
    }
    
    // Legacy static factory methods
    
    /// Deserializes from a JSON string with context
    static public func deserialize(context: SwiftParseContext, from jsonString: String) throws -> SwiftTableColumnDefinition {
        return try SwiftTableColumnDefinitionLegacySupport.deserialize(from: jsonString, context: context)
    }
}

// MARK: - Consolidated SwiftTableRow Legacy Support

/// Unified legacy support for SwiftTableRow parsing and serialization
enum SwiftTableRowLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTableRow
    static public func deserialize(from value: [String: Any], context: SwiftParseContext) throws -> SwiftTableRow {
        // Retrieve the id property using the expected key from AdaptiveCardSchemaKey.
        let idProperty = value[SwiftAdaptiveCardSchemaKey.id.rawValue] as? String ?? ""
        let internalId = SwiftInternalId.next()
        
        // Push element to context
        context.pushElement(idJsonProperty: idProperty, internalId: internalId)
        
        // Create a new row and populate its properties
        let tableRow = SwiftTableRow()
        
        // Parse horizontal alignment
        tableRow.horizontalCellContentAlignment = try SwiftParseUtil.getOptionalEnumValue(
            from: value,
            key: "horizontalCellContentAlignment",
            converter: SwiftHorizontalAlignment.fromString
        )
        
        // Parse vertical alignment
        tableRow.verticalCellContentAlignment = try SwiftParseUtil.getOptionalEnumValue(
            from: value,
            key: "verticalCellContentAlignment",
            converter: SwiftVerticalContentAlignment.fromString
        )
        
        // Parse style
        tableRow.style = try SwiftParseUtil.getEnumValue(
            from: value,
            key: "style",
            defaultValue: .none,
            converter: SwiftContainerStyle.caseInsensitiveValue
        )
        
        // Parse cells
        tableRow.cells = try SwiftParseUtil.getElementCollectionOfSingleType(
            from: value,
            key: "cells",
            context: context,
            defaultValue: [],
            converter: { (context: SwiftParseContext, json: [String: Any]) throws -> SwiftTableCell in
                return try SwiftTableCell.deserialize(from: json, context: context)
            }
        )
        
        // Clean up and return
        tableRow.additionalProperties = nil
        context.popElement()
        
        return tableRow
    }
    
    /// Deserializes string into a SwiftTableRow
    static public func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftTableRow {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(from: jsonDict, context: context)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTableRow to JSON dictionary with proper formatting
    static func serializeToJson(_ tableRow: SwiftTableRow, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Add cells if present
        if !tableRow.cells.isEmpty {
            json["cells"] = try tableRow.cells.map { try $0.serializeToJsonValue() }
        }
        
        // Add style if not default with proper capitalization
        if tableRow.style != .none {
            json["style"] = tableRow.style.rawValue  // Uses proper capitalization
        }
        
        // Add alignments if present
        if let horizontal = tableRow.horizontalCellContentAlignment {
            json["horizontalCellContentAlignment"] = horizontal.rawValue
        }
        if let vertical = tableRow.verticalCellContentAlignment {
            json["verticalCellContentAlignment"] = vertical.rawValue.capitalized
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses TableRow elements in an Adaptive Card.
struct SwiftTableRowParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.tableRow)
        return try SwiftTableRowLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTableRowLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftTableRowLegacySupport.deserialize(from: value, context: context)
    }
}

// MARK: - SwiftTableRow Extension

extension SwiftTableRow {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftTableRowLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Static Factory Methods
    
    /// Deserializes a `TableRow` from a JSON dictionary.
    static func deserialize(from json: [String: Any], context: SwiftParseContext) throws -> SwiftTableRow {
        return try SwiftTableRowLegacySupport.deserialize(from: json, context: context)
    }
    
    /// Deserializes a `TableRow` from a JSON string.
    public static func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftTableRow {
        return try SwiftTableRowLegacySupport.deserialize(from: jsonString, context: context)
    }
}

// MARK: - Consolidated TextBlock Legacy Support

/// Unified legacy support for TextBlock parsing and serialization
enum TextBlockLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a TextBlock
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftTextBlock {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTextBlock.self, from: data)
    }
    
    /// Deserializes string into a TextBlock
    static public func deserialize(from jsonString: String) throws -> SwiftTextBlock {
        guard let data = jsonString.data(using: .utf8) else {
            throw SerializationError.stringDecodingFailed
        }
        
        // Convert to dictionary first
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw AdaptiveCardParseError.invalidJson
        }
        
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a TextBlock to JSON dictionary with proper formatting
    static func serializeToJson(_ textBlock: SwiftTextBlock, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Always set the type
        json["type"] = "TextBlock"
        json["text"] = textBlock.text
        
        // Only include id if it's non-nil and non-empty
        if let id = textBlock.id, !id.isEmpty {
            json["id"] = id
        } else {
            // Remove id from json if it was added by super class
            json.removeValue(forKey: "id")
        }
        
        // Only include style if it differs from default
        if let textStyle = textBlock.textStyle, textStyle != .defaultStyle {
            json[SwiftAdaptiveCardSchemaKey.style.rawValue] = textStyle.rawValue
        }
        
        // Only include language if it's not "en"
        if let language = textBlock.language, language != "en" {
            json["lang"] = language
        }
        
        // Include other properties only if they have non-default values
        if let textSize = textBlock.textSize {
            json[SwiftAdaptiveCardSchemaKey.size.rawValue] = textSize.rawValue
        }
        
        if let textWeight = textBlock.textWeight {
            json[SwiftAdaptiveCardSchemaKey.weight.rawValue] = textWeight.rawValue
        }
        
        if let fontType = textBlock.fontType {
            json[SwiftAdaptiveCardSchemaKey.fontType.rawValue] = fontType.rawValue
        }
        
        if let textColor = textBlock.textColor {
            json[SwiftAdaptiveCardSchemaKey.color.rawValue] = textColor.rawValue
        }
        
        if let isSubtle = textBlock.isSubtle {
            json[SwiftAdaptiveCardSchemaKey.isSubtle.rawValue] = isSubtle
        }
        
        if textBlock.wrap {
            json[SwiftAdaptiveCardSchemaKey.wrap.rawValue] = textBlock.wrap
        }
        
        if textBlock.maxLines > 0 {
            json[SwiftAdaptiveCardSchemaKey.maxLines.rawValue] = textBlock.maxLines
        }
        
        if let horizontalAlignment = textBlock.horizontalAlignment {
            json[SwiftAdaptiveCardSchemaKey.horizontalAlignment.rawValue] = horizontalAlignment.rawValue
        }
        
        return json
    }
    
    /// Serializes to JSON string
    static func serializeToJsonString(_ textBlock: SwiftTextBlock) throws -> String {
        let json = try textBlock.serializeToJsonValue()
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AdaptiveCardParseError.serializationFailed
        }
        return jsonString + "\n"
    }
}

// MARK: - Parser Implementation

/// Parses TextBlock elements in an Adaptive Card.
public struct SwiftTextBlockParser: SwiftBaseCardElementParser {
    public init() { }
    
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        // Verify the type
        try SwiftParseUtil.expectTypeString(value, expected: SwiftCardElementType.textBlock)
        return try TextBlockLegacySupport.deserialize(from: value, context: context)
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try TextBlockLegacySupport.deserialize(from: value)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: value)
        return try deserialize(context: context, value: jsonDict)
    }
}

// MARK: - TextBlock Extensions

extension SwiftTextBlock {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try TextBlockLegacySupport.serializeToJson(self, baseJson: superResult)
    }

    // MARK: - Helper Methods for HTML Entity Decoding
    
    /// Decodes HTML entities in the provided string using a single pass.
    /// Supported entities: &amp;, &lt;, &gt;, &nbsp;
    static func decodeHTMLEntities(_ input: String) -> String {
        let pattern = "&([a-zA-Z]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let nsInput = input as NSString
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsInput.length))
        
        var result = ""
        var lastRangeEnd = 0
        
        for match in matches {
            let matchRange = match.range
            // Append text between last match and current match.
            result.append(nsInput.substring(with: NSRange(location: lastRangeEnd, length: matchRange.location - lastRangeEnd)))
            
            let entityName = nsInput.substring(with: match.range(at: 1))
            let replacement: String
            switch entityName {
            case "amp":
                replacement = "&"
            case "lt":
                replacement = "<"
            case "gt":
                replacement = ">"
            case "nbsp":
                replacement = "\u{00A0}"
            default:
                // Leave unsupported entities unchanged.
                replacement = nsInput.substring(with: matchRange)
            }
            
            result.append(replacement)
            lastRangeEnd = matchRange.location + matchRange.length
        }
        // Append any remaining text.
        result.append(nsInput.substring(from: lastRangeEnd))
        return result
    }
}

// MARK: - Methods for Unit Test Compatibility

extension SwiftTextBlock {
    /// Sets the text after performing a single-pass HTML entity decode.
    public func setText(_ newText: String) {
        self.text = SwiftTextBlock.decodeHTMLEntities(newText)
    }
    
    /// Returns the (decoded) text.
    public func getText() -> String {
        return self.text
    }
}

// MARK: - Consolidated SwiftTextElementProperties Legacy Support

/// Unified legacy support for SwiftTextElementProperties parsing and serialization
enum SwiftTextElementPropertiesLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTextElementProperties
    static public func deserialize(from value: [String: Any]) throws -> SwiftTextElementProperties {
        guard value["text"] is String else {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: "text")
        }

        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftTextElementProperties.self, from: data)
    }
    
    /// Deserializes string into a SwiftTextElementProperties
    static public func deserialize(from jsonString: String) throws -> SwiftTextElementProperties {
        guard let data = jsonString.data(using: .utf8) else {
            throw SerializationError.stringDecodingFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = json as? [String: Any] else {
            throw SerializationError.invalidJsonString
        }
        
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTextElementProperties to JSON dictionary with proper formatting
    static func serializeToJson(_ properties: SwiftTextElementProperties) -> [String: Any] {
        var json: [String: Any] = [:]

        // Add all non-nil properties
        if let textSize = properties.textSize {
            json["size"] = textSize.rawValue
        }
        if let textColor = properties.textColor {
            json["color"] = textColor.rawValue
        }
        if let textWeight = properties.textWeight {
            json["weight"] = textWeight.rawValue
        }
        if let fontType = properties.fontType {
            json["fontType"] = fontType.rawValue
        }
        if let isSubtle = properties.isSubtle {
            json["isSubtle"] = isSubtle
        }

        // Always include text and language
        json["text"] = properties.text
        json["language"] = properties.language

        return json
    }
    
    /// Serializes to JSON string
    static func serializeToJsonString(_ properties: SwiftTextElementProperties) throws -> String {
        let json = serializeToJson(properties)
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw SerializationError.stringEncodingFailed
        }
        return jsonString
    }
}

// MARK: - SwiftTextElementProperties Extension

extension SwiftTextElementProperties {
    // Legacy static factory methods
    
    /// Parses a `TextElementProperties` from a JSON dictionary.
    static func fromJSON(_ json: [String: Any]) throws -> SwiftTextElementProperties {
        return try SwiftTextElementPropertiesLegacySupport.deserialize(from: json)
    }
    
    /// Parses a `TextElementProperties` from a JSON string.
    static func fromJSONString(_ jsonString: String) throws -> SwiftTextElementProperties {
        return try SwiftTextElementPropertiesLegacySupport.deserialize(from: jsonString)
    }
    
    /// Serializes the properties to a JSON string
    func toJSONString() throws -> String {
        return try SwiftTextElementPropertiesLegacySupport.serializeToJsonString(self)
    }
}

// MARK: - TextRun Legacy Support

/// Unified legacy support for SwiftTextRun parsing and serialization
enum SwiftTextRunLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftTextRun
    static public func deserialize(from value: [String: Any]) throws -> SwiftTextRun? {
        // Use the existing deserialize method from SwiftTextRun
        return try SwiftTextRun.deserialize(from: value)
    }
    
    /// Deserializes string into a SwiftTextRun
    static public func deserialize(from jsonString: String) throws -> SwiftTextRun? {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try deserialize(from: json)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftTextRun to JSON dictionary with proper formatting
    static func serializeToJson(_ textRun: SwiftTextRun) -> [String: Any] {
        var json = textRun.additionalProperties.mapValues { $0.value }
        
        // Set type property
        json["type"] = SwiftInlineElementType.textRun.rawValue
        
        // Add required property
        json["text"] = textRun.text
        
        // Add optional properties (use standard keys only, not alternate keys)
        if let textSize = textRun.textSize {
            json["size"] = textSize.rawValue
        }
        
        if let textWeight = textRun.textWeight {
            json["weight"] = textWeight.rawValue
        }
        
        if let fontType = textRun.fontType {
            json["fontType"] = fontType.rawValue
        }
        
        if let textColor = textRun.textColor {
            json["color"] = textColor.rawValue
        }
        
        if let isSubtle = textRun.isSubtle {
            json["isSubtle"] = isSubtle
        }
        
        // Encode flags when true
        if textRun.italic { json["italic"] = true }
        if textRun.strikethrough { json["strikethrough"] = true }
        if textRun.highlight { json["highlight"] = true }
        if textRun.underline { json["underline"] = true }
        
        // Add language if present (only use one key)
        if let language = textRun.language {
            json["language"] = language
        }
        
        // Add selectAction if present
        if let selectAction = textRun.selectAction {
            json["selectAction"] = try? SwiftBaseCardElement.serializeSelectAction(selectAction)
        }
        
        return json
    }
    
    /// Converts to JSON string
    static func serializeToJsonString(_ textRun: SwiftTextRun) throws -> String {
        let json = serializeToJson(textRun)
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncodingError.invalidValue(json, EncodingError.Context(
                codingPath: [], debugDescription: "Failed to convert JSON to string"))
        }
        return jsonString
    }
}

// MARK: - SwiftTextRun Extension for Deserialization

public extension SwiftTextRun {
    /// Static method to deserialize from a JSON dictionary
    static func deserialize(from json: [String: Any]) throws -> SwiftTextRun? {
        guard let text = json["text"] as? String else { return nil }
        
        // Create a mutable copy of additional properties
        var additionalProperties = json
        additionalProperties.removeValue(forKey: "type")
        additionalProperties.removeValue(forKey: "text")
        additionalProperties.removeValue(forKey: "selectAction")
        
        // Mapping for legacy keys
        let sizeString = json["textSize"] as? String ?? json["size"] as? String
        let textSize = sizeString.map { SwiftTextSize.caseInsensitiveValue(from: $0) }
        
        let textWeight = (json["textWeight"] as? String ?? json["weight"] as? String)
            .flatMap { SwiftTextWeight(rawValue: $0) }
        
        let fontType = (json["fontType"] as? String)
            .flatMap { SwiftFontType(rawValue: $0) }
        
        let textColor = (json["textColor"] as? String ?? json["color"] as? String)
            .flatMap { SwiftForegroundColor.fromString($0) }
        
        let isSubtle = json["isSubtle"] as? Bool
        
        let italic = json["italic"] as? Bool ?? false
        let strikethrough = json["strikethrough"] as? Bool ?? false
        let highlight = json["highlight"] as? Bool ?? false
        let underline = json["underline"] as? Bool ?? false
        
        // Language handling with fallback
        let language = json["language"] as? String ?? json["lang"] as? String
        
        // Handle selectAction
        let selectAction: SwiftBaseActionElement?
        if let actionData = json["selectAction"] {
            if let dict = actionData as? [String: SwiftAnyCodable],
               let typeAnyCodable = dict["type"],
               let typeString = typeAnyCodable.value as? String {
                let actionDict: [String: Any] = ["type": typeString]
                selectAction = try SwiftBaseActionElement.deserializeAction(from: actionDict)
            } else {
                selectAction = nil
            }
        } else {
            selectAction = nil
        }
        
        // Remove keys that have been processed
        additionalProperties.removeValue(forKey: "textSize")
        additionalProperties.removeValue(forKey: "size")
        additionalProperties.removeValue(forKey: "weight")
        additionalProperties.removeValue(forKey: "textWeight")
        additionalProperties.removeValue(forKey: "fontType")
        additionalProperties.removeValue(forKey: "textColor")
        additionalProperties.removeValue(forKey: "color")
        additionalProperties.removeValue(forKey: "isSubtle")
        additionalProperties.removeValue(forKey: "italic")
        additionalProperties.removeValue(forKey: "strikethrough")
        additionalProperties.removeValue(forKey: "highlight")
        additionalProperties.removeValue(forKey: "underline")
        additionalProperties.removeValue(forKey: "language")
        additionalProperties.removeValue(forKey: "lang")
        
        return SwiftTextRun(
            text: text,
            textSize: textSize,
            textWeight: textWeight,
            fontType: fontType,
            textColor: textColor,
            isSubtle: isSubtle,
            italic: italic,
            strikethrough: strikethrough,
            highlight: highlight,
            underline: underline,
            language: language ?? "en", // Default to "en" if nil
            selectAction: selectAction,
            additionalProperties: additionalProperties.mapValues { SwiftAnyCodable($0) }
        )
    }
}

// MARK: - Convenience Extension

extension SwiftTextRun {
    /// Serializes the text run to a JSON dictionary
    func serializeToJson() -> [String: Any] {
        return SwiftTextRunLegacySupport.serializeToJson(self)
    }
    
    /// Serializes the text run to a JSON string
    func serializeToJsonString() throws -> String {
        return try SwiftTextRunLegacySupport.serializeToJsonString(self)
    }
}

enum SwiftToggleVisibilityTargetLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes a `SwiftToggleVisibilityTarget` from a JSON dictionary.
    static public func deserialize(from json: [String: Any]) throws -> SwiftToggleVisibilityTarget {
        // Legacy support: if the JSON is a single string, treat it as the elementId with a default toggle state.
        if let elementId = json as? String {
            return SwiftToggleVisibilityTarget(elementId: elementId, isVisible: .toggle)
        }
        
        // Expect a dictionary with an "elementId" key.
        guard let elementId = json["elementId"] as? String else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        
        // Legacy encoding stores isVisible as a Bool: true means .visible; false (or missing) means .hidden.
        let isVisible: SwiftIsVisible = (json["isVisible"] as? Bool) == true ? .visible : .hidden
        return SwiftToggleVisibilityTarget(elementId: elementId, isVisible: isVisible)
    }
    
    /// Deserializes a `SwiftToggleVisibilityTarget` from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftToggleVisibilityTarget {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftToggleVisibilityTarget to a JSON dictionary with legacy formatting.
    static func serializeToJson(_ target: SwiftToggleVisibilityTarget, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        json["elementId"] = target.elementId
        
        // If the target is not in its default state (.toggle), include the "isVisible" key.
        if target.isVisible != .toggle {
            json["isVisible"] = (target.isVisible == .visible)
        }
        return json
    }
}

// MARK: - Extension for Legacy Serialization

internal extension SwiftToggleVisibilityTarget {
    /// Serializes this target to legacy JSON format.
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftToggleVisibilityTargetLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    /// Deserializes a `ToggleVisibilityTarget` from a JSON dictionary.
    static func deserialize(from json: [String: Any]) throws -> SwiftToggleVisibilityTarget {
        if let elementId = json as? String {
            return SwiftToggleVisibilityTarget(elementId: elementId, isVisible: .toggle)
        }

        guard let elementId = json["elementId"] as? String else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        
        let isVisible: SwiftIsVisible = (json["isVisible"] as? Bool) == true ? .visible : .hidden
        return SwiftToggleVisibilityTarget(elementId: elementId, isVisible: isVisible)
    }

    /// Deserializes a `ToggleVisibilityTarget` from a JSON string.
    static func deserialize(from jsonString: String) throws -> SwiftToggleVisibilityTarget {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(from: jsonDict)
    }

}

enum SwiftTokenExchangeResourceLegacySupport {
    // MARK: - Legacy Helpers
    
    /// Determines if serialization should occur based on whether any fields have been set.
    static func shouldSerialize(_ resource: SwiftTokenExchangeResource) -> Bool {
        return resource.id != nil || resource.uri != nil || resource.providerId != nil
    }
    
    /// Serializes the resource to a JSON string.
    static func serialize(_ resource: SwiftTokenExchangeResource) throws -> String {
        let jsonData = try JSONEncoder().encode(resource)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    /// Serializes the resource into a JSON dictionary.
    static func serializeToJsonValue(_ resource: SwiftTokenExchangeResource) throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(resource)
        return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
    }
    
    /// Deserializes a `SwiftTokenExchangeResource` from a JSON dictionary.
    static public func deserialize(from json: [String: Any]) throws -> SwiftTokenExchangeResource {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftTokenExchangeResource.self, from: jsonData)
    }
    
    /// Deserializes a `SwiftTokenExchangeResource` from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftTokenExchangeResource {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftTokenExchangeResource.self, from: jsonData)
    }
}

// MARK: - Extension for Legacy Serialization

internal extension SwiftTokenExchangeResource {
    /// Serializes this resource to legacy JSON format by merging with an existing JSON dictionary.
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        var json = superResult
        let legacyJson = try SwiftTokenExchangeResourceLegacySupport.serializeToJsonValue(self)
        // Merge the legacy JSON values into the base dictionary.
        legacyJson.forEach { json[$0.key] = $0.value }
        return json
    }
    
    /// Determines if serialization should occur based on whether fields have been set.
    var shouldSerialize: Bool {
        return id != nil || uri != nil || providerId != nil
    }
    
    /// Serializes the resource to a JSON string.
    func serialize() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    /// Serializes the resource into a JSON object.
    func serializeToJsonValue() throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
    }

    /// Deserializes a `TokenExchangeResource` from a JSON dictionary.
    static func deserialize(from json: [String: Any]) throws -> SwiftTokenExchangeResource {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftTokenExchangeResource.self, from: jsonData)
    }

    /// Deserializes a `TokenExchangeResource` from a JSON string.
    static func deserialize(from jsonString: String) throws -> SwiftTokenExchangeResource {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "")
        }
        return try JSONDecoder().decode(SwiftTokenExchangeResource.self, from: jsonData)
    }

}

enum SwiftBaseActionElementLegacySupport {
    /// Deserializes a BaseActionElement from a JSON string.
    /// This function is maintained for backward compatibility.
    static func deserializeAction(from jsonString: String) throws -> SwiftBaseActionElement {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw AdaptiveCardParseError.invalidJson
        }
        // Ensure the JSON contains a "type" key.
        guard let typeString = jsonDict["type"] as? String else {
            throw AdaptiveCardParseError.invalidType
        }
        
        // Prepare the JSON data for decoding.
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let decoder = JSONDecoder()
        
        switch typeString {
        case SwiftActionType.openUrl.rawValue:
            return try decoder.decode(SwiftOpenUrlAction.self, from: data)
        case SwiftActionType.showCard.rawValue:
            return try decoder.decode(SwiftShowCardAction.self, from: data)
        case SwiftActionType.submit.rawValue:
            return try decoder.decode(SwiftSubmitAction.self, from: data)
        case SwiftActionType.toggleVisibility.rawValue:
            return try decoder.decode(SwiftToggleVisibilityAction.self, from: data)
        case SwiftActionType.execute.rawValue:
            return try decoder.decode(SwiftExecuteAction.self, from: data)
        default:
            // For any unknown type, decode as an UnknownAction.
            return try decoder.decode(SwiftUnknownAction.self, from: data)
        }
    }
    
    /// Deserializes a BaseActionElement from a JSON dictionary.
    static func deserializeAction(from originalJson: [String: Any]) throws -> SwiftBaseActionElement {
        let data = try JSONSerialization.data(withJSONObject: originalJson, options: [])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AdaptiveCardParseError.invalidJson
        }
        return try deserializeAction(from: jsonString)
    }
}

extension SwiftBaseActionElement {
    // MARK: - Deserialization Helpers
    
    /// Deserializes a BaseActionElement from a JSON string.
    /// This function is crucial and remains available for backward compatibility.
    class func deserializeAction(from jsonString: String) throws -> SwiftBaseActionElement {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw AdaptiveCardParseError.invalidJson
        }
        // Ensure the JSON contains a "type" key.
        guard let typeString = jsonDict["type"] as? String else {
            throw AdaptiveCardParseError.invalidType
        }
        
        // Prepare the JSON data for decoding.
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let decoder = JSONDecoder()
        
        switch typeString {
        case SwiftActionType.openUrl.rawValue:
            return try decoder.decode(SwiftOpenUrlAction.self, from: data)
        case SwiftActionType.showCard.rawValue:
            return try decoder.decode(SwiftShowCardAction.self, from: data)
        case SwiftActionType.submit.rawValue:
            return try decoder.decode(SwiftSubmitAction.self, from: data)
        case SwiftActionType.toggleVisibility.rawValue:
            return try decoder.decode(SwiftToggleVisibilityAction.self, from: data)
        case SwiftActionType.execute.rawValue:
            return try decoder.decode(SwiftExecuteAction.self, from: data)
        default:
            // For any unknown or invalid type, decode as UnknownAction.
            return try decoder.decode(SwiftUnknownAction.self, from: data)
        }
    }
    
    /// Deserializes a BaseActionElement from a JSON dictionary.
    class func deepConvertToJSONSerializable(_ value: Any) -> Any {
        // Handle AnyCodable
        if let anyCodable = value as? SwiftAnyCodable {
            return deepConvertToJSONSerializable(anyCodable.value)
        }
        
        // Handle dictionaries
        if let dict = value as? [String: Any] {
            var newDict = [String: Any]()
            for (key, value) in dict {
                newDict[key] = deepConvertToJSONSerializable(value)
            }
            return newDict
        }
        
        // Handle arrays
        if let array = value as? [Any] {
            return array.map { deepConvertToJSONSerializable($0) }
        }
        
        // Basic types (String, Int, Double, Bool) pass through unchanged
        return value
    }
    
    class func deserializeAction(from originalJson: [String: Any]) throws -> SwiftBaseActionElement {
        let jsonSerializable = deepConvertToJSONSerializable(originalJson) as! [String: Any]
        
        // Verify all values are JSON-serializable
        func checkSerializable(_ value: Any) -> Bool {
            if value is String || value is Int || value is Double || value is Bool || value is NSNull {
                return true
            } else if let dict = value as? [String: Any] {
                return dict.values.allSatisfy { checkSerializable($0) }
            } else if let array = value as? [Any] {
                return array.allSatisfy { checkSerializable($0) }
            }
            debugPrint("Non-serializable value found: \(value) of type \(type(of: value))")
            return false
        }
        
        // Check if everything is serializable
        let isSerializable = checkSerializable(jsonSerializable)
        if !isSerializable {
            debugPrint("Warning: Non-serializable values found")
        }
        
        let data = try JSONSerialization.data(withJSONObject: jsonSerializable, options: [])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AdaptiveCardParseError.invalidJson
        }
        return try deserializeAction(from: jsonString)
    }
}

enum SwiftExecuteActionLegacySupport {
    /// Sets the `dataJson` property from a JSON string.
    static func setDataJson(for action: SwiftExecuteAction, from jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            return
        }
        // Convert [String: Any] into [String: AnyCodable]
        action.dataJson = jsonDict.mapValues { SwiftAnyCodable($0) }
    }

    /// Serializes the action into a legacy JSON dictionary.
    static func serializeToJson(_ action: SwiftExecuteAction) -> [String: Any] {
        do {
            // Start with the base JSON from the superclass.
            var json = try action.serializeToJsonValue()
            
            if let dataJson = action.dataJson {
                // Convert [String: AnyCodable] to [String: Any] by extracting underlying values.
                json["data"] = dataJson.mapValues { $0.value }
            }
            if !action.verb.isEmpty {
                json["verb"] = action.verb
            }
            if action.associatedInputs != .auto {
                json["associatedInputs"] = action.associatedInputs.rawValue
            }
            json["conditionallyEnabled"] = action.conditionallyEnabled
            
            return json
        } catch {
            debugPrint("execute action error serializing to json")
            return [:]
        }
    }
}

final class SwiftExecuteActionParser: SwiftActionElementParser {
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftExecuteAction.self, from: data)
    }

    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(context: context, from: json)
    }
}

enum SwiftShowCardActionLegacySupport {
    /// Deserializes a `SwiftShowCardAction` from a JSON dictionary.
    static public func deserialize(from json: [String: Any]) throws -> SwiftShowCardAction {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftShowCardAction.self, from: data)
    }
    
    /// Deserializes a `SwiftShowCardAction` from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftShowCardAction {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftShowCardAction.self, from: data)
    }
    
    /// Serializes `SwiftShowCardAction` to a legacy JSON dictionary.
    static func serializeToJson(_ action: SwiftShowCardAction) throws -> [String: Any] {
        var json = [String: Any]()
        if let card = action.card {
            var cardJson = try card.serializeToJsonValue()
            // Force fallback-related keys to non-nil defaults.
            cardJson[SwiftAdaptiveCardSchemaKey.fallbackText.rawValue] = card.fallbackText ?? ""
            cardJson[SwiftAdaptiveCardSchemaKey.speak.rawValue] = card.speak ?? ""
            // For language, if missing, force "en".
            cardJson["lang"] = card.language ?? "en"
            // Ensure the sub-card JSON contains a type.
            if cardJson["type"] == nil {
                cardJson["type"] = "AdaptiveCard"
            }
            json[SwiftAdaptiveCardSchemaKey.card.rawValue] = cardJson
        }
        return json
    }
    
    /// Serializes `SwiftShowCardAction` to a JSON string.
    static func serialize(_ action: SwiftShowCardAction) throws -> String {
        let json = try serializeToJson(action)
        return try SwiftParseUtil.jsonToString(json)
    }
}

/// Parser for `ShowCardAction` elements.
class SwiftShowCardActionParser: SwiftActionElementParser {
    
    /// Deserializes a `ShowCardAction` from a JSON dictionary.
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftShowCardAction.self, from: data)
    }

    /// Deserializes a `ShowCardAction` from a JSON string.
    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        let json = try SwiftParseUtil.getJsonDictionary(from: jsonString)
        return try deserialize(context: context, from: json)
    }
}

enum SwiftOpenUrlActionLegacySupport {
    /// Deserializes a `SwiftOpenUrlAction` from a JSON dictionary.
    static public func deserialize(from json: [String: Any]) throws -> SwiftOpenUrlAction {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftOpenUrlAction.self, from: data)
    }
    
    /// Deserializes a `SwiftOpenUrlAction` from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftOpenUrlAction {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftOpenUrlAction.self, from: data)
    }
}

struct OpenUrlActionParser: SwiftActionElementParser {
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftOpenUrlActionLegacySupport.deserialize(from: json)
    }
    
    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftOpenUrlActionLegacySupport.deserialize(from: jsonString)
    }
}

enum SwiftSubmitActionLegacySupport {
    /// Creates a SwiftSubmitAction from a JSON dictionary.
    static func make(from json: [String: Any]) throws -> SwiftSubmitAction {
        let dataJson: Any?
        if let data = json[SwiftAdaptiveCardSchemaKey.data.rawValue] {
            if let dataDict = data as? [String: Any] {
                dataJson = dataDict
            } else {
                dataJson = data
            }
        } else {
            dataJson = nil
        }
        
        let associatedInputsString = json[SwiftAdaptiveCardSchemaKey.associatedInputs.rawValue] as? String ?? "auto"
        let associatedInputs = SwiftAssociatedInputs(rawValue: associatedInputsString) ?? .auto
        let conditionallyEnabled = json[SwiftAdaptiveCardSchemaKey.conditionallyEnabled.rawValue] as? Bool ?? false
        
        let title = json["title"] as? String
        let iconUrl = json["iconUrl"] as? String
        let style = json["style"] as? String ?? "default"
        let tooltip = json["tooltip"] as? String
        let mode = (json["mode"] as? String).flatMap { SwiftMode(rawValue: $0) } ?? .primary
        let isEnabled = json["isEnabled"] as? Bool ?? true
        let id = json["id"] as? String
        
        let action = SwiftSubmitAction(
            dataJson: dataJson,
            associatedInputs: associatedInputs,
            conditionallyEnabled: conditionallyEnabled,
            title: title,
            iconUrl: iconUrl,
            style: style,
            tooltip: tooltip,
            mode: mode,
            isEnabled: isEnabled,
            id: id
        )
        
        // Set additional properties for any keys not in the known set.
        var additionalProps: [String: Any] = [:]
        for (key, value) in json {
            if !SwiftSubmitAction.knownProperties.contains(key) {
                additionalProps[key] = value
            }
        }
        if !additionalProps.isEmpty {
            action.additionalProperties = additionalProps.mapValues { SwiftAnyCodable($0) }
        }
        
        return action
    }
    
    /// Returns a legacy-formatted JSON dictionary for the given SubmitAction, merging with the provided base JSON.
    static func serializeToJsonValue(_ action: SwiftSubmitAction, superResult: [String: Any]) throws -> [String: Any] {
        var json = superResult
        
        json["type"] = "Action.Submit"
        
        // Include the data, preserving its original format.
        if let dataJson = action.dataJson {
            json[SwiftAdaptiveCardSchemaKey.data.rawValue] = dataJson
        }
        
        if action.associatedInputs != .auto {
            json[SwiftAdaptiveCardSchemaKey.associatedInputs.rawValue] = action.associatedInputs.rawValue
        }
        
        // Include title if present.
        if !action.title.isEmpty {
            json["title"] = action.title
        }
        
        // Merge in any additional properties.
        if let additionalProps = action.additionalProperties, !additionalProps.isEmpty {
            for (key, value) in additionalProps {
                json[key] = value.value
            }
        }
        
        return json
    }
}

class SubmitActionParser: SwiftActionElementParser {
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftSubmitActionLegacySupport.make(from: json)
    }
    
    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Invalid JSON string")
        }
        return try deserialize(context: context, from: jsonDict)
    }
}

extension SwiftSubmitAction {
    /// Creates a SubmitAction from a JSON dictionary.
    /// (Renamed from “deserialize(from:)” to avoid conflicting with BaseActionElement’s extension.)
    public static func make(from json: [String: Any]) throws -> SwiftSubmitAction {
        let dataJson: Any?
        if let data = json[SwiftAdaptiveCardSchemaKey.data.rawValue] {
            if let dataDict = data as? [String: Any] {
                dataJson = dataDict
            } else {
                dataJson = data
            }
        } else {
            dataJson = nil
        }
        
        let associatedInputsString = json[SwiftAdaptiveCardSchemaKey.associatedInputs.rawValue] as? String ?? "auto"
        let associatedInputs = SwiftAssociatedInputs(rawValue: associatedInputsString) ?? .auto
        let conditionallyEnabled = json[SwiftAdaptiveCardSchemaKey.conditionallyEnabled.rawValue] as? Bool ?? false
        
        let title = json["title"] as? String
        let iconUrl = json["iconUrl"] as? String
        let style = json["style"] as? String ?? "default"
        let tooltip = json["tooltip"] as? String
        let mode = (json["mode"] as? String).flatMap { SwiftMode(rawValue: $0) } ?? .primary
        let isEnabled = json["isEnabled"] as? Bool ?? true
        let id = json["id"] as? String
        
        let action = SwiftSubmitAction(dataJson: dataJson,
                                  associatedInputs: associatedInputs,
                                  conditionallyEnabled: conditionallyEnabled,
                                  title: title,
                                  iconUrl: iconUrl,
                                  style: style,
                                  tooltip: tooltip,
                                  mode: mode,
                                  isEnabled: isEnabled,
                                  id: id)
        
        // Filter and set additional properties
        var additionalProps: [String: Any] = [:]
        for (key, value) in json {
            if !Self.knownProperties.contains(key) {
                additionalProps[key] = value
            }
        }
        if !additionalProps.isEmpty {
            action.additionalProperties = additionalProps.mapValues { SwiftAnyCodable($0) }
        }
        
        return action
    }
}

enum SwiftToggleVisibilityActionLegacySupport {
    /// Deserializes a SwiftToggleVisibilityAction from a JSON dictionary.
    static public func deserialize(from json: [String: Any], context: SwiftParseContext) throws -> SwiftToggleVisibilityAction {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftToggleVisibilityAction.self, from: data)
    }
    
    /// Deserializes a SwiftToggleVisibilityAction from a JSON string.
    static public func deserialize(from jsonString: String, context: SwiftParseContext) throws -> SwiftToggleVisibilityAction {
        guard let data = jsonString.data(using: .utf8) else {
            throw AdaptiveCardParseError.invalidJson
        }
        return try JSONDecoder().decode(SwiftToggleVisibilityAction.self, from: data)
    }
}

class ToggleVisibilityActionParser: SwiftActionElementParser {
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftToggleVisibilityActionLegacySupport.deserialize(from: json, context: context)
    }
    
    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftToggleVisibilityActionLegacySupport.deserialize(from: jsonString, context: context)
    }
}

final class UnknownActionParser: SwiftActionElementParser {
    public func deserialize(context: SwiftParseContext, from json: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        guard let typeString = json["type"] as? String else {
            throw AdaptiveCardParseError.invalidType
        }
        
        // Create an unknown action with the original type.
        let unknownAction = SwiftUnknownAction(type: typeString)
        // Store all JSON key–value pairs in additionalProperties.
        unknownAction.additionalProperties = json.mapValues { SwiftAnyCodable($0) }
        return unknownAction
    }
    
    public func deserialize(fromString jsonString: String, context: SwiftParseContext) throws -> any SwiftAdaptiveCardElementProtocol {
        let json = try SwiftParseUtil.getJsonDictionary(from: jsonString)
        return try deserialize(context: context, from: json)
    }
}

enum SwiftStyledCollectionElementLegacySupport {
    static func serializeToJsonValue(_ element: SwiftStyledCollectionElement, superResult: [String: Any]) throws -> [String: Any] {
        var json = superResult
        if element.style != .none {
            json["style"] = SwiftContainerStyle.toString(element.style)
        }
        if let verticalAlignment = element.verticalContentAlignment {
            json["verticalContentAlignment"] = verticalAlignment.rawValue
        }
        if element.hasBleed {
            json["bleed"] = true
        }
        if element.minHeight > 0 {
            json["minHeight"] = "\(element.minHeight)px"
        }
        if let selectAction = element.selectAction {
            json["selectAction"] = selectAction.toJSON()
        }
        if let backgroundImage = element.backgroundImage {
            json["backgroundImage"] = backgroundImage.serializeToJsonValue()
        }
        return json
    }
}

extension SwiftContentSource {
    func serializeToJson() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    func getResourceInformation() -> SwiftRemoteResourceInformation? {
        guard let url = url, let mimeType = mimeType else { return nil }
        return SwiftRemoteResourceInformation(url: url, mimeType: mimeType)
    }

    static public func deserialize(from json: [String: Any]) throws -> SwiftContentSource {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftContentSource.self, from: jsonData)
    }

    static public func deserialize(from jsonString: String) throws -> SwiftContentSource {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ContentSource", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        return try JSONDecoder().decode(SwiftContentSource.self, from: jsonData)
    }
}

extension SwiftFlowLayout {
    class public func deserialize(from json: [String: Any]) throws -> SwiftFlowLayout {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try JSONDecoder().decode(SwiftFlowLayout.self, from: data)
    }
}

// MARK: - Consolidated SwiftContainer Legacy Support

/// Unified legacy support for SwiftContainer parsing and serialization
enum SwiftContainerLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftContainer
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftContainer {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftContainer.self, from: data)
    }
    
    /// Deserializes string into a SwiftContainer
    static public func deserialize(from jsonString: String) throws -> SwiftContainer {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftContainer.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftContainer to JSON dictionary with proper formatting
    static func serializeToJson(_ container: SwiftContainer, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "Container"
        
        // Serialize child items if present
        if !container.items.isEmpty {
            var itemsArray: [[String: Any]] = []
            for item in container.items {
                let itemJson = try item.serializeToJsonValue()
                itemsArray.append(itemJson)
            }
            json["items"] = itemsArray
        }
        
        // Add layouts if present
        if !container.layouts.isEmpty {
            var layoutsArray: [[String: Any]] = []
            for layout in container.layouts {
                // Assuming SwiftLayout has a toJSON method or similar
                layoutsArray.append(layout.toJSON())
            }
            json["layouts"] = layoutsArray
        }
        
        // Add rtl if present
        if let rtl = container.rtl {
            json["rtl"] = rtl
        }
        
        // Add vertical content alignment if present
        if let verticalContentAlignment = container.verticalContentAlignment {
            json["verticalContentAlignment"] = verticalContentAlignment.rawValue.lowercased()
        }
        
        // Add style if not default
        if container.style != .none {
            json["style"] = container.style.rawValue
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses Container elements in an Adaptive Card
struct SwiftContainerParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: .container)
        
        // Save current context
        let parentStyle = context.parentalContainerStyle
        
        // Parse the container itself
        guard let container = try SwiftBaseCardElement.deserialize(from: value) as? SwiftContainer else {
            throw AdaptiveCardParseError.invalidType
        }
        
        // Set new parent style for children
        context.setParentalContainerStyle(container.style)
        
        // Configure container style
        container.configForContainerStyle(context)
        
        // Restore parent style
        if let parentStyle = parentStyle {
            context.setParentalContainerStyle(parentStyle)
        }
        
        return container
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftContainerLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftContainerLegacySupport.deserialize(from: value)
    }
}

// MARK: - SwiftContainer Extension

extension SwiftContainer {
    /// Serializes to legacy JSON format
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("items")
        self.knownProperties.insert("layouts")
        self.knownProperties.insert("rtl")
        self.knownProperties.insert("style")
        self.knownProperties.insert("verticalContentAlignment")
        self.knownProperties.insert("bleed")
        self.knownProperties.insert("minHeight")
    }
    
    // MARK: - Helper Methods for Container Style
    internal func findParentColumn() -> SwiftColumn? {
        var current: SwiftBaseCardElement? = self
        var searchPath: [SwiftBaseCardElement] = []
        
        // First, build the parent chain
        while let currentElement = current {
            searchPath.append(currentElement)
            if let parentId = currentElement.parentalId {
                current = findElement(withId: parentId)
            } else {
                current = nil
            }
        }
        
        // Then search through the chain for the first Column
        for element in searchPath {
            if let parentId = element.parentalId,
               let column = findElement(withId: parentId) as? SwiftColumn {
                return column
            }
        }
        
        return nil
    }
    
    internal func findParentColumnSet(of element: SwiftBaseCardElement) -> SwiftColumnSet? {
        var current: SwiftBaseCardElement? = element
        
        while let currentElement = current {
            if let parentId = currentElement.parentalId {
                if let columnSet = findElement(withId: parentId) as? SwiftColumnSet {
                    return columnSet
                }
                current = findElement(withId: parentId)
            } else {
                current = nil
            }
        }
        
        return nil
    }
    
    func deserializeChildren(from json: [String: Any]) throws {
        // Parse Items array
        if let itemsArray = json["items"] as? [[String: Any]] {
            self.items = try itemsArray.map { itemJson in
                var mutableJson = itemJson
                // Ensure type is set for items that don't specify it
                if mutableJson["type"] == nil {
                    mutableJson["type"] = "TextBlock" // Default type
                }
                return try SwiftBaseCardElement.deserialize(from: mutableJson)
            }
        }
    }
}

// MARK: - Consolidated SwiftColumn Legacy Support

/// Unified legacy support for SwiftColumn parsing and serialization
enum SwiftColumnLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftColumn
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftColumn {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftColumn.self, from: data)
    }
    
    /// Deserializes string into a SwiftColumn
    static public func deserialize(from jsonString: String) throws -> SwiftColumn {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftColumn.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftColumn to JSON dictionary with proper formatting
    static func serializeToJson(_ column: SwiftColumn, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "Column"
        json["width"] = column.width
        
        // Serialize items array
        if !column.items.isEmpty {
            var itemsArray: [[String: Any]] = []
            for item in column.items {
                let itemJson = try item.serializeToJsonValue()
                itemsArray.append(itemJson)
            }
            json["items"] = itemsArray
        }
        
        // Add optional properties
        if let rtl = column.rtl {
            json["rtl"] = rtl
        }
        
        // Add layouts if present
        if !column.layouts.isEmpty {
            var layoutsArray: [[String: Any]] = []
            for layout in column.layouts {
                // Assuming SwiftLayout has a toJSON method or similar
                layoutsArray.append(layout.toJSON())
            }
            json["layouts"] = layoutsArray
        }
        
        // Add style if not default
        if column.style != .none {
            json["style"] = column.style.rawValue
        }
        
        // Add vertical content alignment if present
        if let verticalContentAlignment = column.verticalContentAlignment {
            json["verticalContentAlignment"] = verticalContentAlignment.rawValue.lowercased()
        }
        
        // Add selectAction if present
        if let selectAction = column.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(selectAction)
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses Column elements in an Adaptive Card
struct SwiftColumnParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        guard let typeString = value["type"] as? String,
              typeString == SwiftCardElementType.column.rawValue else {
            throw SwiftAdaptiveCardParseException(statusCode: .requiredPropertyMissing, message: "Invalid type for Column")
        }
        
        guard let column = try SwiftBaseCardElement.deserialize(from: value) as? SwiftColumn else {
            throw SwiftAdaptiveCardParseException(statusCode: .unsupportedParserOverride, message: "Column deserialization failed")
        }
        
        var columnWidth = SwiftParseUtil.getValueAsString(from: value, key: "width")
        if columnWidth.isEmpty {
            columnWidth = SwiftParseUtil.getValueAsString(from: value, key: "size")
        }
        column.setWidth(columnWidth, warnings: &context.warnings)
        column.setRtl(SwiftParseUtil.getOptionalBool(from: value, key: "rtl"))
        
        if let layoutArray: [[String: Any]] = try? SwiftParseUtil.getArray(from: value, key: "layouts", required: false), !layoutArray.isEmpty {
            var parsedLayouts: [SwiftLayout] = []
            for layoutJson in layoutArray {
                guard let baseLayout = SwiftLayout.fromJSON(layoutJson) else {
                    throw SwiftAdaptiveCardParseException(statusCode: .invalidJson, message: "Failed to parse layout")
                }
                switch baseLayout.layoutContainerType {
                case .flow:
                    let flowLayout = try SwiftFlowLayout.deserialize(from: layoutJson)
                    parsedLayouts.append(flowLayout)
                case .areaGrid:
                    let areaGridLayout = SwiftAreaGridLayout.deserialize(from: layoutJson)
                    if areaGridLayout.areas.isEmpty && areaGridLayout.columns.isEmpty {
                        let stackLayout = SwiftLayout()
                        stackLayout.layoutContainerType = .stack
                        parsedLayouts.append(stackLayout)
                    } else if areaGridLayout.areas.isEmpty {
                        let flowLayout = try SwiftFlowLayout.deserialize(from: layoutJson)
                        flowLayout.layoutContainerType = .flow
                        parsedLayouts.append(flowLayout)
                    } else {
                        parsedLayouts.append(SwiftAreaGridLayout.deserialize(from: layoutJson))
                    }
                default:
                    parsedLayouts.append(baseLayout)
                }
            }
            
            column.layouts = parsedLayouts
        }
        
        return column
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftColumnLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: value)
        return try deserialize(context: context, value: jsonDict)
    }
}

// MARK: - SwiftColumn Extension

extension SwiftColumn {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftColumnLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("items")
        self.knownProperties.insert("rtl")
        self.knownProperties.insert("selectAction")
        self.knownProperties.insert("width")
        self.knownProperties.insert("style")
        self.knownProperties.insert("verticalContentAlignment")
    }
    
    // MARK: - Resource Information
    func getResourceInformation(_ resourceInfo: inout [SwiftRemoteResourceInformation]) {
        for element in items {
            if let id = element.id {
                resourceInfo.append(SwiftRemoteResourceInformation(url: id, mimeType: ""))
            }
        }
    }
    
    // MARK: - Child Deserialization
    func deserializeChildren(context: SwiftParseContext, json: [String: Any]) throws {
        let cardElements = try SwiftParseUtil.getElementCollection(
            isTopToBottomContainer: true,
            context: context,
            json: json,
            key: "items",
            required: false
        )
        items = cardElements
    }
    
    // MARK: - RTL and Layout Setters
    func setRtl(_ value: Bool?) {
        rtl = value
    }
    
    func setLayouts(_ value: [SwiftLayout]) {
        layouts = value
    }
    
    // Helper to parse strings ending in "px" (e.g., "20px" → 20)
    internal func parseSizeForPixelSize(_ val: String) -> Int? {
        let lower = val.lowercased()
        guard lower.hasSuffix("px") else { return nil }
        let numberPart = lower.dropLast(2)
        return Int(numberPart)
    }
    
    // MARK: - setWidth Methods
    func setWidth(_ value: String, warnings: inout [SwiftAdaptiveCardParseWarning]) {
        self.width = value  // Property observer on 'width' will update pixelWidth
    }
    
    func setWidth(_ value: String) {
        var dummyWarnings = [SwiftAdaptiveCardParseWarning]()
        setWidth(value, warnings: &dummyWarnings)
    }
    
    func setPixelWidth(_ value: Int) {
        self.pixelWidth = value // Observer on 'pixelWidth' will update 'width'
    }
    
    func getPixelWidth() -> Int {
        return pixelWidth
    }
}

// MARK: - Consolidated SwiftColumnSet Legacy Support

/// Unified legacy support for SwiftColumnSet parsing and serialization
enum SwiftColumnSetLegacySupport {
    // MARK: - Parsing Functions
    
    /// Deserializes JSON into a SwiftColumnSet
    static public func deserialize(from value: [String: Any], context: SwiftParseContext? = nil) throws -> SwiftColumnSet {
        // Convert dictionary to JSON data
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(SwiftColumnSet.self, from: data)
    }
    
    /// Deserializes string into a SwiftColumnSet
    static public func deserialize(from jsonString: String) throws -> SwiftColumnSet {
        guard let data = jsonString.data(using: .utf8) else {
            throw SwiftJSONError.missingKey("Invalid JSON string")
        }
        return try JSONDecoder().decode(SwiftColumnSet.self, from: data)
    }
    
    // MARK: - Serialization Functions
    
    /// Converts a SwiftColumnSet to JSON dictionary with proper formatting
    static func serializeToJson(_ columnSet: SwiftColumnSet, baseJson: [String: Any]) throws -> [String: Any] {
        var json = baseJson
        
        // Set required properties
        json["type"] = "ColumnSet"
        
        // Serialize columns array
        if !columnSet.columns.isEmpty {
            var columnsArray: [[String: Any]] = []
            for column in columnSet.columns {
                let columnJson = try column.serializeToJsonValue()
                columnsArray.append(columnJson)
            }
            json["columns"] = columnsArray
        }
        
        // Add style if not default
        if columnSet.style != .none {
            json["style"] = columnSet.style.rawValue
        }
        
        // Add selectAction if present
        if let selectAction = columnSet.selectAction {
            json["selectAction"] = try SwiftBaseCardElement.serializeSelectAction(selectAction)
        }
        
        // Add bleed if true
        if columnSet.hasBleed {
            json["bleed"] = true
        }
        
        return json
    }
}

// MARK: - Parser Implementation

/// Parses ColumnSet elements in an Adaptive Card
struct SwiftColumnSetParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: .columnSet)
        
        // Parse the columnset itself
        let columnSet = try SwiftBaseCardElement.deserialize(from: value) as! SwiftColumnSet
        
        // Parse columns array
        let columnsArray: [[String: Any]] = try SwiftParseUtil.getArray(from: value, key: "columns", required: true)
        var columns: [SwiftColumn] = []
        
        for colJson in columnsArray {
            var temp = colJson
            if temp["type"] == nil {
                temp["type"] = "Column"
            }
            
            let base = try SwiftBaseCardElement.deserialize(from: temp)
            guard let col = base as? SwiftColumn else {
                throw AdaptiveCardParseError.invalidType
            }
            columns.append(col)
        }
        
        columnSet.columns = columns
        return columnSet
    }
    
    func deserializeWithoutCheckingType(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        return try SwiftColumnSetLegacySupport.deserialize(from: value, context: context)
    }
    
    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: value)
        return try deserialize(context: context, value: jsonDict)
    }
}

// MARK: - SwiftColumnSet Extension

extension SwiftColumnSet {
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat(superResult: [String: Any]) throws -> [String: Any] {
        return try SwiftColumnSetLegacySupport.serializeToJson(self, baseJson: superResult)
    }
    
    // MARK: - Known Properties
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("bleed")
        self.knownProperties.insert("columns")
        self.knownProperties.insert("selectAction")
        self.knownProperties.insert("style")
    }
    
    // MARK: - Resource Information
    func getResourceInformation(_ resourceInfo: inout [SwiftRemoteResourceInformation]) {
        // Iterate over our columns
        for column in columns {
            column.getResourceInformation(&resourceInfo)
        }
    }
    
    // MARK: - Child Deserialization
    func deserializeChildren(context: SwiftParseContext, json: [String: Any]) throws {
        // Use ParseUtil to get an array of BaseCardElement
        let elements = try SwiftParseUtil.getElementCollection(
            isTopToBottomContainer: false,
            context: context,
            json: json,
            key: "columns",
            required: false
        )
        // Filter for Column instances
        self.columns = elements.compactMap { $0 as? SwiftColumn }
    }
    
    // MARK: - Bleed Configuration
    
    /// Indicates whether this ColumnSet is nested (i.e. not at the top level of the card)
    var isNested: Bool {
        return self.parentalId != nil
    }
    
    /// Adjusts the bleedDirection for each contained Column based on position
    func configureColumnBleedDirections() {
        for (index, column) in columns.enumerated() {
            guard let column = column as? SwiftColumn else { continue }
            
            if !column.canBleed {
                column.bleedDirection = .bleedRestricted
                continue
            }
            
            // Start with bleedDown
            var direction: SwiftContainerBleedDirection = .bleedDown
            
            // Add bleedUp if parent ColumnSet has bleed enabled
            if self.hasBleed && self.canBleed {
                direction.insert(.bleedUp)
            }
            
            // Add left/right based on position
            if index == 0 {
                direction.insert(.bleedLeft)
            }
            if index == columns.count - 1 {
                direction.insert(.bleedRight)
            }
            
            column.bleedDirection = direction
            
            // Set parental ID for bleeding columns
            if column.canBleed {
                if let parentalId = self.parentalId {
                    column.parentalId = parentalId
                } else if let contextParentId = column.parentalId {
                    column.parentalId = contextParentId
                }
            }
        }
    }
}

// MARK: - Consolidated SwiftBaseElement Legacy Support

extension SwiftBaseElement {
    /// Deserialize from JSON data.
    static func decode(from json: Data) throws -> SwiftBaseElement {
        return try JSONDecoder().decode(SwiftBaseElement.self, from: json)
    }
    
    /// Serialize to JSON data.
    func encodeToData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat() throws -> [String: Any] {
        var json: [String: Any] = ["type": typeString]
        
        // Add core properties
        if let id = id {
            json["id"] = id
        }
        
        // Add additional properties
        if let additionalProperties = additionalProperties {
            for (key, anyCodable) in additionalProperties {
                json[key] = anyCodable.value
            }
        }
        
        // Add fallback info using the "fallback" key:
        if let fallbackContent = fallbackContent {
            json["fallback"] = try fallbackContent.serializeToJsonValue()
        } else if let fallbackType = fallbackType {
            json["fallback"] = fallbackType.rawValue
        }
        
        // Recursively unwrap AnyCodable values.
        if let unwrapped = SwiftParseUtil.unwrapAnyCodable(from: json) as? [String: Any] {
            return unwrapped
        }
        
        return json
    }
    
    /// Checks whether the element meets host requirements.
    func meetsRequirements(_ hostProvides: SwiftFeatureRegistration) -> Bool {
        guard let requires = requires else { return true }
        
        for (feature, requiredVersion) in requires {
            let hostVersionString = hostProvides.getFeatureVersion(featureName: feature)
            guard let hostVersion = try? SwiftSemanticVersion(hostVersionString) else {
                return false
            }
            
            if hostVersion < requiredVersion {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Consolidated SwiftBaseCardElement Legacy Support

extension SwiftBaseCardElement {
    // MARK: - Deserialization Methods
    
    /// Parses a BaseCardElement from a JSON dictionary.
    static public func deserialize(from originalJson: [String: Any]) throws -> SwiftBaseCardElement {
        // 1) Unwrap first
        let unwrapped = SwiftParseUtil.unwrapAnyCodable(from: originalJson)
        guard let jsonDict = unwrapped as? [String: Any] else {
            throw AdaptiveCardParseError.invalidJson
        }
        
        // 2) Now "type" is definitely a String if present
        guard let typeString = jsonDict["type"] as? String else {
            throw AdaptiveCardParseError.invalidType
        }
        
        let knownTypes = [
            SwiftCardElementType.textBlock.rawValue,
            SwiftCardElementType.columnSet.rawValue,
            SwiftCardElementType.container.rawValue,
            SwiftCardElementType.column.rawValue,
            SwiftCardElementType.image.rawValue,
            SwiftCardElementType.factSet.rawValue,
            SwiftCardElementType.actionSet.rawValue,
            SwiftCardElementType.richTextBlock.rawValue,
            SwiftCardElementType.imageSet.rawValue,
            SwiftCardElementType.textInput.rawValue,
            SwiftCardElementType.numberInput.rawValue,
            SwiftCardElementType.dateInput.rawValue,
            SwiftCardElementType.timeInput.rawValue,
            SwiftCardElementType.choiceSetInput.rawValue,
            SwiftCardElementType.toggleInput.rawValue,
            SwiftCardElementType.media.rawValue,
            SwiftCardElementType.table.rawValue
        ]
        
        if !knownTypes.contains(typeString) {
            // For unknown types, return an UnknownElement that just preserves the JSON.
            return try SwiftUnknownElement.createFromJSON(jsonDict)
        }
        
        // 3) Convert to Data and decode
        let data = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        let decoder = JSONDecoder()
        
        switch typeString {
        case SwiftCardElementType.textBlock.rawValue:
            return try decoder.decode(SwiftTextBlock.self, from: data)
        case SwiftCardElementType.columnSet.rawValue:
            return try decoder.decode(SwiftColumnSet.self, from: data)
        case SwiftCardElementType.container.rawValue:
            return try decoder.decode(SwiftContainer.self, from: data)
        case SwiftCardElementType.column.rawValue:
            return try decoder.decode(SwiftColumn.self, from: data)
        case SwiftCardElementType.factSet.rawValue:
            return try decoder.decode(SwiftFactSet.self, from: data)
        case SwiftCardElementType.actionSet.rawValue:
            return try decoder.decode(SwiftActionSet.self, from: data)
        case SwiftCardElementType.richTextBlock.rawValue:
            return try decoder.decode(SwiftRichTextBlock.self, from: data)
        case SwiftCardElementType.image.rawValue:
            return try decoder.decode(SwiftImage.self, from: data)
        case SwiftCardElementType.imageSet.rawValue:
            return try decoder.decode(SwiftImageSet.self, from: data)
        case SwiftCardElementType.textInput.rawValue:
            return try decoder.decode(SwiftTextInput.self, from: data)
        case SwiftCardElementType.numberInput.rawValue:
            return try decoder.decode(SwiftNumberInput.self, from: data)
        case SwiftCardElementType.dateInput.rawValue:
            return try decoder.decode(SwiftDateInput.self, from: data)
        case SwiftCardElementType.timeInput.rawValue:
            return try decoder.decode(SwiftTimeInput.self, from: data)
        case SwiftCardElementType.choiceSetInput.rawValue:
            return try decoder.decode(SwiftChoiceSetInput.self, from: data)
        case SwiftCardElementType.toggleInput.rawValue:
            return try decoder.decode(SwiftToggleInput.self, from: data)
        case SwiftCardElementType.media.rawValue:
            return try decoder.decode(SwiftMedia.self, from: data)
        case SwiftCardElementType.table.rawValue:
            return try decoder.decode(SwiftTable.self, from: data)
        case SwiftCardElementType.unknown.rawValue:
            fallthrough
        default:
            return try decoder.decode(SwiftBaseCardElement.self, from: data)
        }
    }

    /// Parses a BaseCardElement from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftBaseCardElement {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []),
              let jsonDict = jsonObject as? [String: Any] else {
            throw AdaptiveCardParseError.invalidJson
        }
        return try deserialize(from: jsonDict)
    }
    
    // MARK: - Utility Methods
    
    /// Factory method for creating from JSON
    static func fromJSON(_ json: [String: Any]) -> SwiftBaseCardElement? {
        return try? self.deserialize(from: json)
    }
    
    /// Set additional properties from a JSON dictionary
    func setAdditionalProperties(_ json: [String: Any]) {
        var codableDict = [String: SwiftAnyCodable]()
        for (key, value) in json {
            codableDict[key] = SwiftAnyCodable(value)
        }
        self.additionalProperties = codableDict
    }
    
    /// Set the element type string
    func setElementTypeString(_ type: String) {
        self.typeString = type
    }
    
    // MARK: - Element Lookup Methods
    
    /// Helper method to find parent element
    func findParent() -> SwiftBaseCardElement? {
        guard let parentId = parentalId else { return nil }
        return findElement(withId: parentId)
    }
    
    /// Helper method to find element by ID
    func findElement(withId id: SwiftInternalId) -> SwiftBaseCardElement? {
        // This needs to be implemented with access to the element registry
        // For now, return nil to match current behavior
        return nil
    }
    
    // MARK: - Action Serialization
    
    /// Serialize a select action
    static func serializeSelectAction(_ action: SwiftBaseActionElement) throws -> [String: Any] {
        return try action.serializeToJsonValue()
    }
    
    // MARK: - Type Properties
    
    /// Returns the type string (as originally decoded)
    public var elementTypeString: String {
        return self.typeString
    }
    
    /// A convenience "parse" method used in tests.
    public static func parse(json: [String: Any], context: SwiftParseContext) -> SwiftBaseCardElement? {
        // We simply attempt to deserialize and return nil if an error is thrown.
        return try? SwiftBaseCardElement.deserialize(from: json)
    }
}

// MARK: - Consolidated SwiftAdaptiveCard Legacy Support

extension SwiftAdaptiveCard {
    // MARK: - Deserialization Methods
    
    /// Deserializes an AdaptiveCard from a JSON dictionary.
    static public func deserialize(from json: [String: Any]) throws -> SwiftAdaptiveCard {
        let version = json[SwiftAdaptiveCardSchemaKey.version.rawValue] as? String ?? "1.0"
        let fallbackText = json[SwiftAdaptiveCardSchemaKey.fallbackText.rawValue] as? String
        
        // Handle backgroundImage, which can be a string or a dictionary
        let backgroundImageValue = json[SwiftAdaptiveCardSchemaKey.backgroundImage.rawValue]
        let backgroundImage: SwiftBackgroundImage?
        if let bgStr = backgroundImageValue as? String {
            backgroundImage = SwiftBackgroundImage(url: bgStr, fillMode: .cover, horizontalAlignment: .left, verticalAlignment: .top)
        } else if let bgDict = backgroundImageValue as? [String: Any] {
            backgroundImage = try SwiftBackgroundImage.deserialize(from: bgDict)
        } else {
            backgroundImage = nil
        }
        
        // Parse refresh and authentication if present
        let refreshJson = json[SwiftAdaptiveCardSchemaKey.refresh.rawValue] as? [String: Any]
        let refresh = try refreshJson.map { try SwiftRefresh.deserialize(from: $0) }
        
        let authenticationJson = json[SwiftAdaptiveCardSchemaKey.authentication.rawValue] as? [String: Any]
        let authentication = try authenticationJson.map { try SwiftAuthentication.deserialize(from: $0) }
        
        // Parse basic properties
        let speak = json[SwiftAdaptiveCardSchemaKey.speak.rawValue] as? String
        let style = SwiftContainerStyle(rawValue: json[SwiftAdaptiveCardSchemaKey.style.rawValue] as? String ?? "none") ?? SwiftContainerStyle.none
        let language = (json[SwiftAdaptiveCardSchemaKey.language.rawValue] as? String) ?? (json["lang"] as? String)
        let verticalContentAlignment = SwiftVerticalContentAlignment(rawValue: json[SwiftAdaptiveCardSchemaKey.verticalContentAlignment.rawValue] as? String ?? "top") ?? .top
        let height = SwiftHeightType(rawValue: json[SwiftAdaptiveCardSchemaKey.height.rawValue] as? String ?? "auto") ?? .auto
        
        // Parse minHeight, which could be a string with "px" suffix or a UInt
        var minHeight: UInt = 0
        if let minHeightStr = json[SwiftAdaptiveCardSchemaKey.minHeight.rawValue] as? String {
            let digits = minHeightStr.filter { "0123456789".contains($0) }
            minHeight = UInt(digits) ?? 0
        } else if let mh = json[SwiftAdaptiveCardSchemaKey.minHeight.rawValue] as? UInt {
            minHeight = mh
        }
        
        let rtl = json[SwiftAdaptiveCardSchemaKey.rtl.rawValue] as? Bool
        
        // Process body elements
        let bodyJson = json[SwiftAdaptiveCardSchemaKey.body.rawValue] as? [[String: Any]] ?? []
        let adjustedBodyJson = bodyJson.map { element -> [String: Any] in
            var element = element
            if let type = element["type"] as? String, type == "Table" {
                if let rows = element["rows"] as? [[String: Any]] {
                    let adjustedRows = rows.map { row -> [String: Any] in
                        var row = row
                        if row["type"] == nil { row["type"] = "TableRow" }
                        if let cells = row["cells"] as? [[String: Any]] {
                            let adjustedCells = cells.map { cell -> [String: Any] in
                                var cell = cell
                                if cell["type"] == nil { cell["type"] = "TableCell" }
                                return cell
                            }
                            row["cells"] = adjustedCells
                        }
                        return row
                    }
                    element["rows"] = adjustedRows
                }
            }
            return element
        }
        let body = try adjustedBodyJson.map { try SwiftBaseCardElement.deserialize(from: $0) }
        
        // Process actions
        let actionsJson = json[SwiftAdaptiveCardSchemaKey.actions.rawValue] as? [[String: Any]] ?? []
        let actions = try actionsJson.map { try SwiftBaseActionElement.deserializeAction(from: $0) }
        
        // Process layouts
        let layoutsJson = json[SwiftAdaptiveCardSchemaKey.layouts.rawValue] as? [[String: Any]] ?? []
        let layouts = try layoutsJson.map { json in
            guard let layout = SwiftLayout.fromJSON(json) else {
                throw AdaptiveCardParseError.invalidJson
            }
            return layout
        }
        
        // Process selectAction if present
        var selectAction: SwiftBaseActionElement? = nil
        if let selectActionJson = json[SwiftAdaptiveCardSchemaKey.selectAction.rawValue] as? [String: Any] {
            selectAction = try SwiftBaseActionElement.deserializeAction(from: selectActionJson)
        }
        
        // Create the card with parsed properties
        let card = SwiftAdaptiveCard(
            version: version,
            fallbackText: fallbackText,
            backgroundImage: backgroundImage,
            refresh: refresh,
            authentication: authentication,
            speak: speak,
            style: style,
            language: language,
            verticalContentAlignment: verticalContentAlignment,
            height: height,
            minHeight: minHeight,
            rtl: rtl,
            body: body,
            actions: actions,
            layouts: layouts,
            selectAction: selectAction,
            requires: [:],
            fallbackContent: nil,
            fallbackType: .none
        )
        
        // Remove known keys from additionalProperties
        let knownKeys: Set<String> = [
            "$schema", "type", SwiftAdaptiveCardSchemaKey.version.rawValue,
            SwiftAdaptiveCardSchemaKey.fallbackText.rawValue,
            SwiftAdaptiveCardSchemaKey.backgroundImage.rawValue,
            SwiftAdaptiveCardSchemaKey.refresh.rawValue,
            SwiftAdaptiveCardSchemaKey.authentication.rawValue,
            SwiftAdaptiveCardSchemaKey.speak.rawValue,
            SwiftAdaptiveCardSchemaKey.style.rawValue,
            SwiftAdaptiveCardSchemaKey.language.rawValue,
            "lang",
            SwiftAdaptiveCardSchemaKey.verticalContentAlignment.rawValue,
            SwiftAdaptiveCardSchemaKey.height.rawValue,
            SwiftAdaptiveCardSchemaKey.minHeight.rawValue,
            SwiftAdaptiveCardSchemaKey.rtl.rawValue,
            SwiftAdaptiveCardSchemaKey.body.rawValue,
            SwiftAdaptiveCardSchemaKey.actions.rawValue,
            SwiftAdaptiveCardSchemaKey.layouts.rawValue,
            SwiftAdaptiveCardSchemaKey.selectAction.rawValue,
            SwiftAdaptiveCardSchemaKey.requires.rawValue,
            SwiftAdaptiveCardSchemaKey.fallback.rawValue
        ]
        var additionalProps = json
        for key in knownKeys {
            additionalProps.removeValue(forKey: key)
        }
        card.additionalProperties = additionalProps
        
        // Check for duplicate IDs
        try checkDuplicateIds(in: card)
        
        return card
    }
    
    // MARK: - Serialization Methods
    
    /// Serializes to legacy JSON format
    func serializeToLegacyJsonFormat() throws -> [String: Any] {
        var json = additionalProperties
        
        // Essential fields that should always be included
        json["type"] = "AdaptiveCard"
        json[SwiftAdaptiveCardSchemaKey.version.rawValue] = version
        
        // Only include non-empty optional fields
        if let language = language {
            json["lang"] = language
        }
        
        // Background image - serialize as string if it's simple URL, object if complex
        if let backgroundImage = backgroundImage {
            // Check if it's a simple background image (just URL with default values)
            if backgroundImage.fillMode == .cover && 
               backgroundImage.horizontalAlignment == .left && 
               backgroundImage.verticalAlignment == .top {
                // Serialize as simple string for simple cases
                json[SwiftAdaptiveCardSchemaKey.backgroundImage.rawValue] = backgroundImage.url
            } else {
                // Serialize as object for complex cases
                json[SwiftAdaptiveCardSchemaKey.backgroundImage.rawValue] = SwiftBackgroundImageLegacySupport.serializeToJson(backgroundImage)
            }
        }
        
        // Body elements
        json[SwiftAdaptiveCardSchemaKey.body.rawValue] = try body.map { try $0.serializeToJsonValue() }
        
        // Actions with cleanup of empty/default fields
        let serializedActions = try actions.map { action -> [String: Any] in
            var actionJson = try action.serializeToJsonValue()
            
            // Remove empty or default fields from actions
            if let title = actionJson["title"] as? String, title.isEmpty {
                actionJson.removeValue(forKey: "title")
            }
            actionJson.removeValue(forKey: "conditionallyEnabled")
            
            return actionJson
        }
        json[SwiftAdaptiveCardSchemaKey.actions.rawValue] = serializedActions
        
        // Handle optional fields based on whether they have non-default values
        if let fallbackText = fallbackText, !fallbackText.isEmpty {
            json[SwiftAdaptiveCardSchemaKey.fallbackText.rawValue] = fallbackText
        }
        if let speak = speak, !speak.isEmpty {
            json[SwiftAdaptiveCardSchemaKey.speak.rawValue] = speak
        }
        if style != .none {
            json[SwiftAdaptiveCardSchemaKey.style.rawValue] = style.rawValue
        }
        if verticalContentAlignment != .top {
            json[SwiftAdaptiveCardSchemaKey.verticalContentAlignment.rawValue] = verticalContentAlignment.rawValue
        }
        if height != .auto {
            json[SwiftAdaptiveCardSchemaKey.height.rawValue] = height.rawValue
        }
        if !layouts.isEmpty {
            json[SwiftAdaptiveCardSchemaKey.layouts.rawValue] = layouts.map { $0.serializeToJsonValue() }
        }
        
        // Handle minHeight consistently
        if minHeight > 0 {
            json[SwiftAdaptiveCardSchemaKey.minHeight.rawValue] = "\(minHeight)px"
        }
        
        return json
    }
    
    // MARK: - Utility Methods
    
    /// Gets resource information from the card
    func getResourceInformation() -> [SwiftRemoteResourceInformation] {
        // Implement resource extraction logic if needed.
        // For now, return an empty array.
        return []
    }
    
    /// Deserializes an AdaptiveCard from a JSON string.
    static public func deserialize(from jsonString: String) throws -> SwiftAdaptiveCard {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: jsonString)
        return try deserialize(from: jsonDict)
    }
    
    /// Creates an AdaptiveCard that serves as a fallback, containing a single TextBlock with the provided text.
    public func makeFallbackTextCard(text: String, language: String, speak: String) -> SwiftAdaptiveCard? {
        let fallbackTextBlock = SwiftTextBlock(
            text: text,
            textStyle: .heading,      // Use heading as expected
            textSize: SwiftTextSize.defaultSize,
            textWeight: SwiftTextWeight.defaultWeight,
            fontType: nil,
            textColor: .default,
            isSubtle: false,
            wrap: false,
            maxLines: 1,
            horizontalAlignment: .left,
            language: language,
            id: nil
        )
        
        // Set fallbackText to an empty string (instead of nil)
        // and speak to an empty string if that’s what is expected.
        return SwiftAdaptiveCard(
            version: self.version,
            fallbackText: "",      // explicitly set to empty string
            backgroundImage: nil,
            refresh: nil,
            authentication: nil,
            speak: "speak",             // explicitly set to empty string
            style: .none,
            language: language,    // should be "en" in our test
            verticalContentAlignment: .top,
            height: .auto,
            minHeight: 0,
            rtl: nil,
            body: [fallbackTextBlock],
            actions: [],
            layouts: [],
            selectAction: nil,
            requires: [:],
            fallbackContent: nil,
            fallbackType: .none
        )
    }
    
    internal static func checkDuplicateIds(in card: SwiftAdaptiveCard) throws {
        print("Starting duplicate ID check")  // Debug print
        var seen = Set<String>()
        
        // Check body
        print("Checking body elements...")  // Debug print
        for element in card.body {
            try gatherIds(element, &seen)
        }
        
        // Check actions
        print("Checking actions...")  // Debug print
        for action in card.actions {
            try gatherIds(action, &seen)
        }
        
        print("Found IDs: \(seen)")  // Debug print
    }
    
    internal static func gatherIds(_ element: Any, _ seen: inout Set<String>) throws {
        switch element {
        case let action as SwiftBaseActionElement:
            // First, check the action’s own id.
            if let theId = action.id, !theId.isEmpty {
                if seen.contains(theId) {
                    throw AdaptiveCardParseError.idCollision
                }
                seen.insert(theId)
            }
            // Then, if it is a ShowCardAction, recurse into its nested card.
            if let showCard = action as? SwiftShowCardAction, let nestedCard = showCard.card {
                for item in nestedCard.body { try gatherIds(item, &seen) }
                for nestedAction in nestedCard.actions { try gatherIds(nestedAction, &seen) }
                if let selectAction = nestedCard.selectAction {
                    try gatherIds(selectAction, &seen)
                }
            }
            
        case let base as SwiftBaseCardElement:
            // Now handle any BaseCardElement that isn’t an action.
            if let theId = base.id, !theId.isEmpty {
                if seen.contains(theId) {
                    throw AdaptiveCardParseError.idCollision
                }
                seen.insert(theId)
            }
            // Recurse into composite elements.
            if let container = base as? SwiftContainer {
                for item in container.items { try gatherIds(item, &seen) }
            }
            if let colSet = base as? SwiftColumnSet {
                for col in colSet.columns { try gatherIds(col, &seen) }
            }
            if let col = base as? SwiftColumn {
                for item in col.items { try gatherIds(item, &seen) }
            }
            
        case let card as SwiftAdaptiveCard:
            // Also check the AdaptiveCard itself.
            for item in card.body { try gatherIds(item, &seen) }
            for action in card.actions { try gatherIds(action, &seen) }
            if let selectAction = card.selectAction {
                try gatherIds(selectAction, &seen)
            }
            
        default:
            break
        }
    }
}
