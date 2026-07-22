// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"

namespace AdaptiveCards
{
class FontSizesConfig
{
public:
    FontSizesConfig() = default;
    FontSizesConfig(unsigned int s, unsigned int d, unsigned int m, unsigned int l, unsigned int xl) :
        _small(s), _default(d), _medium(m), _large(l), _extraLarge(xl)
    {
    }

    static FontSizesConfig Deserialize(const Json::Value& json, const FontSizesConfig& defaultValue);
    static unsigned int GetDefaultFontSize(TextSize size);
    unsigned int GetFontSize(TextSize size) const;
    void SetFontSize(TextSize size, unsigned int value);

private:
    // std::numeric_limits<unsigned int>::max() used to check if value was defined
    unsigned int _small = std::numeric_limits<unsigned int>::max();
    unsigned int _default = std::numeric_limits<unsigned int>::max();
    unsigned int _medium = std::numeric_limits<unsigned int>::max();
    unsigned int _large = std::numeric_limits<unsigned int>::max();
    unsigned int _extraLarge = std::numeric_limits<unsigned int>::max();
};

class FontWeightsConfig
{
public:
    FontWeightsConfig() = default;
    FontWeightsConfig(unsigned int lighterWeight, unsigned int defaultWeight, unsigned int bolderWeight) :
        _lighter(lighterWeight), _default(defaultWeight), _bolder(bolderWeight)
    {
    }
    static FontWeightsConfig Deserialize(const Json::Value& json, const FontWeightsConfig& defaultValue);
    static unsigned int GetDefaultFontWeight(TextWeight weight);
    unsigned int GetFontWeight(TextWeight weight) const;
    void SetFontWeight(TextWeight weight, unsigned int value);

private:
    // std::numeric_limits<unsigned int>::max() used to check if value was defined
    unsigned int _lighter = std::numeric_limits<unsigned int>::max();
    unsigned int _default = std::numeric_limits<unsigned int>::max();
    unsigned int _bolder = std::numeric_limits<unsigned int>::max();
};

struct FontTypeDefinition
{
    std::string fontFamily;
    FontSizesConfig fontSizes;
    FontWeightsConfig fontWeights;

    static FontTypeDefinition Deserialize(const Json::Value& json, const FontTypeDefinition& defaultValue);
};

struct FontTypesDefinition
{
    FontTypeDefinition defaultFontType;
    FontTypeDefinition monospaceFontType;

    static FontTypesDefinition Deserialize(const Json::Value& json, const FontTypesDefinition& defaultValue);
};

struct HighlightColorConfig
{
    std::string defaultColor;
    std::string subtleColor;

    static HighlightColorConfig Deserialize(const Json::Value& json, const HighlightColorConfig& defaultValue);
};

struct ColorConfig
{
    std::string defaultColor;
    std::string subtleColor;

    HighlightColorConfig highlightColors;

    static ColorConfig Deserialize(const Json::Value& json, const ColorConfig& defaultValue);
};

// TODO: microsoft/AdaptiveCards#3460 each ColorConfig below needs a HighlightColorConfig initializer
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-field-initializers"
#endif
struct ColorsConfig
{
    ColorConfig defaultColor = {"#FF000000", "#B2000000"};
    ColorConfig accent = {"#FF0000FF", "#B20000FF"};
    ColorConfig dark = {"#FF101010", "#B2101010"};
    ColorConfig light = {"#FFFFFFFF", "#B2FFFFFF"};
    ColorConfig good = {"#FF008000", "#B2008000"};
    ColorConfig warning = {"#FFFFD700", "#B2FFD700"};
    ColorConfig attention = {"#FF8B0000", "#B28B0000"};

    static ColorsConfig Deserialize(const Json::Value& json, const ColorsConfig& defaultValue);
};
#ifdef __clang__
#pragma clang diagnostic pop
#endif

struct TextStyleConfig
{
    TextWeight weight = TextWeight::Default;
    TextSize size = TextSize::Default;
    bool isSubtle = false;
    ForegroundColor color = ForegroundColor::Default;
    FontType fontType = FontType::Default;

    static TextStyleConfig Deserialize(const Json::Value& json, const TextStyleConfig& defaultValue);
};

struct FactSetTextConfig : TextStyleConfig
{
    bool wrap = true;
    unsigned int maxWidth = ~0U;

    static FactSetTextConfig Deserialize(const Json::Value& json, const FactSetTextConfig& defaultValue);
};

struct RatingStarCofig
{
    std::string marigoldColor = "#EAA300";
    std::string neutralColor = "#242424";

    static RatingStarCofig Deserialize(const Json::Value& json, const RatingStarCofig& defaultValue);
};

struct RatingElementConfig
{
    RatingStarCofig filledStar = {
        "#EAA300",
        "#212121"
    };

    RatingStarCofig emptyStar = {
        "#EAA300",
        "#212121"
    };

    std::string ratingTextColor = "#000000";
    std::string countTextColor = "#000000";

    static RatingElementConfig Deserialize(const Json::Value& json, const RatingElementConfig& defaultValue);
};

struct TextStylesConfig
{
    TextStyleConfig heading = {TextWeight::Bolder, TextSize::Large, false, ForegroundColor::Default, FontType::Default};
    TextStyleConfig columnHeader = {TextWeight::Bolder, TextSize::Default, false, ForegroundColor::Default, FontType::Default};

    static TextStylesConfig Deserialize(const Json::Value& json, const TextStylesConfig& defaultValue);
};

struct SpacingConfig
{
    unsigned int smallSpacing = 3;
    unsigned int defaultSpacing = 8;
    unsigned int mediumSpacing = 20;
    unsigned int largeSpacing = 30;
    unsigned int extraLargeSpacing = 40;
    unsigned int paddingSpacing = 20;
    unsigned int extraSmallSpacing = 4;
    static SpacingConfig Deserialize(const Json::Value& json, const SpacingConfig& defaultValue);
};

struct SeparatorConfig
{
    unsigned int lineThickness = 1;
    std::string lineColor = "#B2000000";
    std::string lineColorDefault = "#B2000000";
    std::string lineColorEmphasis = "#B2000000";
    std::string lineColorGood = "#B2000000";
    std::string lineColorAttention = "#B2000000";
    std::string lineColorWarning = "#B2000000";
    std::string lineColorAccent = "#B2000000";

    static SeparatorConfig Deserialize(const Json::Value& json, const SeparatorConfig& defaultValue);
};

struct ImageSizesConfig
{
    unsigned int smallSize = 80;
    unsigned int mediumSize = 120;
    unsigned int largeSize = 180;

    static ImageSizesConfig Deserialize(const Json::Value& json, const ImageSizesConfig& defaultValue);
};

struct ImageSetConfig
{
    ImageSize imageSize = ImageSize::Auto;
    unsigned int maxImageHeight = 100;

    static ImageSetConfig Deserialize(const Json::Value& json, const ImageSetConfig& defaultValue);
};

struct ImageConfig
{
    ImageSize imageSize = ImageSize::Auto;

    static ImageConfig Deserialize(const Json::Value& json, const ImageConfig& defaultValue);
};

struct AdaptiveCardConfig
{
    bool allowCustomStyle = true;

    static AdaptiveCardConfig Deserialize(const Json::Value& json, const AdaptiveCardConfig& defaultValue);
};

struct FactSetConfig
{
    FactSetTextConfig title{TextWeight::Bolder, TextSize::Default, false, ForegroundColor::Default, FontType::Default, true, 150};
    FactSetTextConfig value{TextWeight::Default, TextSize::Default, false, ForegroundColor::Default, FontType::Default, true, ~0U};
    unsigned int spacing = 10;

    static FactSetConfig Deserialize(const Json::Value& json, const FactSetConfig& defaultValue);
};

struct ContainerStyleDefinition
{
    std::string backgroundColor = "#FFFFFFFF";
    std::string borderColor = "#FF7F7F7F";
    ColorsConfig foregroundColors;

    static ContainerStyleDefinition Deserialize(const Json::Value& json, const ContainerStyleDefinition& defaultValue);
};

struct ContainerStylesDefinition
{
    ContainerStyleDefinition defaultPalette = {
        "#FFFFFFFF",
        "#FF7F7F7F",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFFFD700", "#B2FFD700", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        }};
    ContainerStyleDefinition emphasisPalette = {
        "#08000000",
        "#08000000",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFFFD700", "#B2FFD700", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        }};
    ContainerStyleDefinition goodPalette = {
        "#FFD5F0DD",
        "#FF7F7F7F",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFA60000", "#B2FFA600", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        }};
    ContainerStyleDefinition attentionPalette = {
        "#F7E9E9",
        "#FF7F7F7F",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFA60000", "#B2FFA600", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        },
    };
    ContainerStyleDefinition warningPalette = {
        "#F7F7DF",
        "#FF7F7F7F",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFA60000", "#B2FFA600", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        }};
    ContainerStyleDefinition accentPalette = {
        "#DCE5F7",
        "#FF7F7F7F",
        {
            // Foreground Colors
            {"#FF000000", "#B2000000", {"#FFFFFF00", "#FFFFFFE0"}}, // defaultColor
            {"#FF0000FF", "#B20000FF", {"#FFFFFF00", "#FFFFFFE0"}}, // accent
            {"#FF101010", "#B2101010", {"#FFFFFF00", "#FFFFFFE0"}}, // dark
            {"#FFFFFFFF", "#B2FFFFFF", {"#FFFFFF00", "#FFFFFFE0"}}, // light
            {"#FF008000", "#B2008000", {"#FFFFFF00", "#FFFFFFE0"}}, // good
            {"#FFA60000", "#B2FFA600", {"#FFFFFF00", "#FFFFFFE0"}}, // warning
            {"#FF8B0000", "#B28B0000", {"#FFFFFF00", "#FFFFFFE0"}}  // attention
        }};

    static ContainerStylesDefinition Deserialize(const Json::Value& json, const ContainerStylesDefinition& defaultValue);
};

struct ShowCardActionConfig
{
    ActionMode actionMode = ActionMode::Inline;
    ContainerStyle style = ContainerStyle::Emphasis;
    unsigned int inlineTopMargin = 16;

    static ShowCardActionConfig Deserialize(const Json::Value& json, const ShowCardActionConfig& defaultValue);
};

struct PopoverConfig {
    std::string backgroundColor = "#FFFFFF";
    std::string tintColor = "#000000";

    static PopoverConfig Deserialize(const Json::Value& json, const PopoverConfig& defaultValue);
};

struct ActionsConfig
{
    ShowCardActionConfig showCard;
    PopoverConfig popover;
    ActionsOrientation actionsOrientation = ActionsOrientation::Horizontal;
    ActionAlignment actionAlignment = ActionAlignment::Stretch;
    unsigned int buttonSpacing = 10;
    unsigned int maxActions = 5;
    Spacing spacing = Spacing::Default;
    IconPlacement iconPlacement = IconPlacement::AboveTitle;
    unsigned int iconSize = 16;

    static ActionsConfig Deserialize(const Json::Value& json, const ActionsConfig& defaultValue);
};

struct InputLabelConfig
{
    ForegroundColor color = ForegroundColor::Default;
    bool isSubtle = false;
    TextSize size = TextSize::Default;
    std::string suffix = std::string();
    TextWeight weight = TextWeight::Default;

    static InputLabelConfig Deserialize(const Json::Value& json, const InputLabelConfig& defaultValue);
};

struct LabelConfig
{
    Spacing inputSpacing = Spacing::Default;
    InputLabelConfig requiredInputs;
    InputLabelConfig optionalInputs;

    static LabelConfig Deserialize(const Json::Value& json, const LabelConfig& defaultValue);
};

struct ErrorMessageConfig
{
    TextSize size = TextSize::Default;
    Spacing spacing = Spacing::Default;
    TextWeight weight = TextWeight::Default;

    static ErrorMessageConfig Deserialize(const Json::Value& json, const ErrorMessageConfig& defaultValue);
};

struct InputsConfig
{
    LabelConfig label;
    ErrorMessageConfig errorMessage;

    static InputsConfig Deserialize(const Json::Value& json, const InputsConfig& defaultValue);
};

struct IconsConfig
{
    unsigned int iconSize = 16;
    unsigned int iconPadding = 10;

    static IconsConfig Deserialize(const Json::Value& json, const IconsConfig& defaultValue);
};

struct MediaConfig
{
    std::string defaultPoster;
    std::string playButton;
    bool allowInlinePlayback = true;

    static MediaConfig Deserialize(const Json::Value& json, const MediaConfig& defaultValue);
};

struct HostWidthConfig
{
    unsigned int veryNarrow = 0;
    unsigned int narrow = 0;
    unsigned int standard = 0;

    static HostWidthConfig Deserialize(const Json::Value& json, const HostWidthConfig& defaultValue);
};

struct TextBlockConfig
{
    unsigned int headingLevel = 2;

    static TextBlockConfig Deserialize(const Json::Value& json, const TextBlockConfig& defaultValue);
};

struct CitationBlock {
    std::string iconColor = "#212121";
    std::string textColor = "#E1E1E1";
    std::string backgroundColor = "#141414";
    std::string borderColor = "#292929";
    std::string dividerColor = "#E1E1E1";
    std::string bottomSheetTextColor = "#E1E1E1";
    std::string bottomSheetKeywordsColor = "#919191";
    std::string bottomSheetMoreDetailColor = "#7F85F5";
    std::string bottomSheetBackgroundColor = "#000000";

    static CitationBlock Deserialize(const Json::Value& json, const CitationBlock& defaultValue);
};

struct TableConfig
{
    unsigned int cellSpacing = 8;
    static TableConfig Deserialize(const Json::Value& json, const TableConfig& defaultValue);
};

struct BadgeConfig
{
    std::string backgroundColor = "#5B5FC7";
    static BadgeConfig Deserialize(const Json::Value& json, const BadgeConfig& defaultValue);
};

struct CompoundButtonConfig
{
    BadgeConfig badgeConfig;
    std::string borderColor = "#E1E1E1";
    static CompoundButtonConfig Deserialize(const Json::Value& json, const CompoundButtonConfig& defaultValue);
};

struct PageControlConfig
{
    std::string selectedTintColor = "#5B5FC7";
    std::string unselectedTintColor = "#6E6E6E";
    static PageControlConfig Deserialize(const Json::Value& json, const PageControlConfig& defaultValue);
};

struct BadgeAppearanceDefinition
{
    std::string backgroundColor = "#212121";
    std::string strokeColor = "#212121";
    std::string textColor = "#ffffff";

    static BadgeAppearanceDefinition Deserialize(const Json::Value& json, const BadgeAppearanceDefinition& defaultValue);
};

struct BadgeStyleDefinition
{
    BadgeAppearanceDefinition filledStyle;
    BadgeAppearanceDefinition tintStyle;

    static BadgeStyleDefinition Deserialize(const Json::Value& json, const BadgeStyleDefinition& defaultValue);
};

struct BadgeStylesDefinition
{
    BadgeStyleDefinition defaultPalette = {
        {
            "#212121",
            "#212121",
            "#ffffff"
        },
        {
            "#6e6e6e",
            "#6e6e6e",
            "#ffffff"
        }
    };
    BadgeStyleDefinition accentPalette = {
        {
            "#5b5fc7",
            "#5b5fc7",
            "#ffffff"
            },
        {
            "#e8ebfa",
            "#e1e1e1",
            "#5b5fc7"
        }
    };
    BadgeStyleDefinition attentionPalette = {
        {
            "#d92c2c",
            "#d92c2c",
            "#ffffff"
        },
        {
            "#f9d9d9",
            "#e1e1e1",
            "#d92c2c"
        }
    };
    BadgeStyleDefinition goodPalette = {
        {
            "#0f7a0b",
            "#0f7a0b",
            "#ffffff"
        },
        {
            "#e7f2da",
            "#e1e1e1",
            "#0f7a0b"
        }
    };

    BadgeStyleDefinition informativePalette = {
        {
            "#ffffff",
            "#ffffff",
            "#212121"
        },
        {
            "#ffffff",
            "#e1e1e1",
            "#212121"
        }
    };

    BadgeStyleDefinition subtlePalette = {
        {
            "#f1f1f1",
            "#f1f1f1",
            "#6e6e6e"
        },
        {
            "#f1f1f1",
            "#e1e1e1",
            "#6e6e6e"
        }
    };

    BadgeStyleDefinition warningPalette = {
        {
            "#835c00",
            "#835c00",
            "#ffffff"
        },
        {
            "#fbf6d9",
            "#e1e1e1",
            "#835C00"
        }
    };

    static BadgeStylesDefinition Deserialize(const Json::Value& json, const BadgeStylesDefinition& defaultValue);
};

class HostConfig
{
public:
    HostConfig() = default;
    static HostConfig Deserialize(const Json::Value& json);
    static HostConfig DeserializeFromString(const std::string& jsonString);

    FontTypeDefinition GetFontType(FontType fontType) const;
    std::string GetFontFamily(FontType fontType) const;
    unsigned int GetFontSize(FontType fontType, TextSize size) const;
    unsigned int GetFontWeight(FontType fontType, TextWeight weight) const;

    std::string GetBackgroundColor(ContainerStyle style) const;
    std::string GetForegroundColor(ContainerStyle style, ForegroundColor color, bool isSubtle) const;
    std::string GetHighlightColor(ContainerStyle style, ForegroundColor color, bool isSubtle) const;
    std::string GetSeparatorColor(ContainerStyle style, SeparatorConfig separator) const;
    std::string GetBorderColor(ContainerStyle style) const;
    unsigned int GetBorderWidth(CardElementType elementType) const;
    unsigned int GetCornerRadius(CardElementType elementType) const;

    std::string GetFontFamily() const;
    void SetFontFamily(const std::string& value);

    FontSizesConfig GetFontSizes() const;
    void SetFontSizes(const FontSizesConfig value);

    FontWeightsConfig GetFontWeights() const;
    void SetFontWeights(const FontWeightsConfig value);

    FontTypesDefinition GetFontTypes() const;
    void SetFontTypes(const FontTypesDefinition value);

    bool GetSupportsInteractivity() const;
    void SetSupportsInteractivity(const bool value);

    std::string GetImageBaseUrl() const;
    void SetImageBaseUrl(const std::string& value);

    ImageSizesConfig GetImageSizes() const;
    void SetImageSizes(const ImageSizesConfig value);

    ImageConfig GetImage() const;
    void SetImage(const ImageConfig value);

    SeparatorConfig GetSeparator() const;
    void SetSeparator(const SeparatorConfig value);

    SpacingConfig GetSpacing() const;
    void SetSpacing(const SpacingConfig value);

    AdaptiveCardConfig GetAdaptiveCard() const;
    void SetAdaptiveCard(const AdaptiveCardConfig value);

    ImageSetConfig GetImageSet() const;
    void SetImageSet(const ImageSetConfig value);

    FactSetConfig GetFactSet() const;
    void SetFactSet(const FactSetConfig value);

    ActionsConfig GetActions() const;
    void SetActions(const ActionsConfig value);

    ContainerStylesDefinition GetContainerStyles() const;
    void SetContainerStyles(const ContainerStylesDefinition value);

    MediaConfig GetMedia() const;
    void SetMedia(const MediaConfig value);

    InputsConfig GetInputs() const;
    void SetInputs(const InputsConfig value);

    IconsConfig GetIcons() const;
    void SetIcons(const IconsConfig value);

    HostWidthConfig getHostWidth() const;
    void SetHostWidth(const HostWidthConfig value);

    TextStylesConfig GetTextStyles() const;
    void SetTextStyles(const TextStylesConfig value);

    RatingElementConfig GetRatingLabelConfig() const;
    void SetRatingLabelConfig(const RatingElementConfig value);

    RatingElementConfig GetRatingInputConfig() const;
    void SetRatingInputConfig(const RatingElementConfig value);

    TextBlockConfig GetTextBlock() const;
    void SetTextBlock(const TextBlockConfig value);

    CitationBlock GetCitationBlock() const;

    TableConfig GetTable() const;
    void SetTable(const TableConfig value);

    CompoundButtonConfig GetCompoundButtonConfig() const;
    void SetCompoundButtonConfig(const CompoundButtonConfig value);

    PageControlConfig GetPageControlConfig() const;
    void SetPageControlConfig(const PageControlConfig value);

    BadgeStylesDefinition GetBadgeStyles() const;
    void SetBadgeStyles(const BadgeStylesDefinition value);

private:
    const ContainerStyleDefinition& GetContainerStyle(ContainerStyle style) const;
    const ColorConfig& GetContainerColorConfig(const ColorsConfig& colors, ForegroundColor color) const;
    const BadgeStyleDefinition& GetBadgeStyle(BadgeStyle style) const;

    std::string _fontFamily;
    FontSizesConfig _fontSizes;
    FontWeightsConfig _fontWeights;
    FontTypesDefinition _fontTypes;
    bool _supportsInteractivity = true;
    std::string _imageBaseUrl;
    ImageSizesConfig _imageSizes;
    ImageConfig _image;
    SeparatorConfig _separator;
    SpacingConfig _spacing;
    AdaptiveCardConfig _adaptiveCard;
    ImageSetConfig _imageSet;
    FactSetConfig _factSet;
    ActionsConfig _actions;
    ContainerStylesDefinition _containerStyles;
    MediaConfig _media;
    InputsConfig _inputs;
    IconsConfig _icons;
    HostWidthConfig _hostWidth;
    TextBlockConfig _textBlock;
    CitationBlock _citationBlock;
    TextStylesConfig _textStyles;
    RatingElementConfig _ratingInputConfig;
    RatingElementConfig _ratingLabelConfig;
    TableConfig _table;
    Json::Value _borderWidth;
    Json::Value _cornerRadius;
    CompoundButtonConfig _compoundButtonConfig;
    PageControlConfig _pageControlConfig;
    BadgeStylesDefinition _badgeStyles;
};
} // namespace AdaptiveCards
