//
//  ACOEnums
//  ACOEnums.h
//
//  Copyright © 2021 Microsoft. All rights reserved.
//
//
#include <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ACRActionType) {
    ACRExecute = 1,
    ACROpenUrl,
    ACRPopover,
    ACRShowCard,
    ACRSubmit,
    ACRToggleVisibility,
    ACROverflow,
    ACRUnknownAction = 8,
};

typedef NS_ENUM(NSInteger, ACRIconPlacement) {
    ACRAboveTitle = 0,
    ACRLeftOfTitle,
    ACRRightOfTitle,
    ACRNoTitle,
};

typedef NS_ENUM(NSInteger, ACRCardElementType) {
    // The order of enums must match with ones in enums.h
    ACRActionSet = 0,
    ACRAdaptiveCard,
    ACRChoiceInput,
    ACRChoiceSetInput,
    ACRColumn,
    ACRColumnSet,
    ACRContainer,
    ACRCustom,
    ACRDateInput,
    ACRFact,
    ACRFactSet,
    ACRImage,
    ACRIcon,
    ACRImageSet,
    ACRMedia,
    ACRNumberInput,
    ACRRatingInput,
    ACRRatingLabel,
    ACRRichTextBlock,
    ACRTable,
    ACRTableCell,
    ACRTableRow,
    ACRTextBlock,
    ACRTextInput,
    ACRTimeInput,
    ACRToggleInput,
    ACRCompoundButton,
    ACRCarousel,
    ACRCarouselPage,
    ACRBadge,
    ACRProgressBar,
    ACRProgressRing,
    ACRUnknown
};

typedef NS_ENUM(NSInteger, ACRContainerStyle) {
    ACRNone,
    ACRDefault,
    ACREmphasis,
    ACRGood,
    ACRAttention,
    ACRWarning,
    ACRAccent
};

typedef NS_ENUM(NSInteger, ACRTheme) {
    ACRThemeNone = 0,
    ACRThemeLight,
    ACRThemeDark
};

typedef NS_ENUM(NSInteger, ACRBleedDirection) {
    ACRBleedRestricted = 0x0000,
    ACRBleedToLeadingEdge = 0x0001,
    ACRBleedToTrailingEdge = 0x0010,
    ACRBleedToTopEdge = 0x0100,
    ACRBleedToBottomEdge = 0x1000,
    ACRBleedToAll = ACRBleedToLeadingEdge | ACRBleedToTrailingEdge | ACRBleedToTopEdge | ACRBleedToBottomEdge
};

typedef NS_ENUM(NSInteger, ACRRtl) {
    ACRRtlNone,
    ACRRtlRTL,
    ACRRtlLTR
};

typedef NS_ENUM(NSUInteger, ACRHorizontalAlignment) {
    ACRLeft = 0,
    ACRCenter,
    ACRRight
};

typedef NS_ENUM(NSUInteger, ACRHorizontalContentAlignment) {
    ACRHorizontalContentAlignmentLeft = 0,
    ACRHorizontalContentAlignmentCenter,
    ACRHorizontalContentAlignmentRight
};

typedef NS_ENUM(NSUInteger, ACRImageFitMode) {
    ACRImageFitModeFill,
    ACRImageFitModeContain,
    ACRImageFitModeCover
};

typedef NS_ENUM(NSUInteger, ACRRatingSize) {
    ACRMedium = 0,
    ACRLarge
};

typedef NS_ENUM(NSUInteger, ACRRatingColor) {
    ACRNeutral = 0,
    ACRMarigold
};

typedef NS_ENUM(NSUInteger, ACRRatingStyle) {
    ACRDefaultStyle = 0,
    ACRCompactStyle
};

typedef NS_ENUM(NSUInteger, ACRVerticalContentAlignment) {
    ACRVerticalContentAlignmentTop = 0,
    ACRVerticalContentAlignmentCenter,
    ACRVerticalContentAlignmentBottom
};

typedef NS_ENUM(NSUInteger, ACRHeightType) {
    ACRHeightAuto = 0,
    ACRHeightStretch
};

typedef NS_ENUM(NSUInteger, ACRIconPosition) {
   ACRBeforePosition = 0,
   ACRAfterPosition
};

typedef NS_ENUM(NSUInteger, ACRShape) {
    ACRSquare = 0,
    ACRRounded,
    ACRCircular
};

typedef NS_ENUM(NSUInteger, ACRBadgeStyle) {
    ACRBadgeDefaultStyle = 0,
    ACRBadgeAccentStyle,
    ACRBadgeAttentionStyle,
    ACRBadgeGoodStyle,
    ACRBadgeInformativeStyle,
    ACRBadgeSubtleStyle,
    ACRBadgeWarningStyle
};

typedef NS_ENUM(NSUInteger, ACRBadgeSize) {
    ACRMediumSize = 0,
    ACRLargeSize,
    ACRExtraLargeSize
};

typedef NS_ENUM(NSUInteger, ACRBadgeAppearance) {
    ACRFilled = 0,
    ACRTint
};

typedef NS_ENUM(NSInteger, ACIcon) {
    ACIconAdobeIllustrator = 0,
    ACIconAdobePhotoshop,
    ACIconAdobeInDesign,
    ACIconAdobeFlash,
    ACIconMsWord,
    ACIconMsExcel,
    ACIconMsPowerPoint,
    ACIconMsOneNote,
    ACIconMsSharePoint,
    ACIconMsVisio,
    ACIconMsLoop,
    ACIconMsWhiteboard,
    ACIconCode,
    ACIconGif,
    ACIconCitationImage,
    ACIconPdf,
    ACIconSketch,
    ACIconSound,
    ACIconText,
    ACIconVideo,
    ACIconZip
};
