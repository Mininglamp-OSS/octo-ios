//
//  SwiftHostConfig.swift
//  SwiftAdaptiveCards
//
//  Created by Hugo Gonzalez on 3/07/25.
//

import Foundation

// MARK: - JSON Helper

enum SwiftJSONError: Error {
    case missingKey(String)
    case invalidType(key: String, expected: String, actual: String)
}

extension Dictionary where Key == String {
    /// Returns the value for a key or the supplied default.
    func value<T>(forKey key: String, default defaultValue: T) -> T {
        return self[key] as? T ?? defaultValue
    }
    
    /// Returns a nested dictionary for a key (or an empty dictionary if missing)
    func nestedDictionary(forKey key: String) -> [String: Any] {
        return self[key] as? [String: Any] ?? [:]
    }
}

// MARK: - Enums

extension SwiftTextSize {
    var defaultFontSize: UInt {
        switch self {
        case .small: return 10
        case .defaultSize: return 12
        case .medium: return 14
        case .large: return 17
        case .extraLarge: return 20
        }
    }
}

extension SwiftTextWeight {
    var defaultFontWeight: UInt {
        switch self {
        case .lighter: return 200
        case .defaultWeight: return 400
        case .bolder: return 800
        }
    }
}

// MARK: - Configuration Structures

// 1. FontSizesConfig
public struct SwiftFontSizesConfig: Codable {
    var small: UInt?
    var `default`: UInt?
    var medium: UInt?
    var large: UInt?
    var extraLarge: UInt?
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFontSizesConfig) -> SwiftFontSizesConfig {
        return SwiftFontSizesConfig(
            small: json["small"] as? UInt ?? defaultValue.small,
            default: json["default"] as? UInt ?? defaultValue.default,
            medium: json["medium"] as? UInt ?? defaultValue.medium,
            large: json["large"] as? UInt ?? defaultValue.large,
            extraLarge: json["extraLarge"] as? UInt ?? defaultValue.extraLarge
        )
    }
    
    func getFontSize(for size: SwiftTextSize) -> UInt {
        switch size {
        case .small:      return small ?? size.defaultFontSize
        case .medium:     return medium ?? size.defaultFontSize
        case .large:      return large ?? size.defaultFontSize
        case .extraLarge: return extraLarge ?? size.defaultFontSize
        case .defaultSize:    return self.default ?? size.defaultFontSize
        }
    }
    
    static func getDefaultFontSize(for size: SwiftTextSize) -> UInt {
        return size.defaultFontSize
    }
}

// 2. FontWeightsConfig
public struct SwiftFontWeightsConfig: Codable {
    var lighter: UInt?
    var `default`: UInt?
    var bolder: UInt?
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFontWeightsConfig) -> SwiftFontWeightsConfig {
        return SwiftFontWeightsConfig(
            lighter: json["lighter"] as? UInt ?? defaultValue.lighter,
            default: json["default"] as? UInt ?? defaultValue.default,
            bolder: json["bolder"] as? UInt ?? defaultValue.bolder
        )
    }
    
    func getFontWeight(for weight: SwiftTextWeight) -> UInt {
        switch weight {
        case .lighter:  return lighter ?? weight.defaultFontWeight
        case .bolder:   return bolder ?? weight.defaultFontWeight
        case .defaultWeight:  return self.default ?? weight.defaultFontWeight
        }
    }
    
    static func getDefaultFontWeight(for weight: SwiftTextWeight) -> UInt {
        return weight.defaultFontWeight
    }
}

// 3. FontTypeDefinition
public struct SwiftFontTypeDefinition: Codable {
    var fontFamily: String
    var fontSizes: SwiftFontSizesConfig
    var fontWeights: SwiftFontWeightsConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFontTypeDefinition) -> SwiftFontTypeDefinition {
        let fontFamilyValue = (json["fontFamily"] as? String) ?? ""
        let finalFontFamily = fontFamilyValue.isEmpty ? defaultValue.fontFamily : fontFamilyValue
        let sizes = SwiftFontSizesConfig.deserialize(from: json.nestedDictionary(forKey: "fontSizes"), defaultValue: defaultValue.fontSizes)
        let weights = SwiftFontWeightsConfig.deserialize(from: json.nestedDictionary(forKey: "fontWeights"), defaultValue: defaultValue.fontWeights)
        return SwiftFontTypeDefinition(fontFamily: finalFontFamily, fontSizes: sizes, fontWeights: weights)
    }
}

// 4. FontTypesDefinition
public struct SwiftFontTypesDefinition: Codable {
    var defaultFontType: SwiftFontTypeDefinition
    var monospaceFontType: SwiftFontTypeDefinition
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFontTypesDefinition) -> SwiftFontTypesDefinition {
        let defaultFont = SwiftFontTypeDefinition.deserialize(from: json.nestedDictionary(forKey: "default"), defaultValue: defaultValue.defaultFontType)
        let monospaceFont = SwiftFontTypeDefinition.deserialize(from: json.nestedDictionary(forKey: "monospace"), defaultValue: defaultValue.monospaceFontType)
        return SwiftFontTypesDefinition(defaultFontType: defaultFont, monospaceFontType: monospaceFont)
    }
}

// 5. HighlightColorConfig
public struct SwiftHighlightColorConfig: Codable {
    var defaultColor: String
    var subtleColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftHighlightColorConfig) -> SwiftHighlightColorConfig {
        let defColor = (json["default"] as? String) ?? ""
        let finalDefault = defColor.isEmpty ? defaultValue.defaultColor : defColor
        let subColor = (json["subtle"] as? String) ?? ""
        let finalSubtle = subColor.isEmpty ? defaultValue.subtleColor : subColor
        return SwiftHighlightColorConfig(defaultColor: finalDefault, subtleColor: finalSubtle)
    }
}

// 6. ColorConfig
public struct SwiftColorConfig: Codable {
    var defaultColor: String
    var subtleColor: String
    var highlightColors: SwiftHighlightColorConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftColorConfig) -> SwiftColorConfig {
        let defColor = (json["default"] as? String) ?? ""
        let finalDefault = defColor.isEmpty ? defaultValue.defaultColor : defColor
        let subColor = (json["subtle"] as? String) ?? ""
        let finalSubtle = subColor.isEmpty ? defaultValue.subtleColor : subColor
        let highlight = SwiftHighlightColorConfig.deserialize(from: json.nestedDictionary(forKey: "highlightColors"), defaultValue: defaultValue.highlightColors)
        return SwiftColorConfig(defaultColor: finalDefault, subtleColor: finalSubtle, highlightColors: highlight)
    }
}

// 7. ColorsConfig
public struct SwiftColorsConfig: Codable {
    var `default`: SwiftColorConfig
    var accent: SwiftColorConfig
    var dark: SwiftColorConfig
    var light: SwiftColorConfig
    var good: SwiftColorConfig
    var warning: SwiftColorConfig
    var attention: SwiftColorConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftColorsConfig) -> SwiftColorsConfig {
        return SwiftColorsConfig(
            default: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "default"), defaultValue: defaultValue.default),
            accent: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "accent"), defaultValue: defaultValue.accent),
            dark: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "dark"), defaultValue: defaultValue.dark),
            light: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "light"), defaultValue: defaultValue.light),
            good: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "good"), defaultValue: defaultValue.good),
            warning: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "warning"), defaultValue: defaultValue.warning),
            attention: SwiftColorConfig.deserialize(from: json.nestedDictionary(forKey: "attention"), defaultValue: defaultValue.attention)
        )
    }
}

// 8. TextStyleConfig
public struct SwiftTextStyleConfig: Codable, Equatable {
    public var weight: SwiftTextWeight
    public var size: SwiftTextSize
    public var isSubtle: Bool
    public var color: SwiftForegroundColor
    public var fontType: SwiftFontType
    
    public init(weight: SwiftTextWeight, size: SwiftTextSize, isSubtle: Bool, color: SwiftForegroundColor, fontType: SwiftFontType) {
        self.weight = weight
        self.size = size
        self.isSubtle = isSubtle
        self.color = color
        self.fontType = fontType
    }
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftTextStyleConfig) -> SwiftTextStyleConfig {
        // Use the fromString methods (with capitalization if needed)
        let weightStr = json["weight"] as? String ?? defaultValue.weight.rawValue
        let weight = SwiftTextWeight.caseInsensitiveValue(from: weightStr)
        
        let sizeStr = json["size"] as? String ?? defaultValue.size.rawValue
        let size = SwiftTextSize.caseInsensitiveValue(from: sizeStr)
        
        let isSubtle = json["isSubtle"] as? Bool ?? defaultValue.isSubtle
        
        let colorStr = json["color"] as? String ?? defaultValue.color.rawValue
        let color = SwiftForegroundColor.fromString(colorStr) ?? defaultValue.color
        
        let fontTypeStr = json["fontType"] as? String ?? defaultValue.fontType.rawValue
        let fontType = SwiftFontType.fromString(fontTypeStr.capitalized) ?? defaultValue.fontType
        
        return SwiftTextStyleConfig(weight: weight, size: size, isSubtle: isSubtle, color: color, fontType: fontType)
    }
}

// 9. FactSetTextConfig
public struct SwiftFactSetTextConfig: Codable {
    var weight: SwiftTextWeight
    var size: SwiftTextSize
    var isSubtle: Bool
    var color: SwiftForegroundColor
    var fontType: SwiftFontType
    var wrap: Bool
    var maxWidth: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFactSetTextConfig) -> SwiftFactSetTextConfig {
        let base = SwiftTextStyleConfig.deserialize(from: json, defaultValue: SwiftTextStyleConfig(weight: defaultValue.weight, size: defaultValue.size, isSubtle: defaultValue.isSubtle, color: defaultValue.color, fontType: defaultValue.fontType))
        let wrap = json["wrap"] as? Bool ?? defaultValue.wrap
        let maxWidth = json["maxWidth"] as? UInt ?? defaultValue.maxWidth
        return SwiftFactSetTextConfig(weight: base.weight, size: base.size, isSubtle: base.isSubtle, color: base.color, fontType: base.fontType, wrap: wrap, maxWidth: maxWidth)
    }
}

// 10. RatingStarCofig
public struct SwiftRatingStarCofig: Codable {
    var marigoldColor: String
    var neutralColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftRatingStarCofig) -> SwiftRatingStarCofig {
        let marigold = json["marigoldColor"] as? String ?? defaultValue.marigoldColor
        let neutral = json["neutralColor"] as? String ?? defaultValue.neutralColor
        return SwiftRatingStarCofig(marigoldColor: marigold, neutralColor: neutral)
    }
}

// 11. RatingElementConfig
public struct SwiftRatingElementConfig: Codable {
    var filledStar: SwiftRatingStarCofig
    var emptyStar: SwiftRatingStarCofig
    var ratingTextColor: String
    var countTextColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftRatingElementConfig) -> SwiftRatingElementConfig {
        let filled = SwiftRatingStarCofig.deserialize(from: json.nestedDictionary(forKey: "filledStar"), defaultValue: defaultValue.filledStar)
        let empty = SwiftRatingStarCofig.deserialize(from: json.nestedDictionary(forKey: "emptyStar"), defaultValue: defaultValue.emptyStar)
        let ratingTextColor = json["ratingTextColor"] as? String ?? defaultValue.ratingTextColor
        let countTextColor = json["countTextColor"] as? String ?? defaultValue.countTextColor
        return SwiftRatingElementConfig(filledStar: filled, emptyStar: empty, ratingTextColor: ratingTextColor, countTextColor: countTextColor)
    }
}

// 12. TextStylesConfig
public struct SwiftTextStylesConfig: Codable {
    public var heading: SwiftTextStyleConfig
    public var columnHeader: SwiftTextStyleConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftTextStylesConfig) -> SwiftTextStylesConfig {
        let heading = SwiftTextStyleConfig.deserialize(from: json.nestedDictionary(forKey: "heading"), defaultValue: defaultValue.heading)
        let columnHeader = SwiftTextStyleConfig.deserialize(from: json.nestedDictionary(forKey: "columnHeader"), defaultValue: defaultValue.columnHeader)
        return SwiftTextStylesConfig(heading: heading, columnHeader: columnHeader)
    }
}

// 13. SpacingConfig
public struct SwiftSpacingConfig: Codable {
    var smallSpacing: UInt
    var defaultSpacing: UInt
    var mediumSpacing: UInt
    var largeSpacing: UInt
    var extraLargeSpacing: UInt
    var paddingSpacing: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftSpacingConfig) -> SwiftSpacingConfig {
        return SwiftSpacingConfig(
            smallSpacing: json["smallSpacing"] as? UInt ?? defaultValue.smallSpacing,
            defaultSpacing: json["defaultSpacing"] as? UInt ?? defaultValue.defaultSpacing,
            mediumSpacing: json["mediumSpacing"] as? UInt ?? defaultValue.mediumSpacing,
            largeSpacing: json["largeSpacing"] as? UInt ?? defaultValue.largeSpacing,
            extraLargeSpacing: json["extraLargeSpacing"] as? UInt ?? defaultValue.extraLargeSpacing,
            paddingSpacing: json["paddingSpacing"] as? UInt ?? defaultValue.paddingSpacing
        )
    }
}

// 14. SeparatorConfig
public struct SwiftSeparatorConfig: Codable {
    var lineThickness: UInt
    var lineColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftSeparatorConfig) -> SwiftSeparatorConfig {
        let thickness = json["lineThickness"] as? UInt ?? defaultValue.lineThickness
        let color = (json["lineColor"] as? String).flatMap { !$0.isEmpty ? $0 : defaultValue.lineColor } ?? defaultValue.lineColor
        return SwiftSeparatorConfig(lineThickness: thickness, lineColor: color)
    }
}

// 15. ImageSizesConfig
public struct SwiftImageSizesConfig: Codable {
    var smallSize: UInt
    var mediumSize: UInt
    var largeSize: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftImageSizesConfig) -> SwiftImageSizesConfig {
        return SwiftImageSizesConfig(
            smallSize: json["smallSize"] as? UInt ?? defaultValue.smallSize,
            mediumSize: json["mediumSize"] as? UInt ?? defaultValue.mediumSize,
            largeSize: json["largeSize"] as? UInt ?? defaultValue.largeSize
        )
    }
}

// 16. ImageSetConfig
public struct SwiftImageSetConfig: Codable {
    var imageSize: SwiftImageSize
    var maxImageHeight: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftImageSetConfig) -> SwiftImageSetConfig {
        let imageSizeStr = json["imageSize"] as? String ?? defaultValue.imageSize.rawValue
        let imageSize = SwiftImageSize(rawValue: imageSizeStr) ?? defaultValue.imageSize
        let maxHeight = json["maxImageHeight"] as? UInt ?? defaultValue.maxImageHeight
        return SwiftImageSetConfig(imageSize: imageSize, maxImageHeight: maxHeight)
    }
}

// 17. ImageConfig
public struct SwiftImageConfig: Codable {
    var imageSize: SwiftImageSize
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftImageConfig) -> SwiftImageConfig {
        let imageSizeStr = json["imageSize"] as? String ?? defaultValue.imageSize.rawValue
        let imageSize = SwiftImageSize(rawValue: imageSizeStr) ?? defaultValue.imageSize
        return SwiftImageConfig(imageSize: imageSize)
    }
}

// 18. AdaptiveCardConfig
public struct SwiftAdaptiveCardConfig: Codable {
    var allowCustomStyle: Bool
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftAdaptiveCardConfig) -> SwiftAdaptiveCardConfig {
        let allowStyle = json["allowCustomStyle"] as? Bool ?? defaultValue.allowCustomStyle
        return SwiftAdaptiveCardConfig(allowCustomStyle: allowStyle)
    }
}

// 19. FactSetConfig
public struct SwiftFactSetConfig: Codable {
    var title: SwiftFactSetTextConfig
    var value: SwiftFactSetTextConfig
    var spacing: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftFactSetConfig) -> SwiftFactSetConfig {
        let spacing = json["spacing"] as? UInt ?? defaultValue.spacing
        let title = SwiftFactSetTextConfig.deserialize(from: json.nestedDictionary(forKey: "title"), defaultValue: defaultValue.title)
        var valueConfig = SwiftFactSetTextConfig.deserialize(from: json.nestedDictionary(forKey: "value"), defaultValue: defaultValue.value)
        // As in C++ the value’s maxWidth is reset to default.
        valueConfig.maxWidth = defaultValue.value.maxWidth
        return SwiftFactSetConfig(title: title, value: valueConfig, spacing: spacing)
    }
}

// 20. ContainerStyleDefinition
public struct SwiftContainerStyleDefinition: Codable {
    var backgroundColor: String
    var borderColor: String
    var foregroundColors: SwiftColorsConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftContainerStyleDefinition) -> SwiftContainerStyleDefinition {
        let bg = (json["backgroundColor"] as? String).flatMap { !$0.isEmpty ? $0 : defaultValue.backgroundColor } ?? defaultValue.backgroundColor
        let border = (json["borderColor"] as? String).flatMap { !$0.isEmpty ? $0 : defaultValue.borderColor } ?? defaultValue.borderColor
        let foreground = SwiftColorsConfig.deserialize(from: json.nestedDictionary(forKey: "foregroundColors"), defaultValue: defaultValue.foregroundColors)
        return SwiftContainerStyleDefinition(backgroundColor: bg, borderColor: border, foregroundColors: foreground)
    }
}

// 21. ContainerStylesDefinition
public struct SwiftContainerStylesDefinition: Codable {
    var defaultPalette: SwiftContainerStyleDefinition
    var emphasisPalette: SwiftContainerStyleDefinition
    var goodPalette: SwiftContainerStyleDefinition
    var attentionPalette: SwiftContainerStyleDefinition
    var warningPalette: SwiftContainerStyleDefinition
    var accentPalette: SwiftContainerStyleDefinition
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftContainerStylesDefinition) -> SwiftContainerStylesDefinition {
        return SwiftContainerStylesDefinition(
            defaultPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "default"), defaultValue: defaultValue.defaultPalette),
            emphasisPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "emphasis"), defaultValue: defaultValue.emphasisPalette),
            goodPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "good"), defaultValue: defaultValue.goodPalette),
            attentionPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "attention"), defaultValue: defaultValue.attentionPalette),
            warningPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "warning"), defaultValue: defaultValue.warningPalette),
            accentPalette: SwiftContainerStyleDefinition.deserialize(from: json.nestedDictionary(forKey: "accent"), defaultValue: defaultValue.accentPalette)
        )
    }
}

// 22. ShowCardActionConfig
public struct SwiftShowCardActionConfig: Codable {
    var actionMode: SwiftActionMode
    var style: SwiftContainerStyle
    var inlineTopMargin: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftShowCardActionConfig) -> SwiftShowCardActionConfig {
        let modeStr = json["actionMode"] as? String ?? defaultValue.actionMode.rawValue
        let mode = SwiftActionMode(rawValue: modeStr) ?? defaultValue.actionMode
        let styleStr = json["style"] as? String ?? defaultValue.style.rawValue
        let style = SwiftContainerStyle(rawValue: styleStr) ?? defaultValue.style
        let margin = json["inlineTopMargin"] as? UInt ?? defaultValue.inlineTopMargin
        return SwiftShowCardActionConfig(actionMode: mode, style: style, inlineTopMargin: margin)
    }
}

// 23. ActionsConfig
public struct SwiftActionsConfig: Codable {
    var showCard: SwiftShowCardActionConfig
    var actionsOrientation: SwiftActionsOrientation
    var actionAlignment: SwiftActionAlignment
    var buttonSpacing: UInt
    var maxActions: UInt
    var spacing: SwiftSpacing
    var iconPlacement: SwiftIconPlacement
    var iconSize: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftActionsConfig) -> SwiftActionsConfig {
        let orientationStr = json["actionsOrientation"] as? String ?? defaultValue.actionsOrientation.rawValue
        let orientation = SwiftActionsOrientation(rawValue: orientationStr) ?? defaultValue.actionsOrientation
        let alignmentStr = json["actionAlignment"] as? String ?? defaultValue.actionAlignment.rawValue
        let alignment = SwiftActionAlignment(rawValue: alignmentStr) ?? defaultValue.actionAlignment
        let buttonSpacing = json["buttonSpacing"] as? UInt ?? defaultValue.buttonSpacing
        let maxActions = json["maxActions"] as? UInt ?? defaultValue.maxActions
        let spacingStr = json["spacing"] as? String ?? defaultValue.spacing.rawValue
        let spacing = SwiftSpacing(rawValue: spacingStr) ?? defaultValue.spacing
        let iconPlacementStr = json["iconPlacement"] as? String ?? defaultValue.iconPlacement.rawValue
        let iconPlacement = SwiftIconPlacement(rawValue: iconPlacementStr) ?? defaultValue.iconPlacement
        let iconSize = json["iconSize"] as? UInt ?? defaultValue.iconSize
        let showCard = SwiftShowCardActionConfig.deserialize(from: json.nestedDictionary(forKey: "showCard"), defaultValue: defaultValue.showCard)
        return SwiftActionsConfig(showCard: showCard, actionsOrientation: orientation, actionAlignment: alignment, buttonSpacing: buttonSpacing, maxActions: maxActions, spacing: spacing, iconPlacement: iconPlacement, iconSize: iconSize)
    }
}

// 24. InputLabelConfig
public struct SwiftInputLabelConfig: Codable {
    var color: SwiftForegroundColor
    var isSubtle: Bool
    var size: SwiftTextSize
    var suffix: String
    var weight: SwiftTextWeight
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftInputLabelConfig) -> SwiftInputLabelConfig {
        let colorStr = json["color"] as? String ?? defaultValue.color.rawValue
        let color = SwiftForegroundColor(rawValue: colorStr) ?? defaultValue.color
        let isSubtle = json["isSubtle"] as? Bool ?? defaultValue.isSubtle
        let sizeStr = json["size"] as? String ?? defaultValue.size.rawValue
        let size = SwiftTextSize(rawValue: sizeStr) ?? defaultValue.size
        let suffix = json["suffix"] as? String ?? defaultValue.suffix
        let weightStr = json["weight"] as? String ?? defaultValue.weight.rawValue
        let weight = SwiftTextWeight(rawValue: weightStr) ?? defaultValue.weight
        return SwiftInputLabelConfig(color: color, isSubtle: isSubtle, size: size, suffix: suffix, weight: weight)
    }
}

// 25. LabelConfig
public struct SwiftLabelConfig: Codable {
    var inputSpacing: SwiftSpacing
    var requiredInputs: SwiftInputLabelConfig
    var optionalInputs: SwiftInputLabelConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftLabelConfig) -> SwiftLabelConfig {
        let spacingStr = json["inputSpacing"] as? String ?? defaultValue.inputSpacing.rawValue
        let spacing = SwiftSpacing(rawValue: spacingStr) ?? defaultValue.inputSpacing
        let required = SwiftInputLabelConfig.deserialize(from: json.nestedDictionary(forKey: "requiredInputs"), defaultValue: defaultValue.requiredInputs)
        let optional = SwiftInputLabelConfig.deserialize(from: json.nestedDictionary(forKey: "optionalInputs"), defaultValue: defaultValue.optionalInputs)
        return SwiftLabelConfig(inputSpacing: spacing, requiredInputs: required, optionalInputs: optional)
    }
}

// 26. ErrorMessageConfig
public struct SwiftErrorMessageConfig: Codable {
    var size: SwiftTextSize
    var spacing: SwiftSpacing
    var weight: SwiftTextWeight
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftErrorMessageConfig) -> SwiftErrorMessageConfig {
        let sizeStr = json["size"] as? String ?? defaultValue.size.rawValue
        let size = SwiftTextSize(rawValue: sizeStr) ?? defaultValue.size
        let spacingStr = json["spacing"] as? String ?? defaultValue.spacing.rawValue
        let spacing = SwiftSpacing(rawValue: spacingStr) ?? defaultValue.spacing
        let weightStr = json["weight"] as? String ?? defaultValue.weight.rawValue
        let weight = SwiftTextWeight(rawValue: weightStr) ?? defaultValue.weight
        return SwiftErrorMessageConfig(size: size, spacing: spacing, weight: weight)
    }
}

// 27. InputsConfig
public struct SwiftInputsConfig: Codable {
    var label: SwiftLabelConfig
    var errorMessage: SwiftErrorMessageConfig
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftInputsConfig) -> SwiftInputsConfig {
        let errorMsg = SwiftErrorMessageConfig.deserialize(from: json.nestedDictionary(forKey: "errorMessage"), defaultValue: defaultValue.errorMessage)
        let label = SwiftLabelConfig.deserialize(from: json.nestedDictionary(forKey: "label"), defaultValue: defaultValue.label)
        return SwiftInputsConfig(label: label, errorMessage: errorMsg)
    }
}

// 28. MediaConfig
public struct SwiftMediaConfig: Codable {
    var defaultPoster: String
    var playButton: String
    var allowInlinePlayback: Bool
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftMediaConfig) -> SwiftMediaConfig {
        let poster = (json["defaultPoster"] as? String).flatMap { !$0.isEmpty ? $0 : defaultValue.defaultPoster } ?? defaultValue.defaultPoster
        let playButton = (json["playButton"] as? String).flatMap { !$0.isEmpty ? $0 : defaultValue.playButton } ?? defaultValue.playButton
        let inlinePlayback = json["allowInlinePlayback"] as? Bool ?? defaultValue.allowInlinePlayback
        return SwiftMediaConfig(defaultPoster: poster, playButton: playButton, allowInlinePlayback: inlinePlayback)
    }
}

// 29. HostWidthConfig
public struct SwiftHostWidthConfig: Codable {
    var veryNarrow: UInt
    var narrow: UInt
    var standard: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftHostWidthConfig) -> SwiftHostWidthConfig {
        return SwiftHostWidthConfig(
            veryNarrow: json["veryNarrow"] as? UInt ?? defaultValue.veryNarrow,
            narrow: json["narrow"] as? UInt ?? defaultValue.narrow,
            standard: json["standard"] as? UInt ?? defaultValue.standard
        )
    }
}

// 30. TextBlockConfig
public struct SwiftTextBlockConfig: Codable {
    var headingLevel: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftTextBlockConfig) -> SwiftTextBlockConfig {
        return SwiftTextBlockConfig(
            headingLevel: json["headingLevel"] as? UInt ?? defaultValue.headingLevel
        )
    }
}

// 31. TableConfig
public struct SwiftTableConfig: Codable {
    public var cellSpacing: UInt
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftTableConfig) -> SwiftTableConfig {
        return SwiftTableConfig(
            cellSpacing: json["cellSpacing"] as? UInt ?? defaultValue.cellSpacing
        )
    }
}

// 32. BadgeConfig
public struct SwiftBadgeConfig: Codable {
    var backgroundColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftBadgeConfig) -> SwiftBadgeConfig {
        let bg = json["backgroundColor"] as? String ?? defaultValue.backgroundColor
        return SwiftBadgeConfig(backgroundColor: bg)
    }
}

// 33. CompoundButtonConfig
public struct SwiftCompoundButtonConfig: Codable {
    var badgeConfig: SwiftBadgeConfig
    var borderColor: String
    
    static public func deserialize(from json: [String: Any], defaultValue: SwiftCompoundButtonConfig) -> SwiftCompoundButtonConfig {
        let badge = SwiftBadgeConfig.deserialize(from: json.nestedDictionary(forKey: "badge"), defaultValue: defaultValue.badgeConfig)
        let border = json["borderColor"] as? String ?? defaultValue.borderColor
        return SwiftCompoundButtonConfig(badgeConfig: badge, borderColor: border)
    }
}

// 34. HostConfig
public struct SwiftHostConfig: Codable {
    var fontFamily: String
    var supportsInteractivity: Bool
    var imageBaseUrl: String
    var fontSizes: SwiftFontSizesConfig
    var fontWeights: SwiftFontWeightsConfig
    var fontTypes: SwiftFontTypesDefinition
    var imageSizes: SwiftImageSizesConfig
    var image: SwiftImageConfig
    var separator: SwiftSeparatorConfig
    var spacing: SwiftSpacingConfig
    var adaptiveCard: SwiftAdaptiveCardConfig
    var imageSet: SwiftImageSetConfig
    var factSet: SwiftFactSetConfig
    var actions: SwiftActionsConfig
    var containerStyles: SwiftContainerStylesDefinition
    var media: SwiftMediaConfig
    var inputs: SwiftInputsConfig
    var hostWidth: SwiftHostWidthConfig
    var textBlock: SwiftTextBlockConfig
    public var textStyles: SwiftTextStylesConfig
    var ratingLabelConfig: SwiftRatingElementConfig
    var ratingInputConfig: SwiftRatingElementConfig
    public var table: SwiftTableConfig
    var borderWidth: [String: UInt]   // mapping from element type key to width
    var cornerRadius: [String: UInt]    // mapping from element type key to radius
    var compoundButtonConfig: SwiftCompoundButtonConfig
    
    // Default initializer with sample defaults (adjust as needed).
    init() {
        self.fontFamily = ""
        self.supportsInteractivity = true
        self.imageBaseUrl = ""
        self.fontSizes = SwiftFontSizesConfig(small: UInt.max, default: UInt.max, medium: UInt.max, large: UInt.max, extraLarge: UInt.max)
        self.fontWeights = SwiftFontWeightsConfig(lighter: UInt.max, default: UInt.max, bolder: UInt.max)
        let defaultFontType = SwiftFontTypeDefinition(fontFamily: "", fontSizes: self.fontSizes, fontWeights: self.fontWeights)
        self.fontTypes = SwiftFontTypesDefinition(defaultFontType: defaultFontType, monospaceFontType: defaultFontType)
        self.imageSizes = SwiftImageSizesConfig(smallSize: 80, mediumSize: 120, largeSize: 180)
        self.image = SwiftImageConfig(imageSize: .auto)
        self.separator = SwiftSeparatorConfig(lineThickness: 1, lineColor: "#B2000000")
        self.spacing = SwiftSpacingConfig(smallSpacing: 3, defaultSpacing: 8, mediumSpacing: 20, largeSpacing: 30, extraLargeSpacing: 40, paddingSpacing: 20)
        self.adaptiveCard = SwiftAdaptiveCardConfig(allowCustomStyle: true)
        self.imageSet = SwiftImageSetConfig(imageSize: .auto, maxImageHeight: 100)
        let defaultFactSetText = SwiftFactSetTextConfig(weight: .bolder, size: .defaultSize, isSubtle: false, color: .default, fontType: .defaultFont, wrap: true, maxWidth: UInt.max)
        self.factSet = SwiftFactSetConfig(title: defaultFactSetText, value: defaultFactSetText, spacing: 10)
        let defaultShowCard = SwiftShowCardActionConfig(actionMode: .inline, style: .emphasis, inlineTopMargin: 16)
        self.actions = SwiftActionsConfig(showCard: defaultShowCard, actionsOrientation: .horizontal, actionAlignment: .stretch, buttonSpacing: 10, maxActions: 5, spacing: .default, iconPlacement: .aboveTitle, iconSize: 16)
        // Default container styles with sample colors.
        let defaultColorConfig = SwiftColorConfig(defaultColor: "#FF000000", subtleColor: "#B2000000", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0"))
        let defaultColorsConfig = SwiftColorsConfig(default: defaultColorConfig,
                                               accent: SwiftColorConfig(defaultColor: "#FF0000FF", subtleColor: "#B20000FF", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")),
                                               dark: SwiftColorConfig(defaultColor: "#FF101010", subtleColor: "#B2101010", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")),
                                               light: SwiftColorConfig(defaultColor: "#FFFFFFFF", subtleColor: "#B2FFFFFF", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")),
                                               good: SwiftColorConfig(defaultColor: "#FF008000", subtleColor: "#B2008000", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")),
                                               warning: SwiftColorConfig(defaultColor: "#FFFFD700", subtleColor: "#B2FFD700", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")),
                                               attention: SwiftColorConfig(defaultColor: "#FF8B0000", subtleColor: "#B28B0000", highlightColors: SwiftHighlightColorConfig(defaultColor: "#FFFFFF00", subtleColor: "#FFFFFFE0")))
        let defaultContainerStyle = SwiftContainerStyleDefinition(backgroundColor: "#FFFFFFFF", borderColor: "#FF7F7F7F", foregroundColors: defaultColorsConfig)
        self.containerStyles = SwiftContainerStylesDefinition(
            defaultPalette: defaultContainerStyle,
            emphasisPalette: SwiftContainerStyleDefinition(backgroundColor: "#08000000", borderColor: "#08000000", foregroundColors: defaultColorsConfig),
            goodPalette: SwiftContainerStyleDefinition(backgroundColor: "#FFD5F0DD", borderColor: "#FF7F7F7F", foregroundColors: defaultColorsConfig),
            attentionPalette: SwiftContainerStyleDefinition(backgroundColor: "#F7E9E9", borderColor: "#FF7F7F7F", foregroundColors: defaultColorsConfig),
            warningPalette: SwiftContainerStyleDefinition(backgroundColor: "#F7F7DF", borderColor: "#FF7F7F7F", foregroundColors: defaultColorsConfig),
            accentPalette: SwiftContainerStyleDefinition(backgroundColor: "#DCE5F7", borderColor: "#FF7F7F7F", foregroundColors: defaultColorsConfig)
        )
        self.media = SwiftMediaConfig(defaultPoster: "", playButton: "", allowInlinePlayback: true)
        let defaultInputLabel = SwiftInputLabelConfig(color: .default, isSubtle: false, size: .defaultSize, suffix: "", weight: .defaultWeight)
        self.inputs = SwiftInputsConfig(label: SwiftLabelConfig(inputSpacing: .default, requiredInputs: defaultInputLabel, optionalInputs: defaultInputLabel),
                                   errorMessage: SwiftErrorMessageConfig(size: .defaultSize, spacing: .default, weight: .defaultWeight))
        self.hostWidth = SwiftHostWidthConfig(veryNarrow: 0, narrow: 0, standard: 0)
        self.textBlock = SwiftTextBlockConfig(headingLevel: 2)
        let defaultTextStyle = SwiftTextStyleConfig(weight: .defaultWeight, size: .defaultSize, isSubtle: false, color: .default, fontType: .defaultFont)
        let defaultColumnHeaderStyle = SwiftTextStyleConfig(weight: .bolder, size: .defaultSize, isSubtle: false, color: .default, fontType: .defaultFont)
        self.textStyles = SwiftTextStylesConfig(heading: defaultTextStyle, columnHeader: defaultColumnHeaderStyle)
        self.ratingLabelConfig = SwiftRatingElementConfig(filledStar: SwiftRatingStarCofig(marigoldColor: "#EAA300", neutralColor: "#212121"),
                                                      emptyStar: SwiftRatingStarCofig(marigoldColor: "#EAA300", neutralColor: "#212121"),
                                                      ratingTextColor: "#000000",
                                                      countTextColor: "#000000")
        self.ratingInputConfig = SwiftRatingElementConfig(filledStar: SwiftRatingStarCofig(marigoldColor: "#EAA300", neutralColor: "#212121"),
                                                      emptyStar: SwiftRatingStarCofig(marigoldColor: "#EAA300", neutralColor: "#212121"),
                                                      ratingTextColor: "#000000",
                                                      countTextColor: "#000000")
        self.table = SwiftTableConfig(cellSpacing: 8)
        self.borderWidth = [:]
        self.cornerRadius = [:]
        self.compoundButtonConfig = SwiftCompoundButtonConfig(badgeConfig: SwiftBadgeConfig(backgroundColor: "#5B5FC7"), borderColor: "#E1E1E1")
    }
    
    static public func deserialize(from json: [String: Any]) -> SwiftHostConfig {
        var result = SwiftHostConfig()
        // Font Family
        if let fontFamily = json["fontFamily"] as? String, !fontFamily.isEmpty {
            result.fontFamily = fontFamily
        }
        // Supports Interactivity
        result.supportsInteractivity = json["supportsInteractivity"] as? Bool ?? result.supportsInteractivity
        // Image Base URL
        result.imageBaseUrl = json["imageBaseUrl"] as? String ?? result.imageBaseUrl
        
        // FactSet
        result.factSet = SwiftFactSetConfig.deserialize(from: json.nestedDictionary(forKey: "factSet"), defaultValue: result.factSet)
        // Font Sizes
        result.fontSizes = SwiftFontSizesConfig.deserialize(from: json.nestedDictionary(forKey: "fontSizes"), defaultValue: result.fontSizes)
        // Font Weights
        result.fontWeights = SwiftFontWeightsConfig.deserialize(from: json.nestedDictionary(forKey: "fontWeights"), defaultValue: result.fontWeights)
        // Font Types
        result.fontTypes = SwiftFontTypesDefinition.deserialize(from: json.nestedDictionary(forKey: "fontTypes"), defaultValue: result.fontTypes)
        // Container Styles
        result.containerStyles = SwiftContainerStylesDefinition.deserialize(from: json.nestedDictionary(forKey: "containerStyles"), defaultValue: result.containerStyles)
        // Image Config
        result.image = SwiftImageConfig.deserialize(from: json.nestedDictionary(forKey: "image"), defaultValue: result.image)
        // Image Set
        result.imageSet = SwiftImageSetConfig.deserialize(from: json.nestedDictionary(forKey: "imageSet"), defaultValue: result.imageSet)
        // Image Sizes
        result.imageSizes = SwiftImageSizesConfig.deserialize(from: json.nestedDictionary(forKey: "imageSizes"), defaultValue: result.imageSizes)
        // Separator
        result.separator = SwiftSeparatorConfig.deserialize(from: json.nestedDictionary(forKey: "separator"), defaultValue: result.separator)
        // Spacing
        result.spacing = SwiftSpacingConfig.deserialize(from: json.nestedDictionary(forKey: "spacing"), defaultValue: result.spacing)
        // Adaptive Card
        result.adaptiveCard = SwiftAdaptiveCardConfig.deserialize(from: json.nestedDictionary(forKey: "adaptiveCard"), defaultValue: result.adaptiveCard)
        // Actions
        result.actions = SwiftActionsConfig.deserialize(from: json.nestedDictionary(forKey: "actions"), defaultValue: result.actions)
        // Media
        result.media = SwiftMediaConfig.deserialize(from: json.nestedDictionary(forKey: "media"), defaultValue: result.media)
        // Host Width
        result.hostWidth = SwiftHostWidthConfig.deserialize(from: json.nestedDictionary(forKey: "hostWidthBreakpoints"), defaultValue: result.hostWidth)
        // Inputs
        result.inputs = SwiftInputsConfig.deserialize(from: json.nestedDictionary(forKey: "inputs"), defaultValue: result.inputs)
        // Text Block
        result.textBlock = SwiftTextBlockConfig.deserialize(from: json.nestedDictionary(forKey: "textBlock"), defaultValue: result.textBlock)
        // Text Styles
        result.textStyles = SwiftTextStylesConfig.deserialize(from: json.nestedDictionary(forKey: "textStyles"), defaultValue: result.textStyles)
        // Rating Label Config
        result.ratingLabelConfig = SwiftRatingElementConfig.deserialize(from: json.nestedDictionary(forKey: "ratingLabel"), defaultValue: result.ratingLabelConfig)
        // Rating Input Config
        result.ratingInputConfig = SwiftRatingElementConfig.deserialize(from: json.nestedDictionary(forKey: "ratingInput"), defaultValue: result.ratingInputConfig)
        // Table
        result.table = SwiftTableConfig.deserialize(from: json.nestedDictionary(forKey: "table"), defaultValue: result.table)
        // Border Width & Corner Radius (assumed as dictionaries)
        result.borderWidth = json["borderWidth"] as? [String: UInt] ?? result.borderWidth
        result.cornerRadius = json["cornerRadius"] as? [String: UInt] ?? result.cornerRadius
        // Compound Button Config
        result.compoundButtonConfig = SwiftCompoundButtonConfig.deserialize(from: json.nestedDictionary(forKey: "compoundButton"), defaultValue: result.compoundButtonConfig)
        
        return result
    }
    
    static public func deserialize(from jsonString: String) -> SwiftHostConfig {
        let data = jsonString.data(using: .utf8) ?? Data()
        let jsonObject = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
        return SwiftHostConfig.deserialize(from: jsonObject)
    }
    
    // MARK: - Getter Methods
    
    func getFontType(_ type: SwiftFontType) -> SwiftFontTypeDefinition {
        switch type {
        case .monospace:
            return self.fontTypes.monospaceFontType
        case .defaultFont:
            fallthrough
        default:
            return self.fontTypes.defaultFontType
        }
    }
    
    func getFontFamily(for type: SwiftFontType) -> String {
        let fontTypeDef = getFontType(type)
        if !fontTypeDef.fontFamily.isEmpty {
            return fontTypeDef.fontFamily
        } else if type == .monospace {
            // Let the renderer decide a suitable monospace family.
            return ""
        } else {
            return self.fontFamily.isEmpty ? "" : self.fontFamily
        }
    }
    
    func getFontSize(for fontType: SwiftFontType, size: SwiftTextSize) -> UInt {
        var result = getFontType(fontType).fontSizes.getFontSize(for: size)
        if result == UInt.max {
            result = self.fontTypes.defaultFontType.fontSizes.getFontSize(for: size)
            if result == UInt.max {
                result = SwiftFontSizesConfig.getDefaultFontSize(for: size)
            }
        }
        return result
    }
    
    func getFontWeight(for fontType: SwiftFontType, weight: SwiftTextWeight) -> UInt {
        var result = getFontType(fontType).fontWeights.getFontWeight(for: weight)
        if result == UInt.max {
            result = self.fontTypes.defaultFontType.fontWeights.getFontWeight(for: weight)
            if result == UInt.max {
                result = SwiftFontWeightsConfig.getDefaultFontWeight(for: weight)
            }
        }
        return result
    }
    
    func getContainerStyle(for style: SwiftContainerStyle) -> SwiftContainerStyleDefinition {
        switch style {
        case .accent:
            return self.containerStyles.accentPalette
        case .attention:
            return self.containerStyles.attentionPalette
        case .emphasis:
            return self.containerStyles.emphasisPalette
        case .good:
            return self.containerStyles.goodPalette
        case .warning:
            return self.containerStyles.warningPalette
        case .default:
            fallthrough
        default:
            return self.containerStyles.defaultPalette
        }
    }
    
    private func getColor(from config: SwiftColorConfig, isSubtle: Bool) -> String {
        return isSubtle ? config.subtleColor : config.defaultColor
    }
    
    func getForegroundColor(for style: SwiftContainerStyle, color: SwiftForegroundColor, isSubtle: Bool) -> String {
        let container = getContainerStyle(for: style)
        let colorsConfig = container.foregroundColors
        let selectedColor: SwiftColorConfig
        switch color {
        case .accent:
            selectedColor = colorsConfig.accent
        case .attention:
            selectedColor = colorsConfig.attention
        case .dark:
            selectedColor = colorsConfig.dark
        case .good:
            selectedColor = colorsConfig.good
        case .light:
            selectedColor = colorsConfig.light
        case .warning:
            selectedColor = colorsConfig.warning
        case .default:
            fallthrough
        default:
            selectedColor = colorsConfig.default
        }
        return getColor(from: selectedColor, isSubtle: isSubtle)
    }
    
    func getHighlightColor(for style: SwiftContainerStyle, color: SwiftForegroundColor, isSubtle: Bool) -> String {
        let container = getContainerStyle(for: style)
        let colorsConfig = container.foregroundColors
        let selectedColor: SwiftColorConfig
        switch color {
        case .accent:
            selectedColor = colorsConfig.accent
        case .attention:
            selectedColor = colorsConfig.attention
        case .dark:
            selectedColor = colorsConfig.dark
        case .good:
            selectedColor = colorsConfig.good
        case .light:
            selectedColor = colorsConfig.light
        case .warning:
            selectedColor = colorsConfig.warning
        case .default:
            fallthrough
        default:
            selectedColor = colorsConfig.default
        }
        return getHighlight(from: selectedColor.highlightColors, isSubtle: isSubtle)
    }
    
    private func getHighlight(from config: SwiftHighlightColorConfig, isSubtle: Bool) -> String {
        return isSubtle ? config.subtleColor : config.defaultColor
    }
    
    func getBorderColor(for style: SwiftContainerStyle) -> String {
        return getContainerStyle(for: style).borderColor
    }
    
    func getBorderWidth(for elementType: SwiftCardElementType) -> UInt {
        let key = elementType.rawValue
        return self.borderWidth[key] ?? 1
    }
    
    func getCornerRadius(for elementType: SwiftCardElementType) -> UInt {
        let key = elementType.rawValue
        return self.cornerRadius[key] ?? 5
    }
}
