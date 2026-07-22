//
//  SwiftAdaptiveCard.swift
//  SwiftAdaptiveCards
//
//  Created by Rahul Pinjani on 9/18/24.
//

import Foundation

// MARK: - Additional Missing Types

/// Represents the fallback behavior for an element.
enum SwiftFallbackType: String, Codable {
    case none
    case drop
    case content
}

// MARK: - AdaptiveCard Model

/// Represents an Adaptive Card that contains UI elements and actions.
public class SwiftAdaptiveCard: Codable {
    public var version: String
    public let fallbackText: String?
    public let backgroundImage: SwiftBackgroundImage?         // Defined in BackgroundImage.swift
    public let refresh: SwiftRefresh?                         // Defined in Refresh.swift
    public let authentication: SwiftAuthentication?           // Defined in Authentication.swift
    public let speak: String?
    public let style: SwiftContainerStyle                     // Defined in SwiftEnums.swift
    public let language: String?
    public let verticalContentAlignment: SwiftVerticalContentAlignment // See alias above
    public let height: SwiftHeightType
    public let minHeight: UInt
    public let rtl: Bool?
    public let body: [SwiftBaseCardElement]                   // Defined in BaseCardElement.swift
    public let actions: [SwiftBaseActionElement]              // Defined in BaseActionElement.swift
    let layouts: [SwiftLayout]                         // Defined in Layout.swift
    public let selectAction: SwiftBaseActionElement?          // Defined in BaseActionElement.swift
    let requires: [String: SwiftSemanticVersion]       // Defined in SemanticVersion.swift
    let fallbackContent: SwiftBaseElement?             // Defined in BaseElement.swift
    let fallbackType: SwiftFallbackType
    
    public var additionalProperties: [String: Any] = [:]
    
    public var elementTypeVal: SwiftCardElementType {
        return .adaptiveCard
    }
    
    /// Initializes an empty AdaptiveCard with default values.
    init(
        version: String = "1.0",
        fallbackText: String? = nil,
        backgroundImage: SwiftBackgroundImage? = nil,
        refresh: SwiftRefresh? = nil,
        authentication: SwiftAuthentication? = nil,
        speak: String? = nil,
        style: SwiftContainerStyle = SwiftContainerStyle.none,
        language: String? = nil,
        verticalContentAlignment: SwiftVerticalContentAlignment = .top,
        height: SwiftHeightType = .auto,
        minHeight: UInt = 0,
        rtl: Bool? = nil,
        body: [SwiftBaseCardElement] = [],
        actions: [SwiftBaseActionElement] = [],
        layouts: [SwiftLayout] = [],
        selectAction: SwiftBaseActionElement? = nil,
        requires: [String: SwiftSemanticVersion] = [:],
        fallbackContent: SwiftBaseElement? = nil,
        fallbackType: SwiftFallbackType = .none
    ) {
        self.version = version
        self.fallbackText = fallbackText
        self.backgroundImage = backgroundImage
        self.refresh = refresh
        self.authentication = authentication
        self.speak = speak
        self.style = style
        self.language = language
        self.verticalContentAlignment = verticalContentAlignment
        self.height = height
        self.minHeight = minHeight
        self.rtl = rtl
        self.body = body
        self.actions = actions
        self.layouts = layouts
        self.selectAction = selectAction
        self.requires = requires
        self.fallbackContent = fallbackContent
        self.fallbackType = fallbackType
    }
    
    /// Serializes the card into a JSON dictionary.
    public func serializeToJsonValue() throws -> [String: Any] {
        var json = additionalProperties
        
        // Essential fields that should always be included
        json["type"] = "AdaptiveCard"
        json[SwiftAdaptiveCardSchemaKey.version.rawValue] = version
        
        // Only include non-empty optional fields
        if let language = language {
            json["lang"] = language
        }
        
        // Background image is required in the test
        if let backgroundImage = backgroundImage {
            json[SwiftAdaptiveCardSchemaKey.backgroundImage.rawValue] = backgroundImage.serializeToJsonValue()
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
        
        // Include refresh, authentication, and rtl fields if they exist
        if let refresh = refresh {
            json[SwiftAdaptiveCardSchemaKey.refresh.rawValue] = try refresh.serializeToJsonValue()
        }
        
        if let authentication = authentication {
            json[SwiftAdaptiveCardSchemaKey.authentication.rawValue] = try authentication.serializeToJsonValue()
        }
        
        if let rtl = rtl {
            json[SwiftAdaptiveCardSchemaKey.rtl.rawValue] = rtl
        }
        
        // Include selectAction if present
        if let selectAction = selectAction {
            json[SwiftAdaptiveCardSchemaKey.selectAction.rawValue] = try selectAction.serializeToJsonValue()
        }
        
        // Include requires if not empty
        if !requires.isEmpty {
            var requiresJson: [String: Any] = [:]
            for (key, value) in requires {
                requiresJson[key] = value.serializeToJsonValue()
            }
            json[SwiftAdaptiveCardSchemaKey.requires.rawValue] = requiresJson
        }
        
        // Include fallbackContent if present
        if let fallbackContent = fallbackContent {
            json[SwiftAdaptiveCardSchemaKey.fallbackContent.rawValue] = try fallbackContent.serializeToJsonValue()
        }
        
        // Include fallbackType if not none
        if fallbackType != .none {
            json[SwiftAdaptiveCardSchemaKey.fallbackType.rawValue] = fallbackType.rawValue
        }
        
        return json
    }
    
    /// Converts the card into a JSON string.
    public func serialize() throws -> String {
        return try SwiftParseUtil.jsonToString(serializeToJsonValue())
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case fallbackText
        case backgroundImage
        case refresh
        case authentication
        case speak
        case style
        case language
        case verticalContentAlignment
        case height
        case minHeight
        case rtl
        case body
        case actions
        case layouts
        case selectAction
        case requires
        case fallbackContent
        case fallbackType
    }
    
    required convenience public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode the strings, and if they’re missing, provide defaults:
        let version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        let fallbackText = try container.decodeIfPresent(String.self, forKey: .fallbackText) ?? ""
        let speak = try container.decodeIfPresent(String.self, forKey: .speak) ?? ""
        let language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"
        
        // Decode the rest of the properties as before.
        let styleRaw = try container.decodeIfPresent(String.self, forKey: .style) ?? "none"
        let style = SwiftContainerStyle(rawValue: styleRaw) ?? SwiftContainerStyle.none
        let rtl = try container.decodeIfPresent(Bool.self, forKey: .rtl)
        let fallbackTypeRaw = try container.decodeIfPresent(String.self, forKey: .fallbackType) ?? "none"
        let fallbackType = SwiftFallbackType(rawValue: fallbackTypeRaw) ?? .none

        let backgroundImage = try container.decodeIfPresent(SwiftBackgroundImage.self, forKey: .backgroundImage)
        let refresh = try container.decodeIfPresent(SwiftRefresh.self, forKey: .refresh)
        let authentication = try container.decodeIfPresent(SwiftAuthentication.self, forKey: .authentication)
        
        // Decode body by reading an array of dictionaries, then using your factory.
        let rawBody = try container.decodeIfPresent([[String: SwiftAnyCodable]].self, forKey: .body) ?? []
        let body = try rawBody.map { rawElement in
            let dict = rawElement.mapValues { $0.value }
            return try SwiftBaseCardElement.deserialize(from: dict)
        }
        
        // Decode actions.
        let rawActions = try container.decodeIfPresent([[String: SwiftAnyCodable]].self, forKey: .actions) ?? []
        let actions = try rawActions.map { rawAction -> SwiftBaseActionElement in
            let dict = rawAction.mapValues { $0.value }
            return try SwiftBaseActionElement.deserializeAction(from: dict)
        }
        
        // Decode layouts.
        let layouts = try container.decodeIfPresent([SwiftLayout].self, forKey: .layouts) ?? []
        
        // Decode selectAction.
        let selectAction = try container.decodeIfPresent(SwiftBaseActionElement.self, forKey: .selectAction)
        
        // Vertical Content Alignment.
        let verticalAlignmentRaw = try container.decodeIfPresent(String.self, forKey: .verticalContentAlignment) ?? "top"
        let verticalContentAlignment = SwiftVerticalContentAlignment(rawValue: verticalAlignmentRaw) ?? .top
        
        // Height.
        let heightRaw = try container.decodeIfPresent(String.self, forKey: .height) ?? "auto"
        let height = SwiftHeightType(rawValue: heightRaw) ?? .auto
        
        // minHeight.
        let minHeight = try container.decodeIfPresent(UInt.self, forKey: .minHeight) ?? 0
        
        // requires.
        let requiresDict = try container.decodeIfPresent([String: SwiftSemanticVersion].self, forKey: .requires) ?? [:]
        
        // fallbackContent.
        let fallbackContent = try container.decodeIfPresent(SwiftBaseElement.self, forKey: .fallbackContent)
        
        self.init(
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
            requires: requiresDict,
            fallbackContent: fallbackContent,
            fallbackType: fallbackType
        )
    }
    
    /// Mimics the C++ signature: AdaptiveCard::DeserializeFromString(jsonString, rendererVersion)
    /// Returns a ParseResult that contains an AdaptiveCard.
    public static func deserializeFromString(_ jsonString: String,
                                             version: String) throws -> SwiftParseResult {
        do {
            let card = try SwiftAdaptiveCard.deserialize(from: jsonString)
            let warnings = SwiftWarningCollector.getAndClearWarnings()
            return SwiftParseResult(adaptiveCard: card, warnings: warnings)
        } catch {
            debugPrint("swift adaptive card parse error: \(error)\npayload:\n\(jsonString)")
            throw error
        }
    }
}
