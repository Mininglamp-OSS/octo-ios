//
//  SwiftEnums.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

public enum SwiftCardElementType: String, Codable {
    case actionSet = "ActionSet"
    case adaptiveCard = "AdaptiveCard"
    case choiceSetInput = "Input.ChoiceSet"
    case column = "Column"
    case columnSet = "ColumnSet"
    case container = "Container"
    case custom = "Custom"
    case dateInput = "Input.Date"
    case fact = "Fact"
    case factSet = "FactSet"
    case image = "Image"
    case icon = "Icon"
    case imageSet = "ImageSet"
    case media = "Media"
    case numberInput = "Input.Number"
    case ratingInput = "Input.Rating"
    case ratingLabel = "Rating"
    case richTextBlock = "RichTextBlock"
    case table = "Table"
    case tableCell = "TableCell"
    case tableRow = "TableRow"
    case textBlock = "TextBlock"
    case textInput = "Input.Text"
    case timeInput = "Input.Time"
    case toggleInput = "Input.Toggle"
    case compoundButton = "CompoundButton"
    case unknown = "Unknown"
}

// MARK: - CardElementType

/// The test expects `.adaptiveCard` → "AdaptiveCard", etc.
public extension SwiftCardElementType {
    static func toString(_ value: SwiftCardElementType) -> String {
        return value.rawValue
    }
    
    static func fromString(_ str: String) -> SwiftCardElementType? {
        return SwiftCardElementType(rawValue: str)
    }
}

public enum SwiftMode: String, Codable {
    case primary, secondary
}

public enum SwiftErrorStatusCode: String, Codable {
    case invalidJson, renderFailed, requiredPropertyMissing, invalidPropertyValue, unsupportedParserOverride, idCollision, customError, unknownElementType, serializationFailed
}

public enum SwiftWarningStatusCode: String, Codable {
    case unknownElementType, unknownActionElementType, unknownPropertyOnElement, unknownEnumValue, noRendererForType
    case interactivityNotSupported, maxActionsExceeded, assetLoadFailed, unsupportedSchemaVersion, unsupportedMediaType
    case invalidMediaMix, invalidColorFormat, invalidDimensionSpecified, invalidLanguage, invalidValue, customWarning
    case emptyLabelInRequiredInput, requiredPropertyMissing
}

public enum SwiftHostWidth: String, Codable {
    case `default`, veryNarrow, narrow, standard, wide
    static func < (lhs: SwiftHostWidth, rhs: SwiftHostWidth) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    static func <= (lhs: SwiftHostWidth, rhs: SwiftHostWidth) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
    static func >= (lhs: SwiftHostWidth, rhs: SwiftHostWidth) -> Bool {
        return lhs.rawValue >= rhs.rawValue
    }
}

public enum SwiftTargetWidthType: String, Codable {
    case `default` = "Default", veryNarrow, narrow, standard, wide
    case atMostVeryNarrow, atMostNarrow, atMostStandard, atMostWide
    case atLeastVeryNarrow, atLeastNarrow, atLeastStandard, atLeastWide
}

// MARK: - TextSize

public enum SwiftTextSize: String, Codable {
    case defaultSize = "Default"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "ExtraLarge"
    
    init(from rawValue: String) {
        self = SwiftTextSize.caseInsensitiveValue(from: rawValue)
    }
}

public extension SwiftTextSize {
    static func toString(_ value: SwiftTextSize) -> String {
        return value.rawValue
    }
    
    static func fromString(_ s: String) -> SwiftTextSize? {
        let lowered = s.lowercased()
        if lowered == "normal" { return .defaultSize }
        switch lowered {
        case "default": return .defaultSize
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "extralarge": return .extraLarge
        default: return nil
        }
    }
    
    // Create a caseInsensitiveValue function for consistent parser handling
    static func caseInsensitiveValue(from string: String) -> SwiftTextSize {
        let lowercased = string.lowercased()
        switch lowercased {
        case "default", "normal": return .defaultSize
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "extralarge": return .extraLarge
        default: return .defaultSize // Default to defaultSize if not recognized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SwiftTextSize.caseInsensitiveValue(from: raw)
    }
}

// MARK: - TextWeight

public enum SwiftTextWeight: String, Codable {
    case defaultWeight = "Default"
    case lighter = "Lighter"
    case bolder = "Bolder"
    
    init(from rawValue: String) {
        self = SwiftTextWeight.caseInsensitiveValue(from: rawValue)
    }
}

public extension SwiftTextWeight {
    static func toString(_ value: SwiftTextWeight) -> String {
        // Use rawValue for consistent capitalization
        return value.rawValue
    }
    
    static func fromString(_ s: String) -> SwiftTextWeight? {
        switch s {
        case "Default": return .defaultWeight
        case "Normal": return .defaultWeight  // Additional reverse mapping for backward compatibility
        case "Lighter": return .lighter
        case "Bolder": return .bolder
        default: return nil
        }
    }
    
    // Create a caseInsensitiveValue function for consistent parser handling
    static func caseInsensitiveValue(from string: String) -> SwiftTextWeight {
        let lowercased = string.lowercased()
        switch lowercased {
        case "default", "normal": return .defaultWeight
        case "lighter": return .lighter
        case "bolder": return .bolder
        default: return .defaultWeight // Default to default weight if not recognized
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SwiftTextWeight.caseInsensitiveValue(from: raw)
    }
}

// MARK: - FontType

public enum SwiftFontType: String, Codable {
    case defaultFont = "Default"
    case monospace = "Monospace"
    init(from rawValue: String) {
        self = SwiftFontType(rawValue: rawValue) ?? .defaultFont
    }
}

public extension SwiftFontType {
    static func toString(_ value: SwiftFontType) -> String {
        switch value {
        case .defaultFont: return "Default"
        case .monospace: return "Monospace"
        }
    }
    
    static func fromString(_ s: String) -> SwiftFontType? {
        switch s {
        case "Default": return .defaultFont
        case "Monospace": return .monospace
        default: return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Capitalize the string so that "monospace" becomes "Monospace"
        self = SwiftFontType(rawValue: raw.capitalized) ?? .defaultFont
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - ForegroundColor

public enum SwiftForegroundColor: String, Codable {
    case `default` = "Default"
    case dark = "Dark"
    case light = "Light"
    case accent = "Accent"
    case good = "Good"
    case warning = "Warning"
    case attention = "Attention"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Try direct match first, then try case-insensitive match
        if let color = SwiftForegroundColor(rawValue: raw) {
            self = color
        } else if let color = SwiftForegroundColor.fromString(raw) {
            self = color
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot initialize ForegroundColor from invalid String value \(raw)")
        }
    }
}

// Rest of the extension remains the same
public extension SwiftForegroundColor {
    static func toString(_ value: SwiftForegroundColor) -> String {
        switch value {
        case .default: return "Default"
        case .dark: return "Dark"
        case .light: return "Light"
        case .accent: return "Accent"
        case .good: return "Good"
        case .warning: return "Warning"
        case .attention: return "Attention"
        }
    }
    
    static func fromString(_ s: String) -> SwiftForegroundColor? {
        switch s.capitalized {
        case "Default": return .default
        case "Dark": return .dark
        case "Light": return .light
        case "Accent": return .accent
        case "Good": return .good
        case "Warning": return .warning
        case "Attention": return .attention
        default: return nil
        }
    }
}
// MARK: - HorizontalAlignment

public enum SwiftHorizontalAlignment: String, Codable {
    case left = "left"
    case center = "center"
    case right = "right"
    
    init(from rawValue: String) {
        self = SwiftHorizontalAlignment(rawValue: rawValue) ?? .left
    }
}

public extension SwiftHorizontalAlignment {
    static func toString(_ value: SwiftHorizontalAlignment) -> String {
        return value.rawValue
    }
    
    static func fromString(_ s: String) -> SwiftHorizontalAlignment? {
        // Handle case-insensitive matching for horizontal alignment
        let lowercased = s.lowercased()
        switch lowercased {
        case "left":
            return .left
        case "center":
            return .center
        case "right":
            return .right
        default:
            return nil
        }
    }
    
    // Create a caseInsensitiveValue function to use in our decoder
    static func caseInsensitiveValue(from string: String) -> SwiftHorizontalAlignment {
        return fromString(string) ?? .left
    }
}

// MARK: - VerticalAlignment

public enum SwiftVerticalAlignment: String, Codable {
    case top = "top"
    case center = "center"
    case bottom = "bottom"
}
// Your test references a “VerticalContentAlignment” with `.center`.
// If you really need that exact enum, define it:
public enum SwiftVerticalContentAlignment: String, Codable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
}

public extension SwiftVerticalContentAlignment {
    static func toString(_ value: SwiftVerticalContentAlignment) -> String {
        return value.rawValue
    }
    
    static func fromString(_ string: String) -> SwiftVerticalContentAlignment? {
        // Handle case-insensitive matching for vertical content alignment
        let lowercased = string.lowercased()
        switch lowercased {
        case "top":
            return .top
        case "center":
            return .center
        case "bottom":
            return .bottom
        default:
            // Try original capitalization approach
            let normalized = string.capitalized
            return SwiftVerticalContentAlignment(rawValue: normalized)
        }
    }
    
    // Create a caseInsensitiveValue function to use in our decoder
    static func caseInsensitiveValue(from string: String) -> SwiftVerticalContentAlignment {
        return fromString(string) ?? .top
    }
}

// MARK: - ImageSize

public enum SwiftImageSize: String, Codable {
    case none = "None"
    case auto = "Auto"
    case large = "Large"
    case medium = "Medium"
    case small = "Small"
    case stretch = "Stretch"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Use the caseInsensitiveValue method for consistent handling
        self = SwiftImageSize.caseInsensitiveValue(from: raw)
    }
}

public extension SwiftImageSize {
    static func toString(_ value: SwiftImageSize) -> String {
        switch value {
        case .none: return "None"
        case .auto: return "Auto"
        case .stretch: return "Stretch"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large" // if your test wants capital "Large"
        }
    }
    static func fromString(_ s: String) -> SwiftImageSize? {
        let lowered = s.lowercased()
        if lowered == "normal" { return .medium } // Normal maps to medium size
        switch lowered {
        case "none": return SwiftImageSize.none
        case "auto": return .auto
        case "stretch": return .stretch
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        default: return nil
        }
    }
    
    // Create a caseInsensitiveValue function for consistent parser handling
    static func caseInsensitiveValue(from string: String) -> SwiftImageSize {
        let lowercased = string.lowercased()
        switch lowercased {
        case "none": return .none
        case "auto": return .auto
        case "stretch": return .stretch
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        default: return .auto // Default to auto if not recognized
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Encode using the rawValue (e.g. "Auto")
        try container.encode(self.rawValue)
    }
}

// MARK: - ImageStyle

public enum SwiftImageStyle: String, Codable {
    case defaultImageStyle = "default"
    case person = "person"
    case roundedCorners = "roundedCorners"
}

public extension SwiftImageStyle {
    static func toString(_ value: SwiftImageStyle) -> String {
        switch value {
        case .defaultImageStyle: return "default"
        case .person: return "person"
        case .roundedCorners: return "roundedCorners"
        }
    }
    static func fromString(_ s: String) -> SwiftImageStyle? {
        switch s.lowercased() {
        case "default": return .defaultImageStyle
        case "person": return .person
        case "roundedcorners": return .roundedCorners
        default: return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let value = SwiftImageStyle.fromString(raw) {
            self = value
        } else {
            self = .defaultImageStyle
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - TextInputStyle

public enum SwiftTextInputStyle: String, Codable {
    case text = "Text"
    case tel = "Tel"
    case url = "Url"
    case email = "Email"
    case password = "Password"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "password":
            self = .password
        case "tel":
            self = .tel
        case "url":
            self = .url
        case "email":
            self = .email
        default:
            self = .text
        }
    }
}

public extension SwiftTextInputStyle {
    static func toString(_ value: SwiftTextInputStyle) -> String {
        return value.rawValue // Now we can just use rawValue since it matches C++
    }
    
    static func fromString(_ s: String) -> SwiftTextInputStyle? {
        switch s {
        case "Text": return .text
        case "Tel": return .tel
        case "Url": return .url
        case "Email": return .email
        case "Password": return .password
        default: return nil
        }
    }
}

// MARK: - ActionType

public enum SwiftActionType: String, Codable {
    case unsupported = "Unsupported"
    case execute = "Action.Execute"
    case openUrl = "Action.OpenUrl"
    case showCard = "Action.ShowCard"
    case submit = "Action.Submit"
    case toggleVisibility = "Action.ToggleVisibility"
    case custom = "Custom"
    case unknownAction = "UnknownAction"
    case overflow = "Overflow"
    
    // Mirror the C++ approach, but local to this enum.
    public static func toString(_ value: SwiftActionType) -> String {
        // If missing, fallback to rawValue
        switch value {
        case .unsupported: return "Unsupported"
        case .execute: return "Action.Execute"
        case .openUrl: return "Action.OpenUrl"  // special
        case .showCard: return "Action.ShowCard"
        case .submit: return "Action.Submit"
        case .toggleVisibility: return "Action.ToggleVisibility"
        case .custom: return "Custom"
        case .unknownAction: return "UnknownAction"
        case .overflow: return "Overflow"
        }
    }

    public static func fromString(_ s: String) -> SwiftActionType? {
        // case-insensitive
        let lowered = s.lowercased()
        switch lowered {
        case "unsupported": return .unsupported
        case "action.execute": return .execute
        case "action.openurl": return .openUrl
        case "action.showcard": return .showCard
        case "action.submit": return .submit
        case "action.togglevisibility": return .toggleVisibility
        case "custom": return .custom
        case "unknownaction": return .unknownAction
        case "overflow": return .overflow
        default: return nil
        }
    }
}

// MARK: - ActionAlignment

public enum SwiftActionAlignment: String, Codable {
    case left, center, right, stretch
    
    // Add custom decoder for case-insensitive parsing
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Use caseInsensitiveValue for consistent handling
        self = SwiftActionAlignment.caseInsensitiveValue(from: raw)
    }
}

public extension SwiftActionAlignment {
    static func toString(_ value: SwiftActionAlignment) -> String {
        switch value {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        case .stretch: return "Stretch"
        }
    }
    static func fromString(_ s: String) -> SwiftActionAlignment? {
        switch s {
        case "Left": return .left
        case "Center": return .center
        case "Right": return .right
        case "Stretch": return .stretch
        default: return nil
        }
    }
    
    // Create a caseInsensitiveValue function to use in our decoder
    static func caseInsensitiveValue(from string: String) -> SwiftActionAlignment {
        let lowercased = string.lowercased()
        switch lowercased {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "stretch": return .stretch
        default: return .center // Default to center if not recognized
        }
    }
}

// MARK: - ActionMode (the test references .popup)

public enum SwiftActionMode: String, Codable {
    case inline = "Inline"
    case popup = "Popup"
}

public extension SwiftActionMode {
    static func toString(_ value: SwiftActionMode) -> String {
        switch value {
        case .inline: return "Inline"
        case .popup: return "Popup"
        }
    }
    static func fromString(_ s: String) -> SwiftActionMode? {
        switch s {
        case "Inline": return .inline
        case "Popup": return .popup
        default: return nil
        }
    }
}

// MARK: - ActionsOrientation

public enum SwiftActionsOrientation: String, Codable {
    case vertical, horizontal
}

public extension SwiftActionsOrientation {
    static func toString(_ value: SwiftActionsOrientation) -> String {
        switch value {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        }
    }
    static func fromString(_ s: String) -> SwiftActionsOrientation? {
        switch s {
        case "Vertical": return .vertical
        case "Horizontal": return .horizontal
        default: return nil
        }
    }
}

public enum SwiftChoiceSetStyle: String, Codable {
    case compact = "Compact"
    case expanded = "Expanded"
    case filtered = "Filtered"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Use case-insensitive comparison
        switch raw.lowercased() {
        case "compact": self = .compact
        case "expanded": self = .expanded
        case "filtered": self = .filtered
        default:
            // Default to compact as before
            self = .compact
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Use the rawValue which will preserve our defined casing
        try container.encode(self.rawValue)
    }
}

public extension SwiftChoiceSetStyle {
    static func toString(_ value: SwiftChoiceSetStyle) -> String {
        switch value {
        case .compact: return "Compact"
        case .expanded: return "Expanded"
        case .filtered: return "Filtered"
        }
    }
    static func fromString(_ s: String) -> SwiftChoiceSetStyle? {
        switch s {
        case "Compact": return .compact
        case "Expanded": return .expanded
        case "Filtered": return .filtered
        default: return nil
        }
    }
}

// MARK: - ContainerStyle

public enum SwiftContainerStyle: String, Codable {
    case none = "None"
    case `default` = "Default"
    case emphasis = "Emphasis"
    case good = "Good"
    case attention = "Attention"
    case warning = "Warning"
    case accent = "Accent"
    
    // Add explicit encode method
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue) // Always use the raw value with proper capitalization
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SwiftContainerStyle.caseInsensitiveValue(from: raw)
    }
}

public extension SwiftContainerStyle {
    static func toString(_ value: SwiftContainerStyle) -> String {
        return value.rawValue  // Always return the properly capitalized raw value
    }
    
    static func fromString(_ s: String) -> SwiftContainerStyle? {
        switch s {
        case "None": return .none
        case "Default": return .default
        case "Emphasis": return .emphasis
        case "Good": return .good
        case "Attention": return .attention
        case "Warning": return .warning
        case "Accent": return .accent
        default: return nil
        }
    }
    
    // Create a caseInsensitiveValue function for consistent parser handling
    static func caseInsensitiveValue(from string: String) -> SwiftContainerStyle {
        let lowercased = string.lowercased()
        switch lowercased {
        case "none": return .none
        case "default": return .default
        case "emphasis": return .emphasis
        case "good": return .good
        case "attention": return .attention
        case "warning": return .warning
        case "accent": return .accent
        default: return .default // Default to .default if not recognized
        }
    }
}

// MARK: - Spacing

public enum SwiftSpacing: String, Codable {
    case `default`, none, small, medium, large, extraLarge, padding
}

public extension SwiftSpacing {
    static func toString(_ value: SwiftSpacing) -> String {
        switch value {
        case .default: return "default"
        case .none: return "none"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .extraLarge: return "extraLarge"
        case .padding: return "padding"
        }
    }
    static func fromString(_ s: String) -> SwiftSpacing? {
        switch s.lowercased() {
        case "default": return .default
        case "none": return SwiftSpacing.none
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "extralarge", "extra large": return .extraLarge
        case "padding": return .padding
        default: return nil
        }
    }
}

// MARK: - SeparatorThickness (the test references .thick)

public enum SwiftSeparatorThickness: String, Codable {
    case defaultThickness = "default"
    case thick = "thick"
}

public extension SwiftSeparatorThickness {
    static func toString(_ value: SwiftSeparatorThickness) -> String {
        switch value {
        case .defaultThickness: return "default"
        case .thick: return "thick"
        }
    }
    static func fromString(_ s: String) -> SwiftSeparatorThickness? {
        switch s.lowercased() {
        case "default": return .defaultThickness
        case "thick": return .thick
        default: return nil
        }
    }
}

// MARK: - HeightType (the test references .auto)

public enum SwiftHeightType: String, Codable {
    case auto = "auto"
    case stretch = "stretch"
}

public extension SwiftHeightType {
    static func toString(_ value: SwiftHeightType) -> String {
        switch value {
        case .auto: return "Auto"
        case .stretch: return "Stretch"
        }
    }
    static func fromString(_ s: String) -> SwiftHeightType? {
        switch s {
        case "Auto": return .auto
        case "Stretch": return .stretch
        default: return nil
        }
    }
}

// MARK: - IconPlacement (the test references .leftOfTitle)

public enum SwiftIconPlacement: String, Codable {
    case leftOfTitle = "LeftOfTitle"
    case aboveTitle = "AboveTitle"
}

public extension SwiftIconPlacement {
    static func toString(_ value: SwiftIconPlacement) -> String {
        switch value {
        case .leftOfTitle: return "LeftOfTitle"
        case .aboveTitle: return "AboveTitle"
        }
    }
    static func fromString(_ s: String) -> SwiftIconPlacement? {
        switch s {
        case "LeftOfTitle": return .leftOfTitle
        case "AboveTitle": return .aboveTitle
        default: return nil
        }
    }
}

// Case-insensitive string equality comparator
struct SwiftCaseInsensitiveEqualTo {
    func isEqual<T: StringProtocol>(_ lhs: T, _ rhs: T) -> Bool {
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

// Case-insensitive hash generator
struct SwiftCaseInsensitiveHash {
    func hash<T: StringProtocol>(_ keyval: T) -> Int {
        return keyval.lowercased().hashValue
    }
}

// Hash function for enums
struct SwiftEnumHash<T: Hashable> {
    func hash(_ value: T) -> Int {
        return value.hashValue
    }
}

// Enum mapping class for bidirectional enum <-> string conversion
public struct SwiftEnumMapping<T: Hashable & Codable>: Codable {
    private let enumToString: [T: String]
    private let stringToEnum: [String: T]

    init(_ mappings: [(T, String)]) {
        var eToS = [T: String]()
        var sToE = [String: T]()
        for (enumValue, stringValue) in mappings {
            eToS[enumValue] = stringValue
            sToE[stringValue.lowercased()] = enumValue
        }
        self.enumToString = eToS
        self.stringToEnum = sToE
    }

    func toString(_ value: T) -> String {
        return enumToString[value] ?? "unknown"
    }

    func fromString(_ value: String) throws -> T {
        guard let enumValue = stringToEnum[value.lowercased()] else {
            throw SwiftEnumMappingError.invalidValue(value)
        }
        return enumValue
    }
}

// Error handling for invalid enum values
public enum SwiftEnumMappingError: Error {
    case invalidValue(String)
}

// Protocol to allow enums to use the mapping
public protocol SwiftAdaptiveCardEnum: Codable, Hashable {
    static var mappings: SwiftEnumMapping<Self> { get }
}

public extension SwiftAdaptiveCardEnum {
    func toString() -> String {
        return Self.mappings.toString(self)
    }
    static func fromString(_ value: String) throws -> Self {
        return try Self.mappings.fromString(value)
    }
}

// Define `AdaptiveCardSchemaKey` using EnumMapping
public enum SwiftAdaptiveCardSchemaKey: String, SwiftAdaptiveCardEnum {
    case accent, action, actionAlignment, actionMode, actionRole, actionSet, actionSetConfig
    case actions, actionsOrientation, adaptiveCard, allowCustomStyle, allowInlinePlayback
    case backgroundColor, backgroundImage, backgroundImageUrl, baseCardElement, baseContainerStyle
    case bleed, body, bolder, borderColor, bottom, badge, buttonSpacing, buttons, captionSources
    case card, cellSpacing, cells, center, choiceSet, choices, choicesData, choicesDataType, color
    case colorConfig, column, columnHeader, columnSet, columns, container, containerStyles, dark, data
    case dataQuery, dataset, dateInput, defaultCase, defaultPoster, description, elementId, emphasis
    case errorMessage, extraLarge, factSet, facts, fallback, fallbackText, fontFamily, fontSizes, fontType
    case fontWeights, foregroundColor, foregroundColors, good, gridStyle, heading, headingLevel
    case height, highlight, highlightColor, highlightColors, horizontalAlignment, hostWidthBreakpoints
    case iconPlacement, iconSize, iconUrl, id, image, imageBaseUrl, imageSet, imageSize, imageSizes
    case images, inlineAction, inlineTopMargin, inlines, inputSpacing, inputs, isEnabled, isMultiSelect
    case isMultiline, showBorder, roundedCorners, isRequired, isSelected, isSubtle, isVisible, italic
    case items, label, language, attention, large, left, light, lighter, lineColor, lineThickness, max, maxActions
    case maxImageHeight, maxLength, maxLines, maxWidth, media, medium, metaData, method, mimeType, min
    case minHeight, mode, monospace, narrow, numberInput, ratingInput, ratingLabel, padding, placeholder
    case playButton, poster, providerId, refresh, regex, repeatHorizontally, repeatVertically
    case requiredInputs, requires, richTextBlock, right, rows, rtl, selectAction, separator
    case showActionMode, showCard, showCardActionConfig, showGridLines, size, small, sources, spacing
    case speak, standard, stretch, strikethrough, style, subtle, suffix, supportsInteractivity
    case table, tableCell, tableRow, targetElements, layout, itemFit, rowSpacing, columnSpacing
    case itemWidth, minItemWidth, maxItemWidth, horizontalItemsAlignment, row, rowSpan, columnSpan
    case areaGridName, areas, layouts, targetInputIds, targetWidth, text, textBlock, textConfig
    case textInput, textStyles, marigoldColor, neutralColor, filledStar, emptyStar, ratingTextColor
    case countTextColor, textWeight, thickness, timeInput, title, toggleInput, tooltip, top, type
    case underline, uri, url, userIds, value, valueChangedAction, valueChangedActionType, valueOff
    case valueOn, verb, veryNarrow, version, verticalAlignment, verticalCellContentAlignment
    case verticalContentAlignment, warning, webUrl, weight, width, wrap, compoundButton, authentication
    case associatedInputs
    case conditionallyEnabled
    case altText
    case name
    case borderWidth
    case fallbackContent
    case fallbackType
    case cornerRadius
    case connectionName
    case count
    case fillMode
    case firstRowAsHeaders
    case fontTypes
    case horizontalCellContentAlignment
    case icon
    case optionalInputs
    case schema = "$schema"
    case spacingDefinition
    case tokenExchangeResource

    public static let mappings = SwiftEnumMapping([
        (SwiftAdaptiveCardSchemaKey.accent, "accent"),
        (SwiftAdaptiveCardSchemaKey.action, "action"),
        (SwiftAdaptiveCardSchemaKey.actionAlignment, "actionAlignment"),
        (SwiftAdaptiveCardSchemaKey.actionMode, "actionMode"),
        (SwiftAdaptiveCardSchemaKey.actionRole, "role"),
        (SwiftAdaptiveCardSchemaKey.actionSet, "ActionSet"),
        (SwiftAdaptiveCardSchemaKey.actionSetConfig, "actionSetConfig"),
        (SwiftAdaptiveCardSchemaKey.actions, "actions"),
        (SwiftAdaptiveCardSchemaKey.actionsOrientation, "actionsOrientation"),
        (SwiftAdaptiveCardSchemaKey.adaptiveCard, "adaptiveCard"),
        (SwiftAdaptiveCardSchemaKey.allowCustomStyle, "allowCustomStyle"),
        (SwiftAdaptiveCardSchemaKey.allowInlinePlayback, "allowInlinePlayback"),
        (SwiftAdaptiveCardSchemaKey.backgroundColor, "backgroundColor"),
        (SwiftAdaptiveCardSchemaKey.backgroundImage, "backgroundImage"),
        (SwiftAdaptiveCardSchemaKey.backgroundImageUrl, "backgroundImageUrl"),
        (SwiftAdaptiveCardSchemaKey.baseCardElement, "baseCardElement"),
        (SwiftAdaptiveCardSchemaKey.baseContainerStyle, "baseContainerStyle"),
        (SwiftAdaptiveCardSchemaKey.badge, "badge"),
        (SwiftAdaptiveCardSchemaKey.bleed, "bleed"),
        (SwiftAdaptiveCardSchemaKey.body, "body"),
        (SwiftAdaptiveCardSchemaKey.bolder, "bolder"),
        (SwiftAdaptiveCardSchemaKey.borderColor, "borderColor"),
        (SwiftAdaptiveCardSchemaKey.bottom, "bottom"),
        (SwiftAdaptiveCardSchemaKey.buttonSpacing, "buttonSpacing"),
        (SwiftAdaptiveCardSchemaKey.buttons, "buttons"),
        (SwiftAdaptiveCardSchemaKey.captionSources, "captionSources"),
        (SwiftAdaptiveCardSchemaKey.card, "card"),
        (SwiftAdaptiveCardSchemaKey.cellSpacing, "cellSpacing"),
        (SwiftAdaptiveCardSchemaKey.cells, "cells"),
        (SwiftAdaptiveCardSchemaKey.center, "center"),
        (SwiftAdaptiveCardSchemaKey.choiceSet, "choiceSet"),
        (SwiftAdaptiveCardSchemaKey.choices, "choices"),
        (SwiftAdaptiveCardSchemaKey.choicesData, "choices.data"),
        (SwiftAdaptiveCardSchemaKey.choicesDataType, "type"),
        (SwiftAdaptiveCardSchemaKey.color, "color"),
        (SwiftAdaptiveCardSchemaKey.colorConfig, "colorConfig"),
        (SwiftAdaptiveCardSchemaKey.column, "column"),
        (SwiftAdaptiveCardSchemaKey.columnHeader, "columnHeader"),
        (SwiftAdaptiveCardSchemaKey.columnSet, "columnSet"),
        (SwiftAdaptiveCardSchemaKey.columns, "columns"),
        (SwiftAdaptiveCardSchemaKey.container, "container"),
        (SwiftAdaptiveCardSchemaKey.containerStyles, "containerStyles"),
        (SwiftAdaptiveCardSchemaKey.dark, "dark"),
        (SwiftAdaptiveCardSchemaKey.data, "data"),
        (SwiftAdaptiveCardSchemaKey.dataQuery, "Data.Query"),
        (SwiftAdaptiveCardSchemaKey.dataset, "dataset"),
        (SwiftAdaptiveCardSchemaKey.dateInput, "dateInput"),
        (SwiftAdaptiveCardSchemaKey.defaultCase, "default"),
        (SwiftAdaptiveCardSchemaKey.defaultPoster, "defaultPoster"),
        (SwiftAdaptiveCardSchemaKey.description, "description"),
        (SwiftAdaptiveCardSchemaKey.elementId, "elementId"),
        (SwiftAdaptiveCardSchemaKey.emphasis, "emphasis"),
        (SwiftAdaptiveCardSchemaKey.errorMessage, "errorMessage"),
        (SwiftAdaptiveCardSchemaKey.extraLarge, "extraLarge"),
        (SwiftAdaptiveCardSchemaKey.factSet, "factSet"),
        (SwiftAdaptiveCardSchemaKey.facts, "facts"),
        (SwiftAdaptiveCardSchemaKey.fallback, "fallback"),
        (SwiftAdaptiveCardSchemaKey.fallbackText, "fallbackText"),
        (SwiftAdaptiveCardSchemaKey.fontFamily, "fontFamily"),
        (SwiftAdaptiveCardSchemaKey.fontSizes, "fontSizes"),
        (SwiftAdaptiveCardSchemaKey.fontType, "fontType"),
        (SwiftAdaptiveCardSchemaKey.fontWeights, "fontWeights"),
        (SwiftAdaptiveCardSchemaKey.foregroundColor, "foregroundColor"),
        (SwiftAdaptiveCardSchemaKey.foregroundColors, "foregroundColors"),
        (SwiftAdaptiveCardSchemaKey.good, "good"),
        (SwiftAdaptiveCardSchemaKey.gridStyle, "gridStyle"),
        (SwiftAdaptiveCardSchemaKey.heading, "heading"),
        (SwiftAdaptiveCardSchemaKey.headingLevel, "headingLevel"),
        (SwiftAdaptiveCardSchemaKey.height, "height"),
        (SwiftAdaptiveCardSchemaKey.highlight, "highlight"),
        (SwiftAdaptiveCardSchemaKey.highlightColor, "highlightColor"),
        (SwiftAdaptiveCardSchemaKey.highlightColors, "highlightColors"),
        (SwiftAdaptiveCardSchemaKey.horizontalAlignment, "horizontalAlignment"),
        (SwiftAdaptiveCardSchemaKey.hostWidthBreakpoints, "hostWidthBreakpoints"),
        (SwiftAdaptiveCardSchemaKey.associatedInputs, "associatedInputs"),
        (SwiftAdaptiveCardSchemaKey.conditionallyEnabled, "conditionallyEnabled"),
        (SwiftAdaptiveCardSchemaKey.altText, "altText"),
        (SwiftAdaptiveCardSchemaKey.name, "name"),
        (SwiftAdaptiveCardSchemaKey.borderWidth, "borderWidth"),
        (SwiftAdaptiveCardSchemaKey.cornerRadius, "cornerRadius"),
        (SwiftAdaptiveCardSchemaKey.connectionName, "connectionName"),
        (SwiftAdaptiveCardSchemaKey.count, "count"),
        (SwiftAdaptiveCardSchemaKey.fillMode, "fillMode"),
        (SwiftAdaptiveCardSchemaKey.firstRowAsHeaders, "firstRowAsHeaders"),
        (SwiftAdaptiveCardSchemaKey.fontTypes, "fontTypes"),
        (SwiftAdaptiveCardSchemaKey.horizontalCellContentAlignment, "horizontalCellContentAlignment"),
        (SwiftAdaptiveCardSchemaKey.icon, "icon"),
        (SwiftAdaptiveCardSchemaKey.optionalInputs, "optionalInputs"),
        (SwiftAdaptiveCardSchemaKey.schema, "$schema"),
        (SwiftAdaptiveCardSchemaKey.spacingDefinition, "spacingDefinition"),
        (SwiftAdaptiveCardSchemaKey.tokenExchangeResource, "tokenExchangeResource"),
        (SwiftAdaptiveCardSchemaKey.language, "lang"), // Currently maps to "language"
        (SwiftAdaptiveCardSchemaKey.attention, "attention"),
        (SwiftAdaptiveCardSchemaKey.iconUrl, "iconUrl"),
        (SwiftAdaptiveCardSchemaKey.value, "value"),
        (SwiftAdaptiveCardSchemaKey.valueChangedAction, "valueChangedAction"),
        (SwiftAdaptiveCardSchemaKey.valueChangedActionType, "valueChangedActionType"),
        (SwiftAdaptiveCardSchemaKey.valueOff, "valueOff"),
        (SwiftAdaptiveCardSchemaKey.valueOn, "valueOn"),
        (SwiftAdaptiveCardSchemaKey.verb, "verb"),
        (SwiftAdaptiveCardSchemaKey.version, "version"),
        (SwiftAdaptiveCardSchemaKey.webUrl, "webUrl"),
        (SwiftAdaptiveCardSchemaKey.width, "width"),
        (SwiftAdaptiveCardSchemaKey.wrap, "wrap"),
        (SwiftAdaptiveCardSchemaKey.tooltip, "tooltip"),
        (SwiftAdaptiveCardSchemaKey.method, "method"),
        (SwiftAdaptiveCardSchemaKey.text, "text"),
        (SwiftAdaptiveCardSchemaKey.standard, "standard"),
        (SwiftAdaptiveCardSchemaKey.compoundButton, "compoundButton"),
    ])
}

public extension SwiftAdaptiveCardSchemaKey {
    static func fromString(_ s: String) -> SwiftAdaptiveCardSchemaKey? {
        return try? mappings.fromString(s)
    }

    static func toString(_ value: SwiftAdaptiveCardSchemaKey) -> String {
        return mappings.toString(value)
    }
}

/// The role of an action – originally defined in C++.
public enum SwiftActionRole: String, Codable {
    case button = "Button"
    case link = "Link"
    case tab = "Tab"
    case menu = "Menu"
    case menuItem = "MenuItem"
}

public enum SwiftAssociatedInputs: String, Codable {
    case auto = "Auto"
    case none = "None"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Capitalize so "none" becomes "None"
        let normalized = raw.capitalized
        if let value = SwiftAssociatedInputs(rawValue: normalized) {
            self = value
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                                                    debugDescription: "Cannot initialize AssociatedInputs from invalid String value \(raw)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

public enum SwiftImageFillMode: String, Codable {
    case cover = "cover"
    case repeatHorizontally = "repeatHorizontally"
    case repeatVertically = "repeatVertically"
    case `repeat` = "repeat"
}

public enum SwiftIconSize: String, Codable {
    case xxSmall = "xxSmall"
    case xSmall = "xSmall"
    case small = "Small"
    case standard = "Standard"
    case medium = "Medium"
    case large = "Large"
    case xLarge = "xLarge"
    case xxLarge = "xxLarge"
}

public enum SwiftIconStyle: String, Codable {
    case regular = "Regular"
    case filled = "Filled"
}

public enum SwiftLayoutContainerType: String, Codable {
    case none = "Layout.None"
    case stack = "Layout.Stack"
    case flow = "Layout.Flow"
    case areaGrid = "Layout.AreaGrid"
}

/// Minimal stubs for text-related enums.
public enum SwiftTextStyle: String, Codable {
    case defaultStyle = "default"
    case heading = "heading"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        
        switch raw.lowercased() {
        case "default":
            self = .defaultStyle
        case "heading":
            self = .heading
        default:
            // For invalid values, fall back to .defaultStyle
            self = .defaultStyle
        }
    }
}

enum SwiftValueChangedActionType: String, Codable {
    case resetInputs = "ResetInputs"
}

public enum SwiftInlineElementType: String, Codable {
    case textRun = "TextRun"
}

enum SwiftRatingSize: String, Codable {
    case medium = "medium"
    case large = "large"
}

enum SwiftRatingColor: String, Codable {
    case neutral = "neutral"
    case marigold = "marigold"
}

enum SwiftRatingStyle: String, Codable {
    case `default` = "default"
    case compact = "compact"
}

enum SwiftItemFit: String, Codable {
    case fit = "Fit"
    case fill = "Fill"
}

public struct SwiftContainerBleedDirection: OptionSet, Codable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let bleedRestricted    = SwiftContainerBleedDirection([])
    public static let bleedLeft          = SwiftContainerBleedDirection(rawValue: 0x0001)
    public static let bleedRight         = SwiftContainerBleedDirection(rawValue: 0x0010)
    public static let bleedUp            = SwiftContainerBleedDirection(rawValue: 0x0100)
    public static let bleedDown          = SwiftContainerBleedDirection(rawValue: 0x1000)
    
    // Composite directions
    public static let bleedLeftRight: SwiftContainerBleedDirection     = [.bleedLeft, .bleedRight]
    public static let bleedLeftUp: SwiftContainerBleedDirection        = [.bleedLeft, .bleedUp]
    public static let bleedRightUp: SwiftContainerBleedDirection       = [.bleedRight, .bleedUp]
    public static let bleedLeftRightUp: SwiftContainerBleedDirection   = [.bleedLeft, .bleedRight, .bleedUp]
    public static let bleedLeftDown: SwiftContainerBleedDirection      = [.bleedLeft, .bleedDown]
    public static let bleedRightDown: SwiftContainerBleedDirection     = [.bleedRight, .bleedDown]
    public static let bleedLeftRightDown: SwiftContainerBleedDirection = [.bleedLeft, .bleedRight, .bleedDown]
    static let bleedUpDown: SwiftContainerBleedDirection        = [.bleedUp, .bleedDown]
    static let bleedLeftUpDown: SwiftContainerBleedDirection    = [.bleedLeft, .bleedUp, .bleedDown]
    static let bleedRightUpDown: SwiftContainerBleedDirection   = [.bleedRight, .bleedUp, .bleedDown]
    static let bleedAll: SwiftContainerBleedDirection           = [.bleedLeft, .bleedRight, .bleedUp, .bleedDown]
}

extension RawRepresentable where Self: Codable, RawValue == String {
    static func toString(_ value: Self) -> String {
        return value.rawValue
    }
    
    static func fromString(_ s: String) -> Self? {
        return Self(rawValue: s) ?? Self(rawValue: s.capitalized) ?? Self(rawValue: s.lowercased())
    }
}

// Error type for parsing failures.
enum ParsingError: Error {
    case invalidType(expected: String, found: String)
}

/// Represents a remote resource with a URL and MIME type.
struct SwiftRemoteResourceInformation: Codable {
    var url: String
    var mimeType: String
}

/// Custom type to handle any JSON value (for additionalProperties)
public struct SwiftAnyCodable: Codable {
    public let value: Any

    init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([SwiftAnyCodable].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: SwiftAnyCodable].self) {
            value = dictValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON format")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [SwiftAnyCodable] {
            try container.encode(arrayValue)
        } else if let dictValue = value as? [String: SwiftAnyCodable] {
            try container.encode(dictValue)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Invalid JSON format"))
        }
    }
}

/// A dynamic coding key that can represent any key.
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { return nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = "\(intValue)" }
}

extension SwiftBaseElement.CodingKeys: CaseIterable {
    public static var allCases: [SwiftBaseElement.CodingKeys] {
        return [.typeString, .id, .internalId, .additionalProperties, .requires, .fallbackType, .fallbackContent, .canFallbackToAncestor, .fallback]
    }
}

/// Represents a semantic version with major, minor, build, and revision components.
public struct SwiftSemanticVersion: Codable, Comparable, CustomStringConvertible {
    public let major: UInt
    public let minor: UInt
    public let build: UInt
    public let revision: UInt

    /// Initializes a `SemanticVersion` from a version string.
    /// - Throws: `SemanticVersionError.invalidVersion` if the version format is incorrect.
    public init(_ version: String) throws {
        let pattern = #"^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\.(\d+))?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsVersion = version as NSString
        let matches = regex.matches(in: version, range: NSRange(location: 0, length: nsVersion.length))

        guard let match = matches.first else {
            throw SemanticVersionError.invalidVersion(version)
        }

        // Helper function to extract and convert each captured group.
        func extract(_ index: Int) throws -> UInt {
            // If the group didn't match, return 0.
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: version) else {
                return 0
            }
            let substring = String(version[range])
            // Try to convert the captured substring to UInt.
            guard let value = UInt(substring) else {
                throw SemanticVersionError.invalidVersion(version)
            }
            return value
        }

        self.major = try extract(1)
        self.minor = try extract(2)
        self.build = try extract(3)
        self.revision = try extract(4)
    }

    public var description: String {
        return "\(major).\(minor).\(build).\(revision)"
    }

    // MARK: - Comparable Implementation
    public static func == (lhs: SwiftSemanticVersion, rhs: SwiftSemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.build == rhs.build &&
               lhs.revision == rhs.revision
    }

    public static func < (lhs: SwiftSemanticVersion, rhs: SwiftSemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.build != rhs.build { return lhs.build < rhs.build }
        return lhs.revision < rhs.revision
    }

    public static func > (lhs: SwiftSemanticVersion, rhs: SwiftSemanticVersion) -> Bool {
        return rhs < lhs
    }

    public static func <= (lhs: SwiftSemanticVersion, rhs: SwiftSemanticVersion) -> Bool {
        return !(lhs > rhs)
    }

    public static func >= (lhs: SwiftSemanticVersion, rhs: SwiftSemanticVersion) -> Bool {
        return !(lhs < rhs)
    }
    
    public func serializeToJsonValue() -> String {
        return description
    }
}

/// Error cases for `SemanticVersion` parsing.
enum SemanticVersionError: Error {
    case invalidVersion(String)
}
