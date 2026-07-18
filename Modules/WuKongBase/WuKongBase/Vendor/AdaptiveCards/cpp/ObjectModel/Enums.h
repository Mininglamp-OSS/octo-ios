// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once
#include "pch.h"
#include "EnumMagic.h"

namespace AdaptiveCards
{
enum class AdaptiveCardSchemaKey
{
    Accent = 0,
    Action,
    ActionAlignment,
    ActionMode,
    ActionOrientation,
    ActionRole,
    ActionSet,
    ActionSetConfig,
    Actions,
    ActionsOrientation,
    AdaptiveCard,
    AllowCustomStyle,
    AllowInlinePlayback,
    AltText,
    Appearance,
    Name,
    AssociatedInputs,
    Attention,
    Authentication,
    BackgroundColor,
    BackgroundImage,
    BackgroundImageUrl,
    BaseCardElement,
    BaseContainerStyle,
    Bleed,
    Body,
    Bolder,
    BorderColor,
    Bottom,
    Badge,
    BadgeStyles,
    ButtonSpacing,
    Buttons,
    CaptionSources,
    Card,
    CellSpacing,
    Cells,
    Center,
    ChoiceSet,
    Choices,
    ChoicesData,
    ChoicesDataType,
    Color,
    ColorConfig,
    Column,
    ColumnHeader,
    ColumnSet,
    Columns,
    ConditionallyEnabled,
    ConnectionName,
    Container,
    ContainerStyles,
    BorderWidth,
    CornerRadius,
    Dark,
    Data,
    DataQuery,
    Dataset,
    DateInput,
    Default,
    DefaultPoster,
    Count,
    Description,
    ElementId,
    Emphasis,
    ErrorMessage,
    ExtraLarge,
    FactSet,
    Facts,
    Fallback,
    FallbackText,
    FillMode,
    Filled,
    FirstRowAsHeaders,
    FontFamily,
    FontSizes,
    FontType,
    FontTypes,
    FontWeights,
    ForegroundColor,
    ForegroundColors,
    Good,
    GridStyle,
    Heading,
    HeadingLevel,
    Height,
    Highlight,
    HighlightColor,
    HighlightColors,
    HorizontalAlignment,
    HorizontalCellContentAlignment,
    HostWidthBreakpoints,
    IconPadding,
    IconPlacement,
    Icons,
    IconSize,
    IconUrl,
    Id,
    Image,
    Icon,
    IconPosition,
    ImageBaseUrl,
    ImageSet,
    ImageSize,
    ImageSizes,
    Images,
    Informative,
    InlineAction,
    InlineTopMargin,
    Inlines,
    InputSpacing,
    Inputs,
    IsEnabled,
    IsMultiSelect,
    IsMultiline,
    ShowBorder,
    RoundedCorners,
    IsRequired,
    IsSelected,
    IsSubtle,
    IsVisible,
    Italic,
    Items,
    Label,
    Language,
    Large,
    Left,
    Light,
    Lighter,
    LineColor,
    LineColorDefault,
    LineColorEmphasis,
    LineColorGood,
    LineColorAttention,
    LineColorWarning,
    LineColorAccent,
    LineThickness,
    Max,
    MaxActions,
    MaxImageHeight,
    MaxLength,
    MaxLines,
    MaxWidth,
    Media,
    Medium,
    MetaData,
    Method,
    MimeType,
    Min,
    MinHeight,
    Mode,
    Monospace,
    Narrow,
    NumberInput,
    RatingInput,
    RatingLabel,
    OptionalInputs,
    Padding,
    Placeholder,
    PlayButton,
    Poster,
    ProviderId,
    Refresh,
    Regex,
    Repeat,
    RepeatHorizontally,
    RepeatVertically,
    RequiredInputs,
    Requires,
    RichTextBlock,
    Right,
    Rows,
    Rtl,
    Schema,
    SelectAction,
    Separator,
    Shape,
    ShowActionMode,
    ShowCard,
    ShowCardActionConfig,
    ShowGridLines,
    Size,
    Small,
    Sources,
    Spacing,
    SpacingDefinition,
    Speak,
    Standard,
    Stretch,
    Strikethrough,
    StrokeColor,
    Style,
    Subtle,
    Suffix,
    SupportsInteractivity,
    Table,
    TableCell,
    TableRow,
    TargetElements,
    Layout,
    ItemFit,
    RowSpacing,
    ColumnSpacing,
    ItemWidth,
    MinItemWidth,
    MaxItemWidth,
    HorizontalItemsAlignment,
    Row,
    RowSpan,
    ColumnSpan,
    AreaGridName,
    Areas,
    Layouts,
    TargetInputIds,
    TargetWidth,
    Text,
    TextBlock,
    TextConfig,
    TextInput,
    TextStyles,
    Tint,
    MarigoldColor,
    NeutralColor,
    FilledStar,
    EmptyStar,
    RatingTextColor,
    CountTextColor,
    TextColor,
    TextWeight,
    Thickness,
    TimeInput,
    Title,
    ToggleInput,
    TokenExchangeResource,
    Tooltip,
    Top,
    Type,
    Underline,
    Uri,
    Url,
    UserIds,
    Value,
    ValueChangedAction,
    ValueChangedActionType,
    ValueOff,
    ValueOn,
    Verb,
    VeryNarrow,
    Version,
    VerticalAlignment,
    VerticalCellContentAlignment,
    VerticalContentAlignment,
    Warning,
    WebUrl,
    Weight,
    Width,
    Wrap,
    CompoundButton,
    CarouselPage,
    Pages,
    PageAnimation,
    PageControl,
    SelectedTintColor,
    ExtraSmall,
    MenuActions,
    ThemedIconUrls,
    ThemedUrls,
    Theme,
    TintColor,
    LabelPosition,
    Content,
    DisplayArrow,
    MaxPopoverWidth,
    Position,
    Popover,
    ImageFitMode,
    HorizontalContentAlignment,
    LabelFor,
    Resources,
    Strings,
    DefaultValue,
    LocalizedValues,
    Abstract,
    Keywords,
    References,
    ReferenceIndex,
    CitationBlock,
    DividerColor,
    IconColor,
    BottomSheetTextColor,
    BottomSheetKeywordsColor,
    BottomSheetMoreDetailColor,
    BottomSheetBackgroundColor
};

DECLARE_ADAPTIVECARD_ENUM(AdaptiveCardSchemaKey);

enum class CardElementType
{
    // When the order of existing enums are changed, corresponding changes are needed in iOS (ACOBaseCardElement.h)
    ActionSet = 0,
    AdaptiveCard,
    ChoiceInput,
    ChoiceSetInput,
    Column,
    ColumnSet,
    Container,
    Custom,
    DateInput,
    Fact,
    FactSet,
    Image,
    Icon,
    ImageSet,
    Media,
    NumberInput,
    RatingInput,
    RatingLabel,
    RichTextBlock,
    Table,
    TableCell,
    TableRow,
    TextBlock,
    TextInput,
    TimeInput,
    ToggleInput,
    CompoundButton,
    Carousel,
    CarouselPage,
    Badge,
    ProgressBar,
    ProgressRing,
    Unknown
};
DECLARE_ADAPTIVECARD_ENUM(CardElementType);

enum class InlineElementType
{
    TextRun = 0,
    CitationRun,
    IconRun,
    ImageRun
};
DECLARE_ADAPTIVECARD_ENUM(InlineElementType);

enum class TextStyle
{
    Default = 0,
    Heading
};
DECLARE_ADAPTIVECARD_ENUM(TextStyle);

enum class TextSize
{
    Small = 0,
    Default,
    Medium,
    Large,
    ExtraLarge
};
DECLARE_ADAPTIVECARD_ENUM(TextSize);

enum class TextWeight
{
    Lighter = 0,
    Default,
    Bolder
};
DECLARE_ADAPTIVECARD_ENUM(TextWeight);

enum class FontType
{
    Default = 0,
    Monospace
};
DECLARE_ADAPTIVECARD_ENUM(FontType);

enum class ForegroundColor
{
    Default = 0,
    Dark,
    Light,
    Accent,
    Good,
    Warning,
    Attention
};
DECLARE_ADAPTIVECARD_ENUM(ForegroundColor);

enum class HorizontalAlignment
{
    Left = 0,
    Center,
    Right
};
DECLARE_ADAPTIVECARD_ENUM(HorizontalAlignment);

enum class HorizontalContentAlignment {
    Left = 0,
    Center,
    Right
};
DECLARE_ADAPTIVECARD_ENUM(HorizontalContentAlignment);

enum class VerticalAlignment {
    Top = 0,
    Center,
    Bottom
};
DECLARE_ADAPTIVECARD_ENUM(VerticalAlignment);

enum class VerticalContentAlignment {
    Top = 0,
    Center,
    Bottom
};
DECLARE_ADAPTIVECARD_ENUM(VerticalContentAlignment);

enum class IconSize
{
    xxSmall = 0,
    xSmall,
    Small,
    Standard,
    Medium,
    Large,
    xLarge,
    xxLarge
};
DECLARE_ADAPTIVECARD_ENUM(IconSize);

enum class IconStyle
{
    Regular = 0,
    Filled
};
DECLARE_ADAPTIVECARD_ENUM(IconStyle);

enum class ImageFillMode
{
    Cover = 0,
    RepeatHorizontally,
    RepeatVertically,
    Repeat
};
DECLARE_ADAPTIVECARD_ENUM(ImageFillMode);

enum class ItemFit
{
    Fit = 0,
    Fill,
};
DECLARE_ADAPTIVECARD_ENUM(ItemFit);

enum class LayoutContainerType
{
    None = 0,
    Stack,
    Flow,
    AreaGrid
};
DECLARE_ADAPTIVECARD_ENUM(LayoutContainerType);

enum class ImageStyle
{
    Default = 0,
    Person,
    RoundedCorners
};
DECLARE_ADAPTIVECARD_ENUM(ImageStyle);

enum class ImageSize
{
    None = 0,
    Auto,
    Stretch,
    Small,
    Medium,
    Large,
};
DECLARE_ADAPTIVECARD_ENUM(ImageSize);

enum class ImageFitMode {
    Cover,
    Contain,
    Fill
};
DECLARE_ADAPTIVECARD_ENUM(ImageFitMode);

enum class TextInputStyle
{
    Text = 0,
    Tel,
    Url,
    Email,
    Password,
};
DECLARE_ADAPTIVECARD_ENUM(TextInputStyle);

enum class ActionType
{
    Unsupported = 0,
    Execute,
    OpenUrl,
    Popover,
    ShowCard,
    Submit,
    ToggleVisibility,
    Custom,
    UnknownAction,
    Overflow
};
DECLARE_ADAPTIVECARD_ENUM(ActionType);

enum class ActionAlignment
{
    Left = 0,
    Center,
    Right,
    Stretch,
};
DECLARE_ADAPTIVECARD_ENUM(ActionAlignment);

enum class AssociatedInputs
{
    Auto = 0,
    None
};
DECLARE_ADAPTIVECARD_ENUM(AssociatedInputs);

enum class ChoiceSetStyle
{
    Compact = 0,
    Expanded,
    Filtered
};
DECLARE_ADAPTIVECARD_ENUM(ChoiceSetStyle);

enum class SeparatorThickness
{
    Default = 0,
    Thick,
};
DECLARE_ADAPTIVECARD_ENUM(SeparatorThickness);

enum class Spacing
{
    Default = 0,
    None,
    ExtraSmall,
    Small,
    Medium,
    Large,
    ExtraLarge,
    Padding
};
DECLARE_ADAPTIVECARD_ENUM(Spacing);

enum class ActionsOrientation
{
    Vertical = 0,
    Horizontal
};
DECLARE_ADAPTIVECARD_ENUM(ActionsOrientation);

enum class ActionMode
{
    Inline = 0,
    Popup
};
DECLARE_ADAPTIVECARD_ENUM(ActionMode);

enum class ActionRole
{
    Button = 0,
    Link,
    Tab,
    Menu,
    MenuItem
};
DECLARE_ADAPTIVECARD_ENUM(ActionRole);

enum class ContainerStyle
{
    None,
    Default,
    Emphasis,
    Good,
    Attention,
    Warning,
    Accent
};
DECLARE_ADAPTIVECARD_ENUM(ContainerStyle);

enum class Mode
{
    Primary = 0,
    Secondary
};
DECLARE_ADAPTIVECARD_ENUM(Mode);

enum class ACTheme
{
    None = 0,
    Light,
    Dark
};
DECLARE_ADAPTIVECARD_ENUM(ACTheme)

enum class ErrorStatusCode
{
    InvalidJson = 0,
    RenderFailed,
    RequiredPropertyMissing,
    InvalidPropertyValue,
    UnsupportedParserOverride,
    IdCollision,
    CustomError,
};
DECLARE_ADAPTIVECARD_ENUM(ErrorStatusCode);

enum class WarningStatusCode
{
    UnknownElementType = 0,
    UnknownActionElementType,
    UnknownPropertyOnElement,
    UnknownEnumValue,
    NoRendererForType,
    InteractivityNotSupported,
    MaxActionsExceeded,
    AssetLoadFailed,
    UnsupportedSchemaVersion,
    UnsupportedMediaType,
    InvalidMediaMix,
    InvalidColorFormat,
    InvalidDimensionSpecified,
    InvalidLanguage,
    InvalidValue,
    CustomWarning,
    EmptyLabelInRequiredInput,
    RequiredPropertyMissing,
};
// No mapping to string needed

enum class DateTimePreparsedTokenFormat
{
    RegularString = 0,
    Time,
    DateCompact,
    DateShort,
    DateLong
};
// No mapping to string needed

// We have to define all possible combinations because java doesn't allow bitwise operations between enum values
// and it also limits the values an enum can have to only the values defined in the enum, so combinations wouldn't be
// allowed unless they have been explicitly declared (i.e. 0x0101 wouldn't be valid as it was not part of the declared values)
enum class ContainerBleedDirection
{
    BleedRestricted = 0x0000,
    BleedLeft = 0x0001,
    BleedRight = 0x0010,
    BleedLeftRight = 0x0011,
    BleedUp = 0x0100,
    BleedLeftUp = 0x0101,
    BleedRightUp = 0x0110,
    BleedLeftRightUp = 0x0111,
    BleedDown = 0x1000,
    BleedLeftDown = 0x1001,
    BleedRightDown = 0x1010,
    BleedLeftRightDown = 0x1011,
    BleedUpDown = 0x1100,
    BleedLeftUpDown = 0x1101,
    BleedRightUpDown = 0x1110,
    BleedAll = 0x1111
};

// Define bit operators so we can use ContainerBleedDirection as a bitmask
inline ContainerBleedDirection operator~(ContainerBleedDirection a)
{
    return (ContainerBleedDirection) ~(int)a;
}
inline ContainerBleedDirection operator|(ContainerBleedDirection a, ContainerBleedDirection b)
{
    return (ContainerBleedDirection)((int)a | (int)b);
}
inline ContainerBleedDirection operator&(ContainerBleedDirection a, ContainerBleedDirection b)
{
    return (ContainerBleedDirection)((int)a & (int)b);
}
inline ContainerBleedDirection& operator|=(ContainerBleedDirection& a, ContainerBleedDirection b)
{
    return (ContainerBleedDirection&)((int&)a |= (int)b);
}
inline ContainerBleedDirection& operator&=(ContainerBleedDirection& a, ContainerBleedDirection b)
{
    return (ContainerBleedDirection&)((int&)a &= (int)b);
}

// No mapping to string needed

enum class IconPlacement
{
    AboveTitle = 0,
    LeftOfTitle,
    RightOfTitle
};
DECLARE_ADAPTIVECARD_ENUM(IconPlacement);

enum class PageAnimation
{
    Slide =0,
    CrossFade,
    None
};

DECLARE_ADAPTIVECARD_ENUM(PageAnimation);

enum class HeightType
{
    Auto = 0,
    Stretch
};

DECLARE_ADAPTIVECARD_ENUM(HeightType);

enum class RatingSize
{
    Medium = 0,
    Large
};
DECLARE_ADAPTIVECARD_ENUM(RatingSize);

enum class RatingColor
{
    Neutral = 0,
    Marigold
};
DECLARE_ADAPTIVECARD_ENUM(RatingColor);

enum class RatingStyle
{
    Default = 0,
    Compact
};
DECLARE_ADAPTIVECARD_ENUM(RatingStyle);

// Important: "Content" below is a placeholder for a JSON value -- we can't perform automatic mapping.
enum class FallbackType
{
    None,
    Drop,
    Content
};

enum class HostWidth
{
    Default = 0,
    VeryNarrow = 1,
    Narrow = 2,
    Standard = 3,
    Wide = 4
};

enum class TargetWidthType
{
    Default = 0,
    VeryNarrow,
    Narrow,
    Standard,
    Wide,
    AtMostVeryNarrow,
    AtMostNarrow,
    AtMostStandard,
    AtMostWide,
    AtLeastVeryNarrow,
    AtLeastNarrow,
    AtLeastStandard,
    AtLeastWide
};
DECLARE_ADAPTIVECARD_ENUM(TargetWidthType);

enum class ValueChangedActionType
{
    ResetInputs
};
DECLARE_ADAPTIVECARD_ENUM(ValueChangedActionType);

enum class IconPosition
{
    Before,
    After
};
DECLARE_ADAPTIVECARD_ENUM(IconPosition);

enum class Shape
{
    Square,
    Rounded,
    Circular
};
DECLARE_ADAPTIVECARD_ENUM(Shape);

enum class LabelPosition {
    Above,
    Below,
    Before,
    After
};
DECLARE_ADAPTIVECARD_ENUM(LabelPosition)

enum class ProgressSize {
    Tiny,
    Small,
    Medium,
    Large
};
DECLARE_ADAPTIVECARD_ENUM(ProgressSize)

enum class BadgeStyle
{
    Default,
    Accent,
    Attention,
    Good,
    Informative,
    Subtle,
    Warning
};
DECLARE_ADAPTIVECARD_ENUM(BadgeStyle);

enum class BadgeSize
{
    Medium,
    Large,
    ExtraLarge
};
DECLARE_ADAPTIVECARD_ENUM(BadgeSize);

enum class BadgeAppearance
{
    Filled,
    Tint
};
DECLARE_ADAPTIVECARD_ENUM(BadgeAppearance);

enum class ProgressBarColor {
    Accent,
    Attention,
    Good,
    Warning
};
DECLARE_ADAPTIVECARD_ENUM(ProgressBarColor);

enum class ReferenceType {
    AdaptiveCard,
    Document
};
DECLARE_ADAPTIVECARD_ENUM(ReferenceType);

enum class ReferenceIcon {
    AdobeIllustrator,
    AdobePhotoshop,
    AdobeInDesign,
    AdobeFlash,
    MsWord,
    MsExcel,
    MsPowerPoint,
    MsOneNote,
    MsSharePoint,
    MsVisio,
    MsLoop,
    MsWhiteboard,
    Code,
    Gif,
    Image,
    Pdf,
    Sketch,
    Sound,
    Text,
    Video,
    Zip
};
DECLARE_ADAPTIVECARD_ENUM(ReferenceIcon);
}
// namespace AdaptiveCards
