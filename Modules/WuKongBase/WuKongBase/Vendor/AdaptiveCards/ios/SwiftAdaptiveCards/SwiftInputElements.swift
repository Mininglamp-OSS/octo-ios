//
//  SwiftInputElements.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

/// Represents an input element in an Adaptive Card. This class inherits from BaseCardElement and adds additional
/// properties specific to input elements.
public class SwiftBaseInputElement: SwiftBaseCardElement {
    // MARK: - Properties
    /// The text label for the input element.
    public let label: String?
    /// Indicates whether a value is required.
    public let isRequired: Bool
    /// The error message to display if the input is invalid.
    public let errorMessage: String?
    /// An action to execute when the input's value changes.
    let valueChangedAction: SwiftValueChangedAction?

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case label
        case isRequired
        case errorMessage
        case valueChangedAction
    }

    /// Decodes properties from the given decoder.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        label = try container.decodeIfPresent(String.self, forKey: .label)
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        valueChangedAction = try container.decodeIfPresent(SwiftValueChangedAction.self, forKey: .valueChangedAction)
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }

    /// Encodes properties into the given encoder.
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(label, forKey: .label)
        // Only encode isRequired if it's true (non-default)
        if isRequired {
            try container.encode(isRequired, forKey: .isRequired)
        }
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(valueChangedAction, forKey: .valueChangedAction)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    /// Serializes the BaseInputElement to a JSON dictionary.
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    func populateKnownPropertiesSet() {
        self.knownProperties.insert("label")
        self.knownProperties.insert("isRequired")
        self.knownProperties.insert("errorMessage")
        self.knownProperties.insert("valueChangedAction")
    }
}


/// Represents a toggle input field in an Adaptive Card.
public class SwiftToggleInput: SwiftBaseInputElement {
    // MARK: - Properties
    /// The display title for the toggle.
    public let title: String?
    
    /// The default value of the toggle.
    public let value: String?
    
    /// The value representing an "off" state.
    public let valueOff: String
    
    /// The value representing an "on" state.
    public let valueOn: String
    
    /// Whether the title should wrap.
    public let wrap: Bool

    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case title
        case value
        case valueOff
        case valueOn
        case wrap
    }

    /// Required initializer for decoding.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        title = try container.decodeIfPresent(String.self, forKey: .title)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        valueOff = try container.decodeIfPresent(String.self, forKey: .valueOff) ?? "false"
        valueOn = try container.decodeIfPresent(String.self, forKey: .valueOn) ?? "true"
        wrap = try container.decodeIfPresent(Bool.self, forKey: .wrap) ?? false
        
        // Call super's decoding initializer
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }

    /// Encodes a `ToggleInput` to JSON.
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(value, forKey: .value)
        
        // Only encode non-default values
        if valueOff != "false" {
            try container.encode(valueOff, forKey: .valueOff)
        }
        if valueOn != "true" {
            try container.encode(valueOn, forKey: .valueOn)
        }
        if wrap {
            try container.encode(wrap, forKey: .wrap)
        }
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        self.knownProperties.insert("title")
        self.knownProperties.insert("value")
        self.knownProperties.insert("valueOff")
        self.knownProperties.insert("valueOn")
        self.knownProperties.insert("wrap")
    }
}

/// Represents a time input field in an Adaptive Card.
public class SwiftTimeInput: SwiftBaseInputElement {
    // MARK: - Properties
    public let max: String?
    public let min: String?
    public let placeholder: String?
    public let value: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case max, min, placeholder, value
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        max = try container.decodeIfPresent(String.self, forKey: .max)
        min = try container.decodeIfPresent(String.self, forKey: .min)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(value, forKey: .value)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        self.knownProperties.insert("max")
        self.knownProperties.insert("min")
        self.knownProperties.insert("placeholder")
        self.knownProperties.insert("value")
    }
}

/// Represents a ChoiceSetInput in an Adaptive Card.
public class SwiftChoiceSetInput: SwiftBaseInputElement {
    // MARK: - Properties
    public let isMultiSelect: Bool
    public let choiceSetStyle: SwiftChoiceSetStyle
    public let choices: [SwiftChoiceInput]
    public let choicesData: SwiftChoicesData?
    public let value: String
    public let wrap: Bool
    public let placeholder: String

    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case isMultiSelect  = "isMultiSelect"
        case choiceSetStyle = "style"
        case choices        = "choices"
        case choicesData    = "choicesData"
        case value          = "value"
        case wrap           = "wrap"
        case placeholder    = "placeholder"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        isMultiSelect  = try container.decodeIfPresent(Bool.self, forKey: .isMultiSelect) ?? false
        choiceSetStyle = try container.decodeIfPresent(SwiftChoiceSetStyle.self, forKey: .choiceSetStyle) ?? .compact
        choices        = try container.decodeIfPresent([SwiftChoiceInput].self, forKey: .choices) ?? []
        choicesData    = try container.decodeIfPresent(SwiftChoicesData.self, forKey: .choicesData)
        value          = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        wrap           = try container.decodeIfPresent(Bool.self, forKey: .wrap) ?? false
        placeholder    = try container.decodeIfPresent(String.self, forKey: .placeholder) ?? ""
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isMultiSelect, forKey: .isMultiSelect)
        try container.encode(choiceSetStyle, forKey: .choiceSetStyle)
        
        // Encode choices with their type field included
        try container.encode(choices, forKey: .choices)
        
        try container.encodeIfPresent(choicesData, forKey: .choicesData)
        try container.encode(value, forKey: .value)
        try container.encode(wrap, forKey: .wrap)
        try container.encode(placeholder, forKey: .placeholder)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        super.populateKnownPropertiesSet()
        self.knownProperties.insert("isMultiSelect")
        self.knownProperties.insert("style")
        self.knownProperties.insert("choices")
        self.knownProperties.insert("choicesData")
        self.knownProperties.insert("value")
        self.knownProperties.insert("wrap")
        self.knownProperties.insert("placeholder")
    }
}

/// Represents a number input element in an Adaptive Card.
public class SwiftNumberInput: SwiftBaseInputElement {
    // MARK: - Properties
    public let placeholder: String?
    public let value: Double?
    public let min: Double?
    public let max: Double?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case placeholder, value, min, max
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        
        // For numeric values, we might need to handle both String and Number formats
        if let valueDouble = try? container.decodeIfPresent(Double.self, forKey: .value) {
            value = valueDouble
        } else if let valueString = try? container.decodeIfPresent(String.self, forKey: .value),
                  let valueDouble = Double(valueString) {
            value = valueDouble
        } else {
            value = nil
        }
        
        // Same for min/max
        if let minDouble = try? container.decodeIfPresent(Double.self, forKey: .min) {
            min = minDouble
        } else if let minString = try? container.decodeIfPresent(String.self, forKey: .min),
                  let minDouble = Double(minString) {
            min = minDouble
        } else {
            min = nil
        }
        
        if let maxDouble = try? container.decodeIfPresent(Double.self, forKey: .max) {
            max = maxDouble
        } else if let maxString = try? container.decodeIfPresent(String.self, forKey: .max),
                  let maxDouble = Double(maxString) {
            max = maxDouble
        } else {
            max = nil
        }
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(max, forKey: .max)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        self.knownProperties.insert("placeholder")
        self.knownProperties.insert("value")
        self.knownProperties.insert("min")
        self.knownProperties.insert("max")
    }
}

/// Represents a text input element in an Adaptive Card.
public class SwiftTextInput: SwiftBaseInputElement {
    // MARK: - Properties
    /// Placeholder text displayed when the input is empty.
    public let placeholder: String?
    
    /// The default value of the input field.
    public let value: String?
    
    /// Whether the input field is multiline.
    public let isMultiline: Bool
    
    /// Maximum length of the input field.
    public let maxLength: UInt
    
    /// Style of the text input.
    public let style: SwiftTextInputStyle?
    
    /// Optional inline action associated with the input.
    public let inlineAction: SwiftBaseActionElement?
    
    /// Regular expression for validation.
    public let regex: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case placeholder, value, isMultiline, maxLength, style, inlineAction, regex
    }
    
    /// Required initializer for decoding.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        isMultiline = try container.decodeIfPresent(Bool.self, forKey: .isMultiline) ?? false
        maxLength = try container.decodeIfPresent(UInt.self, forKey: .maxLength) ?? 0
        style = try container.decodeIfPresent(SwiftTextInputStyle.self, forKey: .style)
        regex = try container.decodeIfPresent(String.self, forKey: .regex)
        
        // Handle inlineAction separately
        if container.contains(.inlineAction) {
            let actionDict = try container.decode([String: SwiftAnyCodable].self, forKey: .inlineAction)
            let dict = actionDict.mapValues { $0.value }
            inlineAction = try SwiftBaseActionElement.deserializeAction(from: dict)
        } else {
            inlineAction = nil
        }
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    /// Encodes a `TextInput` to JSON.
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(value, forKey: .value)
        // Only encode isMultiline if it's true (non-default)
        if isMultiline {
            try container.encode(isMultiline, forKey: .isMultiline)
        }
        // Only encode maxLength if it's greater than 0 (non-default)
        if maxLength > 0 {
            try container.encode(maxLength, forKey: .maxLength)
        }
        try container.encodeIfPresent(style, forKey: .style)
        try container.encodeIfPresent(regex, forKey: .regex)
        
        if let action = inlineAction {
            try container.encode(SwiftAnyCodable(try action.serializeToJsonValue()), forKey: .inlineAction)
        }
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        super.populateKnownPropertiesSet()
        self.knownProperties.insert("placeholder")
        self.knownProperties.insert("value")
        self.knownProperties.insert("isMultiline")
        self.knownProperties.insert("maxLength")
        self.knownProperties.insert("style")
        self.knownProperties.insert("inlineAction")
        self.knownProperties.insert("regex")
    }
}

/// Represents a date input element in an Adaptive Card.
public class SwiftDateInput: SwiftBaseInputElement {
    // MARK: - Properties
    public let max: String?
    public let min: String?
    public let placeholder: String?
    public let value: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case max, min, placeholder, value
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        max = try container.decodeIfPresent(String.self, forKey: .max)
        min = try container.decodeIfPresent(String.self, forKey: .min)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(value, forKey: .value)
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    override func populateKnownPropertiesSet() {
        self.knownProperties.insert("max")
        self.knownProperties.insert("min")
        self.knownProperties.insert("placeholder")
        self.knownProperties.insert("value")
    }
}

/// Represents a choice input in an Adaptive Card.
public struct SwiftChoiceInput: Codable {
    // MARK: - Properties
    public let type: String?
    public let title: String
    public let value: String
    
    init(title: String, value: String) {
        self.type = "Input.Choice"
        self.title = title
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "Input.Choice"
        self.title = try container.decode(String.self, forKey: .title)
        self.value = try container.decode(String.self, forKey: .value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type ?? "Input.Choice", forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(value, forKey: .value)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case value
    }
}
