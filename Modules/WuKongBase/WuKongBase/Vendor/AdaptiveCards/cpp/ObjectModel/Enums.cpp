// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"

// Auto-formatting does terrible things to this file, so turn it off.
// clang-format off
namespace AdaptiveCards
{
    DEFINE_ADAPTIVECARD_ENUM(AdaptiveCardSchemaKey, {
            {AdaptiveCardSchemaKey::Accent, "accent"},
            {AdaptiveCardSchemaKey::Action, "action"},
            {AdaptiveCardSchemaKey::ActionAlignment, "actionAlignment"},
            {AdaptiveCardSchemaKey::ActionMode, "actionMode"},
            {AdaptiveCardSchemaKey::ActionRole, "role"},
            {AdaptiveCardSchemaKey::ActionSet, "ActionSet"},
            {AdaptiveCardSchemaKey::ActionSetConfig, "actionSetConfig"},
            {AdaptiveCardSchemaKey::Actions, "actions"},
            {AdaptiveCardSchemaKey::ActionsOrientation, "actionsOrientation"},
            {AdaptiveCardSchemaKey::AdaptiveCard, "adaptiveCard"},
            {AdaptiveCardSchemaKey::AllowCustomStyle, "allowCustomStyle"},
            {AdaptiveCardSchemaKey::AllowInlinePlayback, "allowInlinePlayback"},
            {AdaptiveCardSchemaKey::AltText, "altText"},
            {AdaptiveCardSchemaKey::Appearance, "appearance"},
            {AdaptiveCardSchemaKey::Name, "name"},
            {AdaptiveCardSchemaKey::AssociatedInputs, "associatedInputs"},
            {AdaptiveCardSchemaKey::Attention, "attention"},
            {AdaptiveCardSchemaKey::Authentication, "authentication"},
            {AdaptiveCardSchemaKey::BackgroundColor, "backgroundColor"},
            {AdaptiveCardSchemaKey::BackgroundImage, "backgroundImage"},
            {AdaptiveCardSchemaKey::BackgroundImageUrl, "backgroundImageUrl"},
            {AdaptiveCardSchemaKey::BaseCardElement, "baseCardElement"},
            {AdaptiveCardSchemaKey::BaseContainerStyle, "baseContainerStyle"},
            {AdaptiveCardSchemaKey::Badge,"badge"},
            {AdaptiveCardSchemaKey::BadgeStyles, "badgeStyles"},
            {AdaptiveCardSchemaKey::Bleed, "bleed"},
            {AdaptiveCardSchemaKey::Body, "body"},
            {AdaptiveCardSchemaKey::Bolder, "bolder"},
            {AdaptiveCardSchemaKey::BorderColor, "borderColor"},
            {AdaptiveCardSchemaKey::Bottom, "bottom"},
            {AdaptiveCardSchemaKey::ButtonSpacing, "buttonSpacing"},
            {AdaptiveCardSchemaKey::Buttons, "buttons"},
            {AdaptiveCardSchemaKey::CaptionSources, "captionSources"},
            {AdaptiveCardSchemaKey::Card, "card"},
            {AdaptiveCardSchemaKey::CellSpacing, "cellSpacing"},
            {AdaptiveCardSchemaKey::Cells, "cells"},
            {AdaptiveCardSchemaKey::Center, "center"},
            {AdaptiveCardSchemaKey::ChoiceSet, "choiceSet"},
            {AdaptiveCardSchemaKey::Choices, "choices"},
            {AdaptiveCardSchemaKey::ChoicesData, "choices.data"},
            {AdaptiveCardSchemaKey::ChoicesDataType, "type"},
            {AdaptiveCardSchemaKey::Color, "color"},
            {AdaptiveCardSchemaKey::ColorConfig, "colorConfig"},
            {AdaptiveCardSchemaKey::Column, "column"},
            {AdaptiveCardSchemaKey::ColumnHeader, "columnHeader"},
            {AdaptiveCardSchemaKey::ColumnSet, "columnSet"},
            {AdaptiveCardSchemaKey::Columns, "columns"},
            {AdaptiveCardSchemaKey::ConditionallyEnabled, "conditionallyEnabled"},
            {AdaptiveCardSchemaKey::ConnectionName, "connectionName"},
            {AdaptiveCardSchemaKey::Container, "container"},
            {AdaptiveCardSchemaKey::ContainerStyles, "containerStyles"},
            {AdaptiveCardSchemaKey::BorderWidth, "borderWidth"},
            {AdaptiveCardSchemaKey::CornerRadius, "cornerRadius"},
            {AdaptiveCardSchemaKey::Dark, "dark"},
            {AdaptiveCardSchemaKey::Data, "data"},
            {AdaptiveCardSchemaKey::DataQuery, "Data.Query"},
            {AdaptiveCardSchemaKey::Dataset, "dataset"},
            {AdaptiveCardSchemaKey::DateInput, "dateInput"},
            {AdaptiveCardSchemaKey::Default, "default"},
            {AdaptiveCardSchemaKey::DefaultPoster, "defaultPoster"},
            {AdaptiveCardSchemaKey::Count, "count"},
            {AdaptiveCardSchemaKey::Description, "description"},
            {AdaptiveCardSchemaKey::ElementId, "elementId"},
            {AdaptiveCardSchemaKey::Emphasis, "emphasis"},
            {AdaptiveCardSchemaKey::ErrorMessage, "errorMessage"},
            {AdaptiveCardSchemaKey::ExtraLarge, "extraLarge"},
            {AdaptiveCardSchemaKey::FactSet, "factSet"},
            {AdaptiveCardSchemaKey::Facts, "facts"},
            {AdaptiveCardSchemaKey::Fallback, "fallback"},
            {AdaptiveCardSchemaKey::FallbackText, "fallbackText"},
            {AdaptiveCardSchemaKey::FillMode, "fillMode"},
            {AdaptiveCardSchemaKey::Filled, "filled"},
            {AdaptiveCardSchemaKey::FirstRowAsHeaders, "firstRowAsHeaders"},
            {AdaptiveCardSchemaKey::FontFamily, "fontFamily"},
            {AdaptiveCardSchemaKey::FontSizes, "fontSizes"},
            {AdaptiveCardSchemaKey::FontType, "fontType"},
            {AdaptiveCardSchemaKey::FontTypes, "fontTypes"},
            {AdaptiveCardSchemaKey::FontWeights, "fontWeights"},
            {AdaptiveCardSchemaKey::ForegroundColor, "foregroundColor"},
            {AdaptiveCardSchemaKey::ForegroundColors, "foregroundColors"},
            {AdaptiveCardSchemaKey::Good, "good"},
            {AdaptiveCardSchemaKey::GridStyle, "gridStyle"},
            {AdaptiveCardSchemaKey::Heading, "heading"},
            {AdaptiveCardSchemaKey::HeadingLevel, "headingLevel"},
            {AdaptiveCardSchemaKey::Height, "height"},
            {AdaptiveCardSchemaKey::Highlight, "highlight"},
            {AdaptiveCardSchemaKey::HighlightColor, "highlightColor"},
            {AdaptiveCardSchemaKey::HighlightColors, "highlightColors"},
            {AdaptiveCardSchemaKey::HorizontalAlignment, "horizontalAlignment"},
            {AdaptiveCardSchemaKey::HorizontalCellContentAlignment, "horizontalCellContentAlignment"},
            {AdaptiveCardSchemaKey::HostWidthBreakpoints, "hostWidthBreakpoints"},
            {AdaptiveCardSchemaKey::IconPadding, "iconPadding"},
            {AdaptiveCardSchemaKey::IconPlacement, "iconPlacement"},
            {AdaptiveCardSchemaKey::Icons, "icons"},
            {AdaptiveCardSchemaKey::IconPosition, "iconPosition"},
            {AdaptiveCardSchemaKey::IconSize, "iconSize"},
            {AdaptiveCardSchemaKey::IconUrl, "iconUrl"},
            {AdaptiveCardSchemaKey::Id, "id"},
            {AdaptiveCardSchemaKey::Image, "image"},
            {AdaptiveCardSchemaKey::Icon, "icon"},
            {AdaptiveCardSchemaKey::ImageBaseUrl, "imageBaseUrl"},
            {AdaptiveCardSchemaKey::ImageSet, "imageSet"},
            {AdaptiveCardSchemaKey::ImageSize, "imageSize"},
            {AdaptiveCardSchemaKey::ImageSizes, "imageSizes"},
            {AdaptiveCardSchemaKey::Images, "images"},
            {AdaptiveCardSchemaKey::Informative, "informative"},
            {AdaptiveCardSchemaKey::InlineAction, "inlineAction"},
            {AdaptiveCardSchemaKey::InlineTopMargin, "inlineTopMargin"},
            {AdaptiveCardSchemaKey::Inlines, "inlines"},
            {AdaptiveCardSchemaKey::InputSpacing, "inputSpacing"},
            {AdaptiveCardSchemaKey::Inputs, "inputs"},
            {AdaptiveCardSchemaKey::IsEnabled, "isEnabled"},
            {AdaptiveCardSchemaKey::IsMultiSelect, "isMultiSelect"},
            {AdaptiveCardSchemaKey::IsMultiline, "isMultiline"},
            {AdaptiveCardSchemaKey::ShowBorder, "showBorder"},
            {AdaptiveCardSchemaKey::RoundedCorners, "roundedCorners"},
            {AdaptiveCardSchemaKey::IsRequired, "isRequired"},
            {AdaptiveCardSchemaKey::IsSelected, "isSelected"},
            {AdaptiveCardSchemaKey::IsSubtle, "isSubtle"},
            {AdaptiveCardSchemaKey::IsVisible, "isVisible"},
            {AdaptiveCardSchemaKey::Italic, "italic"},
            {AdaptiveCardSchemaKey::Items, "items"},
            {AdaptiveCardSchemaKey::Label, "label"},
            {AdaptiveCardSchemaKey::Language, "lang"},
            {AdaptiveCardSchemaKey::Large, "large"},
            {AdaptiveCardSchemaKey::Left, "left"},
            {AdaptiveCardSchemaKey::Light, "light"},
            {AdaptiveCardSchemaKey::Lighter, "lighter"},
            {AdaptiveCardSchemaKey::LineColor, "lineColor"},
            {AdaptiveCardSchemaKey::LineColorDefault, "lineColorDefault"},
            {AdaptiveCardSchemaKey::LineColorEmphasis, "lineColorEmphasis"},
            {AdaptiveCardSchemaKey::LineColorGood, "lineColorGood"},
            {AdaptiveCardSchemaKey::LineColorAttention, "lineColorAttention"},
            {AdaptiveCardSchemaKey::LineColorWarning, "lineColorWarning"},
            {AdaptiveCardSchemaKey::LineColorAccent, "lineColorAccent"},
            {AdaptiveCardSchemaKey::LineThickness, "lineThickness"},
            {AdaptiveCardSchemaKey::Max, "max"},
            {AdaptiveCardSchemaKey::MaxActions, "maxActions"},
            {AdaptiveCardSchemaKey::MaxImageHeight, "maxImageHeight"},
            {AdaptiveCardSchemaKey::MaxLength, "maxLength"},
            {AdaptiveCardSchemaKey::MaxLines, "maxLines"},
            {AdaptiveCardSchemaKey::MaxWidth, "maxWidth"},
            {AdaptiveCardSchemaKey::Media, "media"},
            {AdaptiveCardSchemaKey::Medium, "medium"},
            {AdaptiveCardSchemaKey::MetaData, "metaData"},
            {AdaptiveCardSchemaKey::Method, "method"},
            {AdaptiveCardSchemaKey::MimeType, "mimeType"},
            {AdaptiveCardSchemaKey::Min, "min"},
            {AdaptiveCardSchemaKey::MinHeight, "minHeight"},
            {AdaptiveCardSchemaKey::Mode, "mode"},
            {AdaptiveCardSchemaKey::Monospace, "monospace"},
            {AdaptiveCardSchemaKey::Narrow, "narrow"},
            {AdaptiveCardSchemaKey::NumberInput, "numberInput"},
            {AdaptiveCardSchemaKey::RatingInput, "ratingInput"},
            {AdaptiveCardSchemaKey::RatingLabel, "ratingLabel"},
            {AdaptiveCardSchemaKey::OptionalInputs, "optionalInputs"},
            {AdaptiveCardSchemaKey::Padding, "padding"},
            {AdaptiveCardSchemaKey::Placeholder, "placeholder"},
            {AdaptiveCardSchemaKey::PlayButton, "playButton"},
            {AdaptiveCardSchemaKey::Poster, "poster"},
            {AdaptiveCardSchemaKey::ProviderId, "providerId"},
            {AdaptiveCardSchemaKey::Refresh, "refresh"},
            {AdaptiveCardSchemaKey::Regex, "regex"},
            {AdaptiveCardSchemaKey::Repeat, "repeat"},
            {AdaptiveCardSchemaKey::RepeatHorizontally, "repeatHorizontally"},
            {AdaptiveCardSchemaKey::RepeatVertically, "repeatVertically"},
            {AdaptiveCardSchemaKey::RequiredInputs, "requiredInputs"},
            {AdaptiveCardSchemaKey::Requires, "requires"},
            {AdaptiveCardSchemaKey::RichTextBlock, "richTextBlock"},
            {AdaptiveCardSchemaKey::Right, "right"},
            {AdaptiveCardSchemaKey::Rows, "rows"},
            {AdaptiveCardSchemaKey::Rtl, "rtl"},
            {AdaptiveCardSchemaKey::Schema, "$schema"},
            {AdaptiveCardSchemaKey::SelectAction, "selectAction"},
            {AdaptiveCardSchemaKey::Separator, "separator"},
            {AdaptiveCardSchemaKey::ShowActionMode, "showActionMode"},
            {AdaptiveCardSchemaKey::ShowCard, "showCard"},
            {AdaptiveCardSchemaKey::ShowCardActionConfig, "showCardActionConfig"},
            {AdaptiveCardSchemaKey::ShowGridLines, "showGridLines"},
            {AdaptiveCardSchemaKey::Size, "size"},
            {AdaptiveCardSchemaKey::Small, "small"},
            {AdaptiveCardSchemaKey::Sources, "sources"},
            {AdaptiveCardSchemaKey::Spacing, "spacing"},
            {AdaptiveCardSchemaKey::SpacingDefinition, "spacingDefinition"},
            {AdaptiveCardSchemaKey::Speak, "speak"},
            {AdaptiveCardSchemaKey::Standard, "standard"},
            {AdaptiveCardSchemaKey::Stretch, "stretch"},
            {AdaptiveCardSchemaKey::Strikethrough, "strikethrough"},
            {AdaptiveCardSchemaKey::Style, "style"},
            {AdaptiveCardSchemaKey::Subtle, "subtle"},
            {AdaptiveCardSchemaKey::Suffix, "suffix"},
            {AdaptiveCardSchemaKey::SupportsInteractivity, "supportsInteractivity"},
            {AdaptiveCardSchemaKey::Table, "table"},
            {AdaptiveCardSchemaKey::TableCell, "tableCell"},
            {AdaptiveCardSchemaKey::TableRow, "tableRow"},
            {AdaptiveCardSchemaKey::TargetElements, "targetElements"},
            {AdaptiveCardSchemaKey::TargetInputIds, "targetInputIds"},
            {AdaptiveCardSchemaKey::TargetWidth, "targetWidth"},
            {AdaptiveCardSchemaKey::Text, "text"},
            {AdaptiveCardSchemaKey::TextBlock, "textBlock"},
            {AdaptiveCardSchemaKey::TextConfig, "textConfig"},
            {AdaptiveCardSchemaKey::TextInput, "textInput"},
            {AdaptiveCardSchemaKey::TextStyles, "textStyles"},
            {AdaptiveCardSchemaKey::TintColor, "tintColor"},
            {AdaptiveCardSchemaKey::MarigoldColor, "marigoldColor"},
            {AdaptiveCardSchemaKey::NeutralColor, "neutralColor"},
            {AdaptiveCardSchemaKey::FilledStar, "filledStar"},
            {AdaptiveCardSchemaKey::EmptyStar, "emptyStar"},
            {AdaptiveCardSchemaKey::RatingTextColor, "ratingTextColor"},
            {AdaptiveCardSchemaKey::CountTextColor, "countTextColor"},
            {AdaptiveCardSchemaKey::TextWeight, "weight"},
            {AdaptiveCardSchemaKey::Thickness, "thickness"},
            {AdaptiveCardSchemaKey::TimeInput, "timeInput"},
            {AdaptiveCardSchemaKey::Title, "title"},
            {AdaptiveCardSchemaKey::Tint, "tint"},
            {AdaptiveCardSchemaKey::ToggleInput, "toggleInput"},
            {AdaptiveCardSchemaKey::Layout, "Layout"},
            {AdaptiveCardSchemaKey::ItemFit, "itemFit"},
            {AdaptiveCardSchemaKey::RowSpacing, "rowSpacing"},
            {AdaptiveCardSchemaKey::ColumnSpacing, "columnSpacing"},
            {AdaptiveCardSchemaKey::ItemWidth, "itemWidth"},
            {AdaptiveCardSchemaKey::MinItemWidth, "minItemWidth"},
            {AdaptiveCardSchemaKey::MaxItemWidth, "maxItemWidth"},
            {AdaptiveCardSchemaKey::HorizontalItemsAlignment, "horizontalItemsAlignment"},
            {AdaptiveCardSchemaKey::Row, "row"},
            {AdaptiveCardSchemaKey::RowSpan, "rowSpan"},
            {AdaptiveCardSchemaKey::ColumnSpan, "columnSpan"},
            {AdaptiveCardSchemaKey::AreaGridName, "grid.area"},
            {AdaptiveCardSchemaKey::Areas, "areas"},
            {AdaptiveCardSchemaKey::Layouts, "layouts"},
            {AdaptiveCardSchemaKey::TokenExchangeResource, "tokenExchangeResource"},
            {AdaptiveCardSchemaKey::Tooltip, "tooltip"},
            {AdaptiveCardSchemaKey::Top, "top"},
            {AdaptiveCardSchemaKey::Type, "type"},
            {AdaptiveCardSchemaKey::Underline, "underline"},
            {AdaptiveCardSchemaKey::Uri, "uri"},
            {AdaptiveCardSchemaKey::Url, "url"},
            {AdaptiveCardSchemaKey::UserIds, "userIds"},
            {AdaptiveCardSchemaKey::Value, "value"},
            {AdaptiveCardSchemaKey::ValueChangedAction, "valueChangedAction"},
            {AdaptiveCardSchemaKey::ValueChangedActionType, "type"},
            {AdaptiveCardSchemaKey::ValueOff, "valueOff"},
            {AdaptiveCardSchemaKey::ValueOn, "valueOn"},
            {AdaptiveCardSchemaKey::Verb, "verb"},
            {AdaptiveCardSchemaKey::VeryNarrow, "veryNarrow"},
            {AdaptiveCardSchemaKey::Version, "version"},
            {AdaptiveCardSchemaKey::VerticalAlignment, "verticalAlignment"},
            {AdaptiveCardSchemaKey::VerticalCellContentAlignment, "verticalCellContentAlignment"},
            {AdaptiveCardSchemaKey::VerticalContentAlignment, "verticalContentAlignment"},
            {AdaptiveCardSchemaKey::Warning, "warning"},
            {AdaptiveCardSchemaKey::WebUrl, "webUrl"},
            {AdaptiveCardSchemaKey::Weight, "weight"},
            {AdaptiveCardSchemaKey::Width, "width"},
            {AdaptiveCardSchemaKey::CompoundButton,"compoundButton"},
            {AdaptiveCardSchemaKey::CarouselPage,"CarouselPage"},
            {AdaptiveCardSchemaKey::Pages,"pages"},
            {AdaptiveCardSchemaKey::PageAnimation,"pageAnimation"},
            {AdaptiveCardSchemaKey::PageControl,"pageControl"},
            {AdaptiveCardSchemaKey::SelectedTintColor,"selectedTintColor"},
            {AdaptiveCardSchemaKey::TextColor, "textColor"},
            {AdaptiveCardSchemaKey::StrokeColor, "strokeColor"},
            {AdaptiveCardSchemaKey::Shape, "shape"},
            {AdaptiveCardSchemaKey::ExtraSmall,"extraSmall"},
            {AdaptiveCardSchemaKey::Wrap, "wrap"},
            {AdaptiveCardSchemaKey::MenuActions, "menuActions"},
            {AdaptiveCardSchemaKey::ThemedIconUrls, "themedIconUrls"},
            {AdaptiveCardSchemaKey::ThemedUrls, "themedUrls"},
            {AdaptiveCardSchemaKey::Theme, "theme"},
            {AdaptiveCardSchemaKey::LabelPosition, "labelPosition"},
            {AdaptiveCardSchemaKey::Content, "content"},
            {AdaptiveCardSchemaKey::DisplayArrow, "displayArrow"},
            {AdaptiveCardSchemaKey::MaxPopoverWidth, "maxPopoverWidth"},
            {AdaptiveCardSchemaKey::Position, "position"},
            {AdaptiveCardSchemaKey::Popover, "popover"},
            {AdaptiveCardSchemaKey::ImageFitMode, "fitMode"},
            {AdaptiveCardSchemaKey::HorizontalContentAlignment, "horizontalContentAlignment"},
            {AdaptiveCardSchemaKey::LabelFor, "labelFor"},
            {AdaptiveCardSchemaKey::Resources, "resources"},
            {AdaptiveCardSchemaKey::Strings, "strings"},
            {AdaptiveCardSchemaKey::DefaultValue, "defaultValue"},
            {AdaptiveCardSchemaKey::LocalizedValues, "localizedValues"},
            {AdaptiveCardSchemaKey::Abstract, "abstract"},
            {AdaptiveCardSchemaKey::Keywords, "keywords"},
            {AdaptiveCardSchemaKey::References, "references"},
            {AdaptiveCardSchemaKey::ReferenceIndex, "referenceIndex"},
            {AdaptiveCardSchemaKey::CitationBlock, "citationBlock"},
            {AdaptiveCardSchemaKey::DividerColor, "dividerColor"},
            {AdaptiveCardSchemaKey::IconColor, "iconColor"},
            {AdaptiveCardSchemaKey::BottomSheetTextColor, "bottomSheetTextColor"},
            {AdaptiveCardSchemaKey::BottomSheetKeywordsColor, "bottomSheetKeywordsColor"},
            {AdaptiveCardSchemaKey::BottomSheetMoreDetailColor, "bottomSheetMoreDetailColor"},
            {AdaptiveCardSchemaKey::BottomSheetBackgroundColor, "bottomSheetBackgroundColor"}});

    DEFINE_ADAPTIVECARD_ENUM(CardElementType, {
            {CardElementType::ActionSet, "ActionSet"},
            {CardElementType::AdaptiveCard, "AdaptiveCard"},
            {CardElementType::Badge, "Badge"},
            {CardElementType::ChoiceSetInput, "Input.ChoiceSet"},
            {CardElementType::Column, "Column"},
            {CardElementType::ColumnSet, "ColumnSet"},
            {CardElementType::Container, "Container"},
            {CardElementType::Custom, "Custom"},
            {CardElementType::DateInput, "Input.Date"},
            {CardElementType::Fact, "Fact"},
            {CardElementType::FactSet, "FactSet"},
            {CardElementType::Image, "Image"},
            {CardElementType::Icon, "Icon"},
            {CardElementType::ImageSet, "ImageSet"},
            {CardElementType::Media, "Media"},
            {CardElementType::NumberInput, "Input.Number"},
            {CardElementType::RatingInput, "Input.Rating"},
            {CardElementType::RatingLabel, "Rating"},
            {CardElementType::RichTextBlock, "RichTextBlock"},
            {CardElementType::Table, "Table"},
            {CardElementType::TableCell, "TableCell"},
            {CardElementType::TableRow, "TableRow"},
            {CardElementType::TextBlock, "TextBlock"},
            {CardElementType::TextInput, "Input.Text"},
            {CardElementType::TimeInput, "Input.Time"},
            {CardElementType::ToggleInput, "Input.Toggle"},
            {CardElementType::CompoundButton,"CompoundButton"},
            {CardElementType::Carousel,"Carousel"},
            {CardElementType::CarouselPage,"CarouselPage"},
            {CardElementType::ProgressBar,"ProgressBar"},
            {CardElementType::ProgressRing,"ProgressRing"},
            {CardElementType::Unknown, "Unknown"}});

    DEFINE_ADAPTIVECARD_ENUM(ActionType, {
            {ActionType::Unsupported, "Unsupported"},
            {ActionType::Execute, "Action.Execute"},
            {ActionType::OpenUrl, "Action.OpenUrl"},
            {ActionType::Popover, "Action.Popover"},
            {ActionType::ShowCard, "Action.ShowCard"},
            {ActionType::Submit, "Action.Submit"},
            {ActionType::ToggleVisibility, "Action.ToggleVisibility"},
            {ActionType::Custom, "Custom"},
            {ActionType::UnknownAction, "UnknownAction"},
            {ActionType::Overflow, "Overflow"}});

    DEFINE_ADAPTIVECARD_ENUM(HeightType, {
            {HeightType::Auto, "Auto"},
            {HeightType::Stretch, "Stretch"}});

    DEFINE_ADAPTIVECARD_ENUM(RatingSize, {
            {RatingSize::Medium, "medium"},
            {RatingSize::Large, "large"}});

    DEFINE_ADAPTIVECARD_ENUM(RatingColor, {
            {RatingColor::Neutral, "neutral"},
            {RatingColor::Marigold, "marigold"}});

    DEFINE_ADAPTIVECARD_ENUM(RatingStyle, {
            {RatingStyle::Default, "default"},
            {RatingStyle::Compact, "compact"}});

    DEFINE_ADAPTIVECARD_ENUM(Spacing, {
            {Spacing::Default, "default"},
            {Spacing::None, "none"},
            {Spacing::Small, "small"},
            {Spacing::Medium, "medium"},
            {Spacing::Large, "large"},
            {Spacing::ExtraLarge, "extraLarge"},
            {Spacing::ExtraSmall, "extraSmall"},
            {Spacing::Padding, "padding"}});

    DEFINE_ADAPTIVECARD_ENUM(SeparatorThickness, {
            {SeparatorThickness::Default, "default"},
            {SeparatorThickness::Thick, "thick"}});

    DEFINE_ADAPTIVECARD_ENUM(ImageStyle, {
            {
                {ImageStyle::Default, "default"},
                {ImageStyle::Person, "person"},
                {ImageStyle::RoundedCorners, "roundedCorners"}
            },
            {
                {"normal", ImageStyle::Default} // Back compat to support "Normal" for "Default" for pre V1.0 payloads
            }});

    DEFINE_ADAPTIVECARD_ENUM(IconSize, {
        {IconSize::xxSmall, "xxSmall"},
        {IconSize::xSmall, "xSmall"},
        {IconSize::Small, "Small"},
        {IconSize::Standard, "Standard"},
        {IconSize::Medium, "Medium"},
        {IconSize::Large, "Large"},
        {IconSize::xLarge, "xLarge"},
        {IconSize::xxLarge, "xxLarge"}});

    DEFINE_ADAPTIVECARD_ENUM(IconStyle, {
        {IconStyle::Regular, "Regular"},
        {IconStyle::Filled, "Filled"},});

    DEFINE_ADAPTIVECARD_ENUM(VerticalAlignment, {
        { VerticalAlignment::Top, "top" },
        { VerticalAlignment::Center, "center" },
        { VerticalAlignment::Bottom, "bottom" }});

    DEFINE_ADAPTIVECARD_ENUM(VerticalContentAlignment, {
        { VerticalContentAlignment::Top, "Top" },
        { VerticalContentAlignment::Center, "Center" },
        { VerticalContentAlignment::Bottom, "Bottom" }});

    DEFINE_ADAPTIVECARD_ENUM(ImageFillMode, {
        { ImageFillMode::Cover, "cover" },
        { ImageFillMode::RepeatHorizontally, "repeatHorizontally" },
        { ImageFillMode::RepeatVertically, "repeatVertically" },
        { ImageFillMode::Repeat, "repeat" }});

    DEFINE_ADAPTIVECARD_ENUM(ItemFit, {
        { ItemFit::Fit, "Fit" },
        { ItemFit::Fill, "Fill" }});

    DEFINE_ADAPTIVECARD_ENUM(LayoutContainerType, {
        { LayoutContainerType::None, "Layout.None" },
        { LayoutContainerType::Stack, "Layout.Stack" },
        { LayoutContainerType::Flow, "Layout.Flow" },
        { LayoutContainerType::AreaGrid, "Layout.AreaGrid" }});

    DEFINE_ADAPTIVECARD_ENUM(ImageSize, {
            {ImageSize::Auto, "Auto"},
            {ImageSize::Large, "Large"},
            {ImageSize::Medium, "Medium"},
            {ImageSize::Small, "Small"},
            {ImageSize::Stretch, "Stretch"}});

    DEFINE_ADAPTIVECARD_ENUM(ImageFitMode, {
        {ImageFitMode::Cover, "Cover"},
        {ImageFitMode::Contain, "Contain"},
        {ImageFitMode::Fill, "Fill"}});

    DEFINE_ADAPTIVECARD_ENUM(HorizontalAlignment, {
            {HorizontalAlignment::Center, "center"},
            {HorizontalAlignment::Left, "left"},
            {HorizontalAlignment::Right, "right"}});

    DEFINE_ADAPTIVECARD_ENUM(HorizontalContentAlignment, {
        {HorizontalContentAlignment::Left, "Left"},
        {HorizontalContentAlignment::Center, "Center"},
        {HorizontalContentAlignment::Right, "Right"}});

    DEFINE_ADAPTIVECARD_ENUM(ForegroundColor, {
            {ForegroundColor::Accent, "Accent"},
            {ForegroundColor::Attention, "Attention"},
            {ForegroundColor::Dark, "Dark"},
            {ForegroundColor::Default, "Default"},
            {ForegroundColor::Good, "Good"},
            {ForegroundColor::Light, "Light"},
            {ForegroundColor::Warning, "Warning"}});

    DEFINE_ADAPTIVECARD_ENUM(TextStyle, {
            {TextStyle::Default, "default"},
            {TextStyle::Heading, "heading"}});

    DEFINE_ADAPTIVECARD_ENUM(TextWeight, {
            {
                {TextWeight::Bolder, "Bolder"},
                {TextWeight::Lighter, "Lighter"},
                {TextWeight::Default, "Default"}
            },
            {
                {"Normal", TextWeight::Default} // Back compat to support "Normal" for "Default" for pre V1.0 payloads
            }});

    DEFINE_ADAPTIVECARD_ENUM(TextSize, {
            {
                {TextSize::ExtraLarge, "ExtraLarge"},
                {TextSize::Large, "Large"},
                {TextSize::Medium, "Medium"},
                {TextSize::Default, "Default"},
                {TextSize::Small, "Small"}
            },
            {
                {"Normal", TextSize::Default} // Back compat to support "Normal" for "Default" for pre V1.0 payloads
            }});

    DEFINE_ADAPTIVECARD_ENUM(FontType, {
            {FontType::Default, "Default"},
            {FontType::Monospace, "Monospace"}});

    DEFINE_ADAPTIVECARD_ENUM(ActionsOrientation, {
            {ActionsOrientation::Horizontal, "Horizontal"},
            {ActionsOrientation::Vertical, "Vertical"}});

    DEFINE_ADAPTIVECARD_ENUM(ActionMode, {
            {ActionMode::Inline, "Inline"},
            {ActionMode::Popup, "Popup"}});

    DEFINE_ADAPTIVECARD_ENUM(ActionRole, {
            {ActionRole::Button, "Button"},
            {ActionRole::Link, "Link"},
            {ActionRole::Tab, "Tab"},
            {ActionRole::Menu, "Menu"},
            {ActionRole::MenuItem, "MenuItem"}});

    DEFINE_ADAPTIVECARD_ENUM(AssociatedInputs, {
            {AssociatedInputs::Auto, "Auto"},
            {AssociatedInputs::None, "None"}});

    DEFINE_ADAPTIVECARD_ENUM(ChoiceSetStyle, {
            {ChoiceSetStyle::Compact, "Compact"},
            {ChoiceSetStyle::Expanded, "Expanded"},
            {ChoiceSetStyle::Filtered, "Filtered"}});

    DEFINE_ADAPTIVECARD_ENUM(TextInputStyle, {
            {TextInputStyle::Email, "Email"},
            {TextInputStyle::Tel, "Tel"},
            {TextInputStyle::Text, "Text"},
            {TextInputStyle::Url, "Url"},
            {TextInputStyle::Password, "Password"}});

    DEFINE_ADAPTIVECARD_ENUM(ContainerStyle, {
            {ContainerStyle::Default, "Default"},
            {ContainerStyle::Emphasis, "Emphasis"},
            {ContainerStyle::Good, "Good"},
            {ContainerStyle::Attention, "Attention"},
            {ContainerStyle::Warning, "Warning"},
            {ContainerStyle::Accent, "Accent"}});

    DEFINE_ADAPTIVECARD_ENUM(ActionAlignment, {
            {ActionAlignment::Left, "Left"},
            {ActionAlignment::Center, "Center"},
            {ActionAlignment::Right, "Right"},
            {ActionAlignment::Stretch, "Stretch"}});

    DEFINE_ADAPTIVECARD_ENUM(IconPlacement, {
            {IconPlacement::AboveTitle, "AboveTitle"},
            {IconPlacement::LeftOfTitle, "LeftOfTitle"}});

    DEFINE_ADAPTIVECARD_ENUM(PageAnimation, {
            {PageAnimation::Slide,"Slide"},
            {PageAnimation::CrossFade,"CrossFade"},
            {PageAnimation::None,"None"}});

    DEFINE_ADAPTIVECARD_ENUM(InlineElementType, {
            {InlineElementType::TextRun, "TextRun"},
            {InlineElementType::CitationRun, "CitationRun"},
            {InlineElementType::IconRun, "IconRun"},
            {InlineElementType::ImageRun, "ImageRun"}});

    DEFINE_ADAPTIVECARD_ENUM(Mode, {
            {Mode::Primary, "primary"},
            {Mode::Secondary, "secondary"}});

    DEFINE_ADAPTIVECARD_ENUM(ACTheme, {
            {ACTheme::Light, "Light"},
            {ACTheme::Dark, "Dark"}})

    DEFINE_ADAPTIVECARD_ENUM(ErrorStatusCode, {
            {ErrorStatusCode::InvalidJson, "InvalidJson"},
            {ErrorStatusCode::RenderFailed, "RenderFailed"},
            {ErrorStatusCode::RequiredPropertyMissing, "RequiredPropertyMissing"},
            {ErrorStatusCode::InvalidPropertyValue, "InvalidPropertyValue"},
            {ErrorStatusCode::UnsupportedParserOverride, "UnsupportedParserOverride"},
            {ErrorStatusCode::IdCollision, "IdCollision"},
            {ErrorStatusCode::CustomError, "CustomError"}});

    DEFINE_ADAPTIVECARD_ENUM(TargetWidthType, {
        {TargetWidthType::Default, "Default"},
        {TargetWidthType::VeryNarrow, "veryNarrow"},
        {TargetWidthType::Narrow, "narrow"},
        {TargetWidthType::Standard, "standard"},
        {TargetWidthType::Wide, "wide"},
        {TargetWidthType::AtMostVeryNarrow, "atMost:veryNarrow"},
        {TargetWidthType::AtMostNarrow, "atMost:narrow"},
        {TargetWidthType::AtMostStandard, "atMost:standard"},
        {TargetWidthType::AtMostWide, "atMost:wide"},
        {TargetWidthType::AtLeastVeryNarrow, "atLeast:veryNarrow"},
        {TargetWidthType::AtLeastNarrow, "atLeast:narrow"},
        {TargetWidthType::AtLeastStandard, "atLeast:standard"},
        {TargetWidthType::AtLeastWide, "atLeast:wide"}});

    DEFINE_ADAPTIVECARD_ENUM(ValueChangedActionType, {
            {ValueChangedActionType::ResetInputs, "Action.ResetInputs"},});

    DEFINE_ADAPTIVECARD_ENUM(IconPosition, {
        {IconPosition::Before, "Before"},
        {IconPosition::After, "After"},});

    DEFINE_ADAPTIVECARD_ENUM(Shape, {
        {Shape::Square, "Square"},
        {Shape::Rounded, "Rounded"},
        {Shape::Circular, "Circular"}});

    DEFINE_ADAPTIVECARD_ENUM(BadgeStyle, {
        {BadgeStyle::Default, "Default"},
        {BadgeStyle::Accent, "Accent"},
        {BadgeStyle::Attention, "Attention"},
        {BadgeStyle::Good, "Good"},
        {BadgeStyle::Informative, "Informative"},
        {BadgeStyle::Subtle, "Subtle"},
        {BadgeStyle::Warning, "Warning"}});

    DEFINE_ADAPTIVECARD_ENUM(BadgeSize, {
        {BadgeSize::Medium, "Medium"},
        {BadgeSize::Large, "Large"},
        {BadgeSize::ExtraLarge, "ExtraLarge"}});

    DEFINE_ADAPTIVECARD_ENUM(BadgeAppearance, {
        {BadgeAppearance::Filled, "Filled"},
        {BadgeAppearance::Tint, "Tint"}});

    DEFINE_ADAPTIVECARD_ENUM(ProgressBarColor, {
        {ProgressBarColor::Accent, "Accent"},
        {ProgressBarColor::Attention, "Attention"},
        {ProgressBarColor::Good, "Good"},
        {ProgressBarColor::Warning, "Warning"}});

    DEFINE_ADAPTIVECARD_ENUM(ProgressSize, {
        {ProgressSize::Tiny, "Tiny"},
        {ProgressSize::Small, "Small"},
        {ProgressSize::Medium, "Medium"},
        {ProgressSize::Large, "Large"}})

    DEFINE_ADAPTIVECARD_ENUM(LabelPosition, {
        {LabelPosition::Above, "Above"},
        {LabelPosition::Below, "Below"},
        {LabelPosition::Before, "Before"},
        {LabelPosition::After, "After"}})

    DEFINE_ADAPTIVECARD_ENUM(ReferenceType, {
        {ReferenceType::AdaptiveCard, "AdaptiveCardReference"},
        {ReferenceType::Document, "DocumentReference"}})

    DEFINE_ADAPTIVECARD_ENUM(ReferenceIcon, {
        {ReferenceIcon::AdobeFlash, "adobeFlash"},
        {ReferenceIcon::AdobeIllustrator, "adobeIllustrator"},
        {ReferenceIcon::AdobeInDesign, "adobeInDesign"},
        {ReferenceIcon::AdobePhotoshop, "adobePhotoshop"},
        {ReferenceIcon::MsExcel, "msExcel"},
        {ReferenceIcon::MsLoop, "msLoop"},
        {ReferenceIcon::MsOneNote, "msOneNote"},
        {ReferenceIcon::MsPowerPoint, "msPowerPoint"},
        {ReferenceIcon::MsSharePoint, "msSharePoint"},
        {ReferenceIcon::MsVisio, "msVisio"},
        {ReferenceIcon::MsWhiteboard, "msWhiteboard"},
        {ReferenceIcon::MsWord, "msWord"},
        {ReferenceIcon::Code, "code"},
        {ReferenceIcon::Gif, "gif"},
        {ReferenceIcon::Image, "image"},
        {ReferenceIcon::Pdf, "pdf"},
        {ReferenceIcon::Sketch, "sketch"},
        {ReferenceIcon::Sound, "sound"},
        {ReferenceIcon::Text, "text"},
        {ReferenceIcon::Video, "video"},
        {ReferenceIcon::Zip, "zip"}})
}
