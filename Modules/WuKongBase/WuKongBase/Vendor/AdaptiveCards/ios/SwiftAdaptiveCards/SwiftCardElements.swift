//
//  SwiftCardElements.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

// MARK: - TextBlock Implementation

/// Represents a TextBlock element in an Adaptive Card.
public class SwiftTextBlock: SwiftBaseCardElement {
    // MARK: - Properties
    
    public var text: String
    public let textStyle: SwiftTextStyle?
    public let textSize: SwiftTextSize?
    public let textWeight: SwiftTextWeight?
    public var fontType: SwiftFontType?
    public let textColor: SwiftForegroundColor?
    public let isSubtle: Bool?
    public let wrap: Bool
    public let maxLines: UInt
    public let horizontalAlignment: SwiftHorizontalAlignment?
    public let language: String?

    // MARK: - Initializers
    
    /// Designated initializer.
    public init(
        text: String = "",
        textStyle: SwiftTextStyle? = .defaultStyle,
        textSize: SwiftTextSize? = nil,
        textWeight: SwiftTextWeight? = nil,
        fontType: SwiftFontType? = nil,
        textColor: SwiftForegroundColor? = nil,
        isSubtle: Bool? = nil,
        wrap: Bool = false,
        maxLines: UInt = 0,
        horizontalAlignment: SwiftHorizontalAlignment? = nil,
        language: String? = "en",
        id: String? = nil
    ) {
        self.text = SwiftTextBlock.decodeHTMLEntities(text)
        self.textStyle = textStyle
        self.textSize = textSize
        self.textWeight = textWeight
        self.fontType = fontType
        self.textColor = textColor
        self.isSubtle = isSubtle
        self.wrap = wrap
        self.maxLines = maxLines
        self.horizontalAlignment = horizontalAlignment
        self.language = language
        super.init(type: .textBlock, id: id ?? "") // Convert nil to empty string here
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case text = "text"
        case textStyle = "style"
        case textSize = "size"
        case textWeight = "weight"
        case fontType = "fontType"
        case textColor = "color"
        case isSubtle = "isSubtle"
        case wrap = "wrap"
        case maxLines = "maxLines"
        case horizontalAlignment = "horizontalAlignment"
        case language = "language"
    }
    
    /// Required initializer for decoding.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        let rawText = try container.decode(String.self, forKey: .text)
        text = SwiftTextBlock.decodeHTMLEntities(rawText)
        
        // Handle text style with custom decoding logic
        if let styleStr = try? container.decodeIfPresent(String.self, forKey: .textStyle) {
            switch styleStr.lowercased() {
            case "heading":
                textStyle = .heading
            case "default":
                textStyle = .defaultStyle
            default:
                textStyle = nil
            }
        } else {
            textStyle = nil
        }
        
        // Decode remaining properties
        textSize = try container.decodeIfPresent(SwiftTextSize.self, forKey: .textSize)
        textWeight = try container.decodeIfPresent(SwiftTextWeight.self, forKey: .textWeight)
        fontType = try container.decodeIfPresent(SwiftFontType.self, forKey: .fontType)
        textColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .textColor)
        isSubtle = try container.decodeIfPresent(Bool.self, forKey: .isSubtle)
        wrap = try container.decodeIfPresent(Bool.self, forKey: .wrap) ?? false
        maxLines = try container.decodeIfPresent(UInt.self, forKey: .maxLines) ?? 0
        
        // Custom decoding for horizontalAlignment to handle case variations
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment) {
            horizontalAlignment = SwiftHorizontalAlignment.caseInsensitiveValue(from: alignmentString)
        } else {
            horizontalAlignment = nil
        }
        
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"
        
        // Decode the base class properties
        try super.init(from: decoder)
        
        // Remove known properties from additionalProperties
        cleanupAdditionalProperties()
    }

    /// Encodes the TextBlock to JSON.
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(textStyle, forKey: .textStyle)
        try container.encodeIfPresent(textSize, forKey: .textSize)
        try container.encodeIfPresent(textWeight, forKey: .textWeight)
        try container.encodeIfPresent(fontType, forKey: .fontType)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(isSubtle, forKey: .isSubtle)
        try container.encode(wrap, forKey: .wrap)
        try container.encode(maxLines, forKey: .maxLines)
        try container.encodeIfPresent(horizontalAlignment, forKey: .horizontalAlignment)
        try container.encodeIfPresent(language, forKey: .language)
    }
    
    // MARK: - Serialization to JSON
    
    /// Converts this TextBlock into a JSON dictionary.
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
    
    // MARK: - Helper Methods
    
    /// Returns a DateTimePreparser initialized with the current text.
    public func getTextForDateParsing() -> SwiftDateTimePreparser {
        return SwiftDateTimePreparser(input: self.text)
    }
    
    /// Cleanup additional properties after deserialization
    private func cleanupAdditionalProperties() {
        if var additional = self.additionalProperties {
            additional.removeValue(forKey: "type")
            additional.removeValue(forKey: "text")
            additional.removeValue(forKey: "style")
            additional.removeValue(forKey: "size")
            additional.removeValue(forKey: "weight")
            additional.removeValue(forKey: "fontType")
            additional.removeValue(forKey: "color")
            additional.removeValue(forKey: "isSubtle")
            additional.removeValue(forKey: "wrap")
            additional.removeValue(forKey: "maxLines")
            additional.removeValue(forKey: "horizontalAlignment")
            additional.removeValue(forKey: "lang")
            self.additionalProperties = additional
        }

        // Force empty string for id if nil
        if self.id == nil {
            self.id = ""
        }
    }
}

/// Represents a rich text block with inline elements.
public class SwiftRichTextBlock: SwiftBaseCardElement {
    // MARK: - Properties
    public let horizontalAlignment: SwiftHorizontalAlignment?
    public let inlines: [Any] // Supports both TextRun and String
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case horizontalAlignment
        case inlines
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode horizontalAlignment
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment) {
            horizontalAlignment = SwiftHorizontalAlignment(rawValue: alignmentString.lowercased())
        } else {
            horizontalAlignment = nil
        }
        
        // Decode inlines array
        var inlinesArray: [Any] = []
        var inlinesContainer = try container.nestedUnkeyedContainer(forKey: .inlines)
        
        while !inlinesContainer.isAtEnd {
            // Try to decode as a dictionary first (for TextRun)
            if let inlineDict = try? inlinesContainer.decode([String: SwiftAnyCodable].self) {
                let dict = inlineDict.mapValues { $0.value }
                if let typeString = dict["type"] as? String, typeString == "TextRun",
                   let textRun = try? SwiftTextRun.deserialize(from: dict) {
                    inlinesArray.append(textRun)
                }
            } else if let stringValue = try? inlinesContainer.decode(String.self) {
                // It's a plain string
                inlinesArray.append(stringValue)
            }
        }
        
        inlines = inlinesArray
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let alignment = horizontalAlignment {
            try container.encode(alignment.rawValue, forKey: .horizontalAlignment)
        }
        
        var inlinesContainer = container.nestedUnkeyedContainer(forKey: .inlines)
        for inline in inlines {
            if let textRun = inline as? SwiftTextRun {
                try inlinesContainer.encode(SwiftAnyCodable(textRun.serializeToJson()))
            } else if let stringValue = inline as? String {
                try inlinesContainer.encode(stringValue)
            }
        }
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Represents an image element in an Adaptive Card.
public class SwiftImage: SwiftBaseCardElement {
    // MARK: - Properties
    public let url: String
    public let backgroundColor: String
    public let imageStyle: SwiftImageStyle
    public let imageSize: SwiftImageSize
    public var pixelWidth: UInt
    public let pixelHeight: UInt
    public let altText: String
    public let hAlignment: SwiftHorizontalAlignment?
    public let selectAction: SwiftBaseActionElement?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case url
        case backgroundColor
        case imageStyle = "style"
        case imageSize = "size"
        case pixelWidth, pixelHeight, altText
        case hAlignment = "horizontalAlignment"
        case selectAction
        case width
        case height
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required properties
        url = try container.decode(String.self, forKey: .url)
        
        // Decode and validate background color
        let rawColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? ""
        var dummyWarnings = [SwiftAdaptiveCardParseWarning]()
        backgroundColor = validateColor(rawColor, warnings: &dummyWarnings)
        
        // Decode style and size
        imageStyle = try container.decodeIfPresent(SwiftImageStyle.self, forKey: .imageStyle) ?? .defaultImageStyle
        imageSize = try container.decodeIfPresent(SwiftImageSize.self, forKey: .imageSize) ?? .none
        
        // Decode altText and hAlignment
        altText = try container.decodeIfPresent(String.self, forKey: .altText) ?? ""
        
        // Custom decoding for hAlignment to handle case variations
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .hAlignment) {
            hAlignment = SwiftHorizontalAlignment.caseInsensitiveValue(from: alignmentString)
        } else {
            hAlignment = nil
        }
        
        // Handle pixel dimensions including string parsing (before super.init)
        var tempPixelWidth = try container.decodeIfPresent(UInt.self, forKey: .pixelWidth) ?? 0
        var tempPixelHeight = try container.decodeIfPresent(UInt.self, forKey: .pixelHeight) ?? 0
        
        // Parse explicit width/height strings
        if let widthString = try? container.decode(String.self, forKey: .width) {
            var warnings = [SwiftAdaptiveCardParseWarning]()
            if let parsedWidth = parseSizeForPixelSize(widthString, warnings: &warnings) {
                tempPixelWidth = parsedWidth
            }
            SwiftWarningCollector.add(warnings)
        }
        
        if let heightString = try? container.decode(String.self, forKey: .height) {
            var warnings = [SwiftAdaptiveCardParseWarning]()
            if let parsedHeight = parseSizeForPixelSize(heightString, warnings: &warnings) {
                tempPixelHeight = parsedHeight
            }
            SwiftWarningCollector.add(warnings)
        }
        
        // Assign to let properties
        pixelWidth = tempPixelWidth
        pixelHeight = tempPixelHeight
        
        // Decode selectAction if present
        if container.contains(.selectAction) {
            let actionDict = try container.decode([String: SwiftAnyCodable].self, forKey: .selectAction)
            let dict = actionDict.mapValues { $0.value }
            selectAction = try SwiftBaseActionElement.deserializeAction(from: dict)
        } else {
            selectAction = nil
        }
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Don't set default values after parsing - let them remain nil if not specified
        // This allows proper serialization to skip default values
        
        self.populateKnownPropertiesSet()
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(imageStyle, forKey: .imageStyle)
        try container.encode(imageSize, forKey: .imageSize)
        try container.encode(pixelWidth, forKey: .pixelWidth)
        try container.encode(pixelHeight, forKey: .pixelHeight)
        try container.encode(altText, forKey: .altText)
        try container.encodeIfPresent(hAlignment, forKey: .hAlignment)
        
        if let action = selectAction {
            try container.encode(SwiftAnyCodable(try SwiftBaseCardElement.serializeSelectAction(action)), forKey: .selectAction)
        }
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    /// Serializes the Image to a JSON dictionary.
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Represents a media element containing sources and optional poster/alt text.
public class SwiftMedia: SwiftBaseCardElement {
    // MARK: - Properties
    public let poster: String?
    public let altText: String?
    public let sources: [SwiftMediaSource]
    public let captionSources: [SwiftCaptionSource]
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case poster, altText, sources, captionSources
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        poster = try container.decodeIfPresent(String.self, forKey: .poster)
        altText = try container.decodeIfPresent(String.self, forKey: .altText)
        sources = try container.decode([SwiftMediaSource].self, forKey: .sources)
        captionSources = try container.decodeIfPresent([SwiftCaptionSource].self, forKey: .captionSources) ?? []
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(poster, forKey: .poster)
        try container.encodeIfPresent(altText, forKey: .altText)
        try container.encode(sources, forKey: .sources)
        try container.encode(captionSources, forKey: .captionSources)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Represents a media source, inheriting properties from `ContentSource`.
public struct SwiftMediaSource: Codable {
    // MARK: - Properties
    public let url: String
    public let mimeType: String?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case url, mimeType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        url = try container.decode(String.self, forKey: .url)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
    }
    
    // MARK: - Initialization with Default Values
    
    // MARK: - Serialization to JSON
    func serializeToJson() -> [String: Any] {
        return SwiftMediaSourceLegacySupport.serializeToJson(self)
    }
    
    // MARK: - Resource Information
    func getResourceInformation() -> [SwiftRemoteResourceInformation] {
        return SwiftMediaSourceLegacySupport.getResourceInformation(self)
    }
}

/// Represents an icon element in an Adaptive Card.
class SwiftIcon: SwiftBaseCardElement {
    // MARK: - Properties
    let name: String?
    let foregroundColor: SwiftForegroundColor
    let iconSize: SwiftIconSize
    let iconStyle: SwiftIconStyle
    let selectAction: SwiftBaseActionElement?
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case name, foregroundColor, iconSize, iconStyle, selectAction
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        name = try container.decodeIfPresent(String.self, forKey: .name)
        foregroundColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .foregroundColor) ?? .default
        iconSize = try container.decodeIfPresent(SwiftIconSize.self, forKey: .iconSize) ?? .standard
        iconStyle = try container.decodeIfPresent(SwiftIconStyle.self, forKey: .iconStyle) ?? .regular
        
        // Decode selectAction if present
        if container.contains(.selectAction) {
            let actionDict = try container.decode([String: SwiftAnyCodable].self, forKey: .selectAction)
            let dict = actionDict.mapValues { $0.value }
            selectAction = try SwiftBaseActionElement.deserializeAction(from: dict)
        } else {
            selectAction = nil
        }
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(foregroundColor, forKey: .foregroundColor)
        try container.encode(iconSize, forKey: .iconSize)
        try container.encode(iconStyle, forKey: .iconStyle)
        
        if let action = selectAction {
            try container.encode(SwiftAnyCodable(try SwiftBaseCardElement.serializeSelectAction(action)), forKey: .selectAction)
        }
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Represents a text run element in an Adaptive Card
public struct SwiftTextRun: Codable, SwiftInline {
    // MARK: - Properties
    public let inlineType: SwiftInlineElementType = .textRun
    
    /// The text content of the text run
    public let text: String
    
    /// Optional text size
    public let textSize: SwiftTextSize?
    
    /// Optional text weight
    public let textWeight: SwiftTextWeight?
    
    /// Optional font type
    public let fontType: SwiftFontType?
    
    /// Optional text color
    public let textColor: SwiftForegroundColor?
    
    /// Optional subtle text flag
    public let isSubtle: Bool?
    
    /// Italic text flag
    public let italic: Bool
    
    /// Strikethrough text flag
    public let strikethrough: Bool
    
    /// Highlight text flag
    public let highlight: Bool
    
    /// Underline text flag
    public let underline: Bool
    
    /// Optional language
    public let language: String?
    
    /// Optional select action
    public let selectAction: SwiftBaseActionElement?
    
    /// Additional properties not explicitly defined
    public var additionalProperties: [String: SwiftAnyCodable] = [:]
    
    // MARK: - Computed Properties
    
    /// Unwrapped additional properties
    var unwrappedAdditionalProperties: [String: Any] {
        return additionalProperties.mapValues { $0.value }
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        case inlineType = "type"
        case text, textSize, textWeight, fontType, textColor,
             isSubtle, italic, strikethrough, highlight,
             underline, language, selectAction
        
        // Add any additional properties not in the predefined keys
        case additionalProperties
    }
    
    // MARK: - Initializers
    
    init(
        text: String,
        textSize: SwiftTextSize? = nil,
        textWeight: SwiftTextWeight? = nil,
        fontType: SwiftFontType? = nil,
        textColor: SwiftForegroundColor? = nil,
        isSubtle: Bool? = nil,
        italic: Bool = false,
        strikethrough: Bool = false,
        highlight: Bool = false,
        underline: Bool = false,
        language: String? = nil, // Default to nil, not "en"
        selectAction: SwiftBaseActionElement? = nil,
        additionalProperties: [String: SwiftAnyCodable] = [:]
    ) {
        self.text = text
        self.textSize = textSize
        self.textWeight = textWeight
        self.fontType = fontType
        self.textColor = textColor
        self.isSubtle = isSubtle
        self.italic = italic
        self.strikethrough = strikethrough
        self.highlight = highlight
        self.underline = underline
        self.language = language // Don't default to "en"
        self.selectAction = selectAction
        self.additionalProperties = additionalProperties
    }
    
    // MARK: - Decoding
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required properties
        text = try container.decode(String.self, forKey: .text)
        
        // Decode optional properties
        textSize = try container.decodeIfPresent(SwiftTextSize.self, forKey: .textSize)
        textWeight = try container.decodeIfPresent(SwiftTextWeight.self, forKey: .textWeight)
        fontType = try container.decodeIfPresent(SwiftFontType.self, forKey: .fontType)
        textColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .textColor)
        isSubtle = try container.decodeIfPresent(Bool.self, forKey: .isSubtle)
        
        // Decode flags with default values
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        strikethrough = try container.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
        highlight = try container.decodeIfPresent(Bool.self, forKey: .highlight) ?? false
        underline = try container.decodeIfPresent(Bool.self, forKey: .underline) ?? false
        
        // Decode optional properties
        language = try container.decodeIfPresent(String.self, forKey: .language)
        selectAction = try container.decodeIfPresent(SwiftBaseActionElement.self, forKey: .selectAction)
        
        // Handle additional properties
        additionalProperties = [:]
        let allKeys = container.allKeys
        for key in allKeys {
            // Skip already decoded keys
            guard !CodingKeys.allCases.contains(key) else { continue }
            
            // Try to decode any additional properties
            if let value = try? container.decode(SwiftAnyCodable.self, forKey: key) {
                additionalProperties[key.stringValue] = value
            }
        }
    }
    
    // MARK: - Encoding
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode required properties
        try container.encode(text, forKey: .text)
        
        // Encode optional properties that are not nil
        try container.encodeIfPresent(textSize, forKey: .textSize)
        try container.encodeIfPresent(textWeight, forKey: .textWeight)
        try container.encodeIfPresent(fontType, forKey: .fontType)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(isSubtle, forKey: .isSubtle)
        
        // Encode flags when true
        if italic { try container.encode(italic, forKey: .italic) }
        if strikethrough { try container.encode(strikethrough, forKey: .strikethrough) }
        if highlight { try container.encode(highlight, forKey: .highlight) }
        if underline { try container.encode(underline, forKey: .underline) }
        
        // Encode optional properties
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(selectAction, forKey: .selectAction)
        
        // Encode additional properties
        for (key, value) in additionalProperties {
            try? container.encode(value, forKey: CodingKeys(rawValue: key)!)
        }
    }
}

/// Represents a FactSet element in an Adaptive Card.
public class SwiftFactSet: SwiftBaseCardElement {
    // MARK: - Properties
    public let facts: [SwiftFact]
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case facts
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode properties before super.init
        facts = try container.decodeIfPresent([SwiftFact].self, forKey: .facts) ?? []
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(facts, forKey: .facts)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

public struct SwiftFact: Codable {
    // MARK: - Properties
    public var title: String
    public var value: String
    public let language: String?
    
    public init() {
        title = ""
        value = ""
        language = nil
    }

    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case title
        case value
        case language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        language = try container.decodeIfPresent(String.self, forKey: .language)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(language, forKey: .language)
    }
    
    // MARK: - Serialization to JSON
    func serializeToJsonValue() -> [String: Any] {
        return SwiftFactLegacySupport.serializeToJson(self)
    }
}

/// Represents an image set element in an Adaptive Card.
public class SwiftImageSet: SwiftBaseCardElement {
    // MARK: - Properties
    public var images: [SwiftImage] = []
    public var imageSize: SwiftImageSize = .auto
    
    // MARK: - Initializer
    init(id: String? = nil) {
        super.init(
            type: .imageSet,
            spacing: .default,
            height: .auto,
            targetWidth: nil,
            separator: nil,
            isVisible: true,
            areaGridName: nil,
            id: id
        )
        populateKnownPropertiesSet()
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case images, imageSize
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode the images array (using our helper for AnyCodable dictionaries)
        let rawImages = try container.decodeIfPresent([[String: SwiftAnyCodable]].self, forKey: .images) ?? []
        var finalImages = [SwiftImage]()
        for rawImg in rawImages {
            var dict = rawImg.mapValues { $0.value }
            // Ensure that the type is set to "Image"
            if let existingType = dict["type"] as? String {
                if existingType.lowercased() != "image" {
                    throw AdaptiveCardParseError.invalidType
                }
            } else {
                dict["type"] = "Image"
            }
            let base = try SwiftBaseCardElement.deserialize(from: dict)
            guard let img = base as? SwiftImage else {
                throw AdaptiveCardParseError.invalidType
            }
            finalImages.append(img)
        }
        self.images = finalImages
        
        // Decode imageSize; if missing, default to .auto
        self.imageSize = try container.decodeIfPresent(SwiftImageSize.self, forKey: .imageSize) ?? .auto
        
        try super.init(from: decoder)
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(images, forKey: .images)
        try container.encode(imageSize, forKey: .imageSize)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization
    /// Serializes the ImageSet into a JSON dictionary.
    override func serializeToJsonValue() throws -> [String: Any] {
        var json = try super.serializeToJsonValue()
        json["type"] = "ImageSet"
        // Use the toString method to get proper lowercase for "auto" 
        json["imageSize"] = SwiftImageSize.toString(imageSize)
        json["images"] = try images.map { try $0.serializeToJsonValue() }
        return json
    }
    
    // MARK: - Known Properties
    private func populateKnownPropertiesSet() {
        self.knownProperties.insert("images")
        self.knownProperties.insert("imageSize")
    }
    
    // MARK: - Resource Information
    func getResourceInformation(_ resourceInfo: inout [SwiftRemoteResourceInformation]) {
        for image in images {
            image.getResourceInformation(&resourceInfo)
        }
    }
}

/// Parses ImageSet elements in an Adaptive Card.
struct SwiftImageSetParser: SwiftBaseCardElementParser {
    public func deserialize(context: SwiftParseContext, value: [String: Any]) throws -> any SwiftAdaptiveCardElementProtocol {
        try SwiftParseUtil.expectTypeString(value, expected: .imageSet)
        let imageSet = try SwiftBaseCardElement.deserialize(from: value) as! SwiftImageSet
        
        // Grab the "images" array from the JSON.
        let imagesArray: [[String: Any]] = try SwiftParseUtil.getArray(from: value, key: "images", required: false)
        var images: [SwiftImage] = []
        for imageJson in imagesArray {
            var temp = imageJson
            if temp["type"] == nil {
                temp["type"] = "Image"
            }
            let base = try SwiftBaseCardElement.deserialize(from: temp)
            guard let asImage = base as? SwiftImage else {
                throw AdaptiveCardParseError.invalidType
            }
            images.append(asImage)
        }
        imageSet.images = images
        
        // Decode imageSize from the original JSON if present.
        if let sizeStr = value["imageSize"] as? String {
            let size = SwiftImageSize.caseInsensitiveValue(from: sizeStr)
            imageSet.imageSize = size
        } else {
            imageSet.imageSize = .auto
        }
        return imageSet
    }

    public func deserialize(fromString context: SwiftParseContext, value: String) throws -> any SwiftAdaptiveCardElementProtocol {
        let jsonDict = try SwiftParseUtil.getJsonDictionary(from: value)
        return try deserialize(context: context, value: jsonDict)
    }
}

protocol SwiftInline: Codable {
    var inlineType: SwiftInlineElementType { get }
    var additionalProperties: [String: SwiftAnyCodable] { get set }

    func serializeToJson() -> [String: Any]
    static func deserialize(from json: [String: Any]) -> SwiftInline?
}

extension SwiftInline {
    func serializeToJson() -> [String: Any] {
        var json: [String: Any] = additionalProperties.mapValues { $0.value }
        json["type"] = inlineType.rawValue
        return json
    }

    static public func deserialize(from json: [String: Any]) -> SwiftInline? {
        guard let typeString = json["type"] as? String,
              let type = SwiftInlineElementType(rawValue: typeString) else {
            return nil
        }

        switch type {
        case .textRun:
            return try? SwiftTextRun.deserialize(from: json)
        }
    }
}

/// Represents a set of actions in an Adaptive Card.
public class SwiftActionSet: SwiftBaseCardElement {
    // MARK: - Properties
    public var actions: [SwiftBaseActionElement]
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case actions
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode actions array
        var actionsArray: [SwiftBaseActionElement] = []
        var actionsContainer = try container.nestedUnkeyedContainer(forKey: .actions)
        
        while !actionsContainer.isAtEnd {
            // Get the action as a dictionary first
            let actionDict = try actionsContainer.decode([String: SwiftAnyCodable].self)
            let dict = actionDict.mapValues { $0.value }
            
            // Use BaseActionElement's deserializeAction to get the correct type
            let action = try SwiftBaseActionElement.deserializeAction(from: dict)
            actionsArray.append(action)
        }
        
        self.actions = actionsArray
        try super.init(from: decoder)
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actions, forKey: .actions)
        try super.encode(to: encoder)
    }
}

/// Represents a rating input element in an Adaptive Card.
class SwiftRatingInput: SwiftBaseCardElement {
    // MARK: - Properties
    let value: Double
    let max: Double
    let horizontalAlignment: SwiftHorizontalAlignment?
    let size: SwiftRatingSize
    let color: SwiftRatingColor
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case value, max, horizontalAlignment, size, color
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        value = try container.decode(Double.self, forKey: .value)
        max = try container.decode(Double.self, forKey: .max)
        
        // Custom decoding for horizontalAlignment to handle case variations
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment) {
            horizontalAlignment = SwiftHorizontalAlignment.caseInsensitiveValue(from: alignmentString)
        } else {
            horizontalAlignment = nil
        }
        
        size = try container.decodeIfPresent(SwiftRatingSize.self, forKey: .size) ?? .medium
        color = try container.decodeIfPresent(SwiftRatingColor.self, forKey: .color) ?? .neutral
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(max, forKey: .max)
        try container.encodeIfPresent(horizontalAlignment, forKey: .horizontalAlignment)
        try container.encode(size, forKey: .size)
        try container.encode(color, forKey: .color)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Represents a rating label element in an Adaptive Card.
class SwiftRatingLabel: SwiftBaseCardElement {
    // MARK: - Properties
    let value: Double
    let max: Double
    let count: UInt?
    let horizontalAlignment: SwiftHorizontalAlignment?
    let size: SwiftRatingSize
    let color: SwiftRatingColor
    public let style: SwiftRatingStyle
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case value, max, count, horizontalAlignment, size, color, style
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        value = try container.decode(Double.self, forKey: .value)
        max = try container.decode(Double.self, forKey: .max)
        count = try container.decodeIfPresent(UInt.self, forKey: .count)
        
        // Custom decoding for horizontalAlignment to handle case variations
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment) {
            horizontalAlignment = SwiftHorizontalAlignment.caseInsensitiveValue(from: alignmentString)
        } else {
            horizontalAlignment = nil
        }
        
        size = try container.decodeIfPresent(SwiftRatingSize.self, forKey: .size) ?? .medium
        color = try container.decodeIfPresent(SwiftRatingColor.self, forKey: .color) ?? .neutral
        style = try container.decodeIfPresent(SwiftRatingStyle.self, forKey: .style) ?? .default
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(max, forKey: .max)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(horizontalAlignment, forKey: .horizontalAlignment)
        try container.encode(size, forKey: .size)
        try container.encode(color, forKey: .color)
        try container.encode(style, forKey: .style)
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

struct SwiftIconInfo: Codable {
    // MARK: - Properties
    let name: String?
    let foregroundColor: SwiftForegroundColor
    let iconSize: SwiftIconSize
    let iconStyle: SwiftIconStyle

    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case name
        case foregroundColor = "color"
        case iconSize = "size"
        case iconStyle = "style"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties
        name = try container.decodeIfPresent(String.self, forKey: .name)
        foregroundColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .foregroundColor) ?? .default
        iconSize = try container.decodeIfPresent(SwiftIconSize.self, forKey: .iconSize) ?? .standard
        iconStyle = try container.decodeIfPresent(SwiftIconStyle.self, forKey: .iconStyle) ?? .regular
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        
        // Only encode non-default values
        if foregroundColor != .default {
            try container.encode(foregroundColor, forKey: .foregroundColor)
        }
        
        if iconSize != .standard {
            try container.encode(iconSize, forKey: .iconSize)
        }
        
        if iconStyle != .regular {
            try container.encode(iconStyle, forKey: .iconStyle)
        }
    }
    
    // MARK: - Utility Methods
    
    // Get SVG Path
    func getSVGPath() -> String {
        guard let name = name else { return "" }
        return "\(name)/\(name).json"
    }
}

/// Represents choices data in an Adaptive Card.
public struct SwiftChoicesData: Codable {
    // MARK: - Properties
    let choicesDataType: String
    let dataset: String
    let associatedInputs: SwiftAssociatedInputs
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case choicesDataType = "ChoicesDataType"
        case dataset = "Dataset"
        case associatedInputs = "AssociatedInputs"
    }
}

/// Represents a caption source in an Adaptive Card.
public struct SwiftCaptionSource: Codable {
    // MARK: - Properties
    public let mimeType: String?
    public let url: String?
    public let label: String?
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case mimeType = "MimeType"
        case url = "Url"
        case label = "Label"
    }
}

public struct SwiftAuthCardButton: Codable {
    // MARK: - Properties
    public let type: String
    public let title: String
    public let image: String
    public let value: String
}

public struct SwiftAuthentication: Codable {
    public let text: String
    public let connectionName: String
    public let tokenExchangeResource: SwiftTokenExchangeResource?
    public let buttons: [SwiftAuthCardButton]
}

/// Represents a background image in an Adaptive Card.
public struct SwiftBackgroundImage: Codable {
    // MARK: - Properties
    public let url: String
    public let fillMode: SwiftImageFillMode
    public let horizontalAlignment: SwiftHorizontalAlignment
    public let verticalAlignment: SwiftVerticalAlignment
    
    // MARK: - Initialization
    init(
        url: String = "",
        fillMode: SwiftImageFillMode = .cover,
        horizontalAlignment: SwiftHorizontalAlignment = .left,
        verticalAlignment: SwiftVerticalAlignment = .top
    ) {
        self.url = url
        self.fillMode = fillMode
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case url, fillMode, horizontalAlignment, verticalAlignment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode url with default
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        
        // Case-insensitive enum parsing for fillMode
        let fillModeStr = try container.decodeIfPresent(String.self, forKey: .fillMode)?.lowercased() ?? "cover"
        
        // Map common variations for fillMode
        let fillModeMap: [String: SwiftImageFillMode] = [
            "repeathorizontally": .repeatHorizontally,
            "repeat-horizontally": .repeatHorizontally,
            "repeat_horizontally": .repeatHorizontally
        ]
        
        fillMode = fillModeMap[fillModeStr] ?? SwiftImageFillMode(rawValue: fillModeStr) ?? .cover
        
        // Decode alignment values with defaults
        let horizontalStr = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment)?.lowercased() ?? "left"
        horizontalAlignment = SwiftHorizontalAlignment(rawValue: horizontalStr) ?? .left
        
        let verticalStr = try container.decodeIfPresent(String.self, forKey: .verticalAlignment)?.lowercased() ?? "top"
        verticalAlignment = SwiftVerticalAlignment(rawValue: verticalStr) ?? .top
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(url, forKey: .url)
        
        // Use specified enum cases for fillMode
        switch fillMode {
        case .repeatHorizontally:
            try container.encode("repeatHorizontally", forKey: .fillMode)
        default:
            try container.encode(fillMode.rawValue.lowercased(), forKey: .fillMode)
        }
        
        try container.encode(horizontalAlignment.rawValue.lowercased(), forKey: .horizontalAlignment)
        try container.encode(verticalAlignment.rawValue.lowercased(), forKey: .verticalAlignment)
    }
}

/// Represents rich text element properties including formatting styles such as italic, strikethrough, and underline.
struct SwiftRichTextElementProperties: Codable {
    // MARK: - Properties
    let text: String
    let textSize: SwiftTextSize?
    let textWeight: SwiftTextWeight?
    let fontType: SwiftFontType?
    let textColor: SwiftForegroundColor?
    let isSubtle: Bool?
    let language: String
    let italic: Bool
    let strikethrough: Bool
    let underline: Bool
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case text
        case textSize = "size"
        case textWeight = "weight"
        case fontType
        case textColor = "color"
        case isSubtle
        case language
        case italic
        case strikethrough
        case underline
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let rawText = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        text = Self.processHTMLEntities(rawText)
        textSize = try container.decodeIfPresent(SwiftTextSize.self, forKey: .textSize)
        textWeight = try container.decodeIfPresent(SwiftTextWeight.self, forKey: .textWeight)
        fontType = try container.decodeIfPresent(SwiftFontType.self, forKey: .fontType)
        textColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .textColor)
        isSubtle = try container.decodeIfPresent(Bool.self, forKey: .isSubtle)
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? ""
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        strikethrough = try container.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
        underline = try container.decodeIfPresent(Bool.self, forKey: .underline) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(textSize, forKey: .textSize)
        try container.encodeIfPresent(textWeight, forKey: .textWeight)
        try container.encodeIfPresent(fontType, forKey: .fontType)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(isSubtle, forKey: .isSubtle)
        try container.encode(language, forKey: .language)
        try container.encode(italic, forKey: .italic)
        try container.encode(strikethrough, forKey: .strikethrough)
        try container.encode(underline, forKey: .underline)
    }
    
    // MARK: - HTML Entity Processing
    private static func processHTMLEntities(_ input: String) -> String {
        let replacements: [String: String] = [
            "&quot;": "\"",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&amp;": "&"
        ]
        
        var output = input
        for (entity, replacement) in replacements {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }
}

/// Represents a separator with color and thickness attributes.
struct SwiftSeparator: Codable {
    // MARK: - Properties
    let thickness: SwiftSeparatorThickness
    let color: SwiftForegroundColor
    
    // MARK: - Initializers
    
    init(thickness: SwiftSeparatorThickness = .defaultThickness, color: SwiftForegroundColor = .default) {
        self.thickness = thickness
        self.color = color
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case thickness, color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode properties with defaults if not present
        thickness = try container.decodeIfPresent(SwiftSeparatorThickness.self, forKey: .thickness) ?? .defaultThickness
        color = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .color) ?? .default
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(color, forKey: .color)
    }
    
    // MARK: - Serialization to JSON
    
    /// Serializes the Separator to a JSON dictionary.
    func serializeToJsonValue() -> [String: Any] {
        return SwiftSeparatorLegacySupport.serializeToJson(self)
    }
}

/// Represents an unknown element in an Adaptive Card.
public class SwiftUnknownElement: SwiftBaseCardElement {
    // MARK: - Properties
    private let elementType: String
    
    override public var typeString: String {
        get { return elementType }
        set { /* Immutable property, setter required by protocol */ }
    }
    
    // MARK: - Codable Implementation
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Get type first
        guard let typeKey = container.allKeys.first(where: { $0.stringValue == "type" }),
              let typeString = try? container.decode(String.self, forKey: typeKey) else {
            throw DecodingError.dataCorruptedError(
                forKey: .init(stringValue: "type")!,
                in: container,
                debugDescription: "Type is required"
            )
        }
        
        // Set the element type before super.init
        elementType = typeString
        
        // Store ALL properties including type
        var properties = [String: SwiftAnyCodable]()
        for key in container.allKeys {
            properties[key.stringValue] = try container.decode(SwiftAnyCodable.self, forKey: key)
        }
        
        // Call super.init after initializing properties
        try super.init(from: decoder)
        self.additionalProperties = properties
    }
    
    // Custom initializer
    init(id: String? = nil, elementType: String, additionalProperties: [String: SwiftAnyCodable] = [:]) {
        self.elementType = elementType
        super.init(
            type: .unknown,
            spacing: .default,
            height: .auto,
            targetWidth: nil,
            separator: nil,
            isVisible: true,
            areaGridName: nil,
            id: id
        )
        
        // Store ALL properties including type
        var props = additionalProperties
        props["type"] = SwiftAnyCodable(elementType)
        self.additionalProperties = props
    }
    
    // MARK: - Serialization to JSON
    override func serializeToJsonValue() throws -> [String: Any] {
        return additionalProperties?.mapValues { $0.value } ?? [:]
    }
}

/// Represents text element properties including text content, styling, and formatting options.
struct SwiftTextElementProperties: Codable {
    // MARK: - Properties
    
    let text: String
    let textSize: SwiftTextSize?
    let textWeight: SwiftTextWeight?
    let fontType: SwiftFontType?
    let textColor: SwiftForegroundColor?
    let isSubtle: Bool?
    let language: String
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case text
        case textSize = "size"
        case textWeight = "weight"
        case fontType
        case textColor = "color"
        case isSubtle
        case language
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let rawText = try container.decode(String.self, forKey: .text)
        text = SwiftTextElementProperties.processHTMLEntities(rawText)
        
        textSize = try container.decodeIfPresent(SwiftTextSize.self, forKey: .textSize)
        textWeight = try container.decodeIfPresent(SwiftTextWeight.self, forKey: .textWeight)
        fontType = try container.decodeIfPresent(SwiftFontType.self, forKey: .fontType)
        textColor = try container.decodeIfPresent(SwiftForegroundColor.self, forKey: .textColor)
        isSubtle = try container.decodeIfPresent(Bool.self, forKey: .isSubtle)
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(textSize, forKey: .textSize)
        try container.encodeIfPresent(textWeight, forKey: .textWeight)
        try container.encodeIfPresent(fontType, forKey: .fontType)
        try container.encodeIfPresent(textColor, forKey: .textColor)
        try container.encodeIfPresent(isSubtle, forKey: .isSubtle)
        try container.encode(language, forKey: .language)
    }
    
    // MARK: - Serialization to JSON
    
    /// Serializes the `TextElementProperties` to a JSON dictionary.
    func toJSON() -> [String: Any] {
        return SwiftTextElementPropertiesLegacySupport.serializeToJson(self)
    }
    
    // MARK: - HTML Entity Processing
    
    /// Converts HTML entities in text to their respective characters.
    private static func processHTMLEntities(_ input: String) -> String {
        let replacements: [String: String] = [
            "&quot;": "\"",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&amp;": "&"
        ]

        var output = input
        for (entity, replacement) in replacements {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }
}

struct SwiftContentSource: Codable {
    var mimeType: String?
    var url: String?

    private enum CodingKeys: String, CodingKey {
        case mimeType = "MimeType"
        case url = "Url"
    }
}

/// Represents a compound button element in an Adaptive Card.
class SwiftCompoundButton: SwiftBaseCardElement {
    // MARK: - Properties
    let badge: String?
    let title: String?           // Inherited name "title" is now unique since we subclass BaseCardElement.
    let buttonDescription: String?  // Renamed from "description" to avoid conflict with Swift's 'description'.
    let icon: SwiftIconInfo?
    let selectAction: SwiftBaseActionElement?

    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case badge, title, buttonDescription = "description", icon, selectAction
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        badge = try container.decodeIfPresent(String.self, forKey: .badge)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        buttonDescription = try container.decodeIfPresent(String.self, forKey: .buttonDescription)
        icon = try container.decodeIfPresent(SwiftIconInfo.self, forKey: .icon)
        
        // Decode selectAction if present
        if container.contains(.selectAction) {
            let actionDict = try container.decode([String: SwiftAnyCodable].self, forKey: .selectAction)
            let dict = actionDict.mapValues { $0.value }
            selectAction = try SwiftBaseActionElement.deserializeAction(from: dict)
        } else {
            selectAction = nil
        }
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        
        // Set up known properties
        populateKnownPropertiesSet()
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(badge, forKey: .badge)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(buttonDescription, forKey: .buttonDescription)
        try container.encodeIfPresent(icon, forKey: .icon)
        
        if let action = selectAction {
            try container.encode(SwiftAnyCodable(try SwiftBaseCardElement.serializeSelectAction(action)), forKey: .selectAction)
        }
        
        try super.encode(to: encoder)
    }
    
    // MARK: - Serialization to JSON
    /// Serializes the CompoundButton to a JSON dictionary.
    override func serializeToJsonValue() throws -> [String: Any] {
        let json = try super.serializeToJsonValue()
        return try serializeToLegacyJsonFormat(superResult: json)
    }
}

/// Base class for layout implementations in an Adaptive Card.
class SwiftLayout: Codable {
    // MARK: - Properties
    var layoutContainerType: SwiftLayoutContainerType = .none
    var targetWidth: SwiftTargetWidthType = .default
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case layoutContainerType = "layout"
        case targetWidth
    }
    
    // MARK: - Initialization
    init() { }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layoutContainerType = try container.decodeIfPresent(SwiftLayoutContainerType.self, forKey: .layoutContainerType) ?? .none
        targetWidth = try container.decodeIfPresent(SwiftTargetWidthType.self, forKey: .targetWidth) ?? .default
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if layoutContainerType != .stack {
            try container.encode(layoutContainerType, forKey: .layoutContainerType)
        }
        
        if targetWidth != .default {
            try container.encode(targetWidth, forKey: .targetWidth)
        }
    }
}

class SwiftFlowLayout: SwiftLayout {
    var itemFit: SwiftItemFit = .fit
    var itemWidth: String?
    var minItemWidth: String?
    var maxItemWidth: String?
    var itemPixelWidth: Int = -1
    var minItemPixelWidth: Int = -1
    var maxItemPixelWidth: Int = -1
    var rowSpacing: SwiftSpacing = .default
    var columnSpacing: SwiftSpacing = .default
    var horizontalAlignment: SwiftHorizontalAlignment = .center

    override init() {
        super.init()
        layoutContainerType = .flow
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.itemFit = try container.decodeIfPresent(SwiftItemFit.self, forKey: .itemFit) ?? .fit
        self.itemWidth = try container.decodeIfPresent(String.self, forKey: .itemWidth)
        self.minItemWidth = try container.decodeIfPresent(String.self, forKey: .minItemWidth)
        self.maxItemWidth = try container.decodeIfPresent(String.self, forKey: .maxItemWidth)
        self.rowSpacing = try container.decodeIfPresent(SwiftSpacing.self, forKey: .rowSpacing) ?? .default
        self.columnSpacing = try container.decodeIfPresent(SwiftSpacing.self, forKey: .columnSpacing) ?? .default
        // Custom decoding for horizontalAlignment to handle case variations
        if let alignmentString = try container.decodeIfPresent(String.self, forKey: .horizontalAlignment) {
            self.horizontalAlignment = SwiftHorizontalAlignment.caseInsensitiveValue(from: alignmentString)
        } else {
            self.horizontalAlignment = .center
        }
        
        self.itemPixelWidth = SwiftFlowLayout.parseSizeToPixels(try container.decodeIfPresent(String.self, forKey: .itemWidth)) ?? -1
        self.minItemPixelWidth = SwiftFlowLayout.parseSizeToPixels(try container.decodeIfPresent(String.self, forKey: .minItemWidth)) ?? -1
        self.maxItemPixelWidth = SwiftFlowLayout.parseSizeToPixels(try container.decodeIfPresent(String.self, forKey: .maxItemWidth)) ?? -1
    }

    override public func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        if itemFit != .fit {
            try container.encode(itemFit, forKey: .itemFit)
        }
        try container.encodeIfPresent(itemWidth, forKey: .itemWidth)
        try container.encodeIfPresent(minItemWidth, forKey: .minItemWidth)
        try container.encodeIfPresent(maxItemWidth, forKey: .maxItemWidth)
        if rowSpacing != .default {
            try container.encode(rowSpacing, forKey: .rowSpacing)
        }
        if columnSpacing != .default {
            try container.encode(columnSpacing, forKey: .columnSpacing)
        }
        if horizontalAlignment != .center {
            try container.encode(horizontalAlignment, forKey: .horizontalAlignment)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case itemFit, itemWidth, minItemWidth, maxItemWidth, rowSpacing, columnSpacing, horizontalAlignment
    }
    
    static func parseSizeToPixels(_ size: String?) -> Int? {
        guard let size = size else { return nil }
        return Int(size.replacingOccurrences(of: "px", with: ""))
    }
}

/// Represents an area grid layout in an Adaptive Card.
class SwiftAreaGridLayout: SwiftLayout {
    // MARK: - Properties
    var columns: [String] = []
    var areas: [SwiftGridArea] = []
    var rowSpacing: SwiftSpacing = .default
    var columnSpacing: SwiftSpacing = .default
    
    // MARK: - Initialization
    override init() {
        super.init()
        self.layoutContainerType = .areaGrid
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case columns, areas, rowSpacing, columnSpacing
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties before super.init
        columns = try container.decodeIfPresent([String].self, forKey: .columns) ?? []
        areas = try container.decodeIfPresent([SwiftGridArea].self, forKey: .areas) ?? []
        rowSpacing = try container.decodeIfPresent(SwiftSpacing.self, forKey: .rowSpacing) ?? .default
        columnSpacing = try container.decodeIfPresent(SwiftSpacing.self, forKey: .columnSpacing) ?? .default
        
        // Call super.init after initializing all properties
        try super.init(from: decoder)
        self.layoutContainerType = .areaGrid
    }
    
    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(areas, forKey: .areas)
        try container.encode(rowSpacing, forKey: .rowSpacing)
        try container.encode(columnSpacing, forKey: .columnSpacing)
        try super.encode(to: encoder)
    }
}

/// Represents a token exchange resource in Adaptive Cards.
public struct SwiftTokenExchangeResource: Codable {
    /// The unique identifier for the token exchange resource.
    public let id: String?
    
    /// The URI associated with the resource.
    public let uri: String?
    
    /// The provider ID for the resource.
    public let providerId: String?
}
