//
// Created by Preeti Patwa on 26/09/24.
//
#include "pch.h"
#include <iomanip>
#include <regex>
#include <iostream>
#include <codecvt>
#include "ParseContext.h"
#include "DateTimePreparser.h"
#include "ParseUtil.h"
#include "Util.h"
#include "Badge.h"

using namespace AdaptiveCards;

Badge::Badge() :
        BaseCardElement(CardElementType::Badge)
{
    PopulateKnownPropertiesSet();
}

void Badge::SetText(const std::string &value) {
    m_text = value;
}

std::string Badge::GetText() const {
    return m_text;
}

void Badge::SetBadgeIcon(const std::string &value) {
    m_icon = value;
}

std::string Badge::GetBadgeIcon() const {
    return m_icon;
}

void Badge::SetTooltip(const std::string &value) {
    m_tooltip = value;
}

std::string Badge::GetTooltip() const {
    return m_tooltip;
}

void Badge::SetShape(Shape value) {
    m_shape = value;
}

Shape Badge::GetShape() const {
    return m_shape;
}

void Badge::SetBadgeStyle(BadgeStyle value) {
    m_badgeStyle = value;
}

BadgeStyle Badge::GetBadgeStyle() const {
    return m_badgeStyle;
}

void Badge::SetBadgeAppearance(BadgeAppearance value) {
    m_badgeAppearance = value;
}

BadgeAppearance Badge::GetBadgeAppearance() const {
    return m_badgeAppearance;
}

void Badge::SetBadgeSize(BadgeSize value) {
    m_badgeSize = value;
}

BadgeSize Badge::GetBadgeSize() const {
    return m_badgeSize;
}

void Badge::SetIconPosition(IconPosition value) {
    m_iconPosition = value;
}

IconPosition Badge::GetIconPosition() const {
    return m_iconPosition;
}

void Badge::SetHorizontalAlignment(const std::optional<HorizontalAlignment> value) {
    m_hAlignment = value;
}

std::optional<HorizontalAlignment> Badge::GetHorizontalAlignment() const {
    return m_hAlignment;
}

Json::Value Badge::SerializeToJsonValue() const
{
    Json::Value root = BaseCardElement::SerializeToJsonValue();

    // ignore return -- properties are added directly to root

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Text)] = GetText();

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Icon)] = GetBadgeIcon();

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Tooltip)] = GetTooltip();

    if (m_hAlignment.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)] =
                HorizontalAlignmentToString(m_hAlignment.value_or(HorizontalAlignment::Left));
    }

    if (m_badgeStyle != BadgeStyle::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style)] = BadgeStyleToString(m_badgeStyle);
    }

    if (m_badgeSize != BadgeSize::Medium)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size)] = BadgeSizeToString(m_badgeSize);
    }

    if (m_shape != Shape::Circular)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Shape)] = ShapeToString(m_shape);
    }

    if (m_badgeAppearance != BadgeAppearance::Filled)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Appearance)] = BadgeAppearanceToString(m_badgeAppearance);
    }

    if (m_iconPosition != IconPosition::Before)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::IconPosition)] = IconPositionToString(m_iconPosition);
    }
    return root;
}


std::shared_ptr<BaseCardElement> BadgeParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::Badge);

    std::shared_ptr<Badge> badge = BaseCardElement::Deserialize<Badge>(context, json);

    badge->SetText(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Text, "",false));
    badge->SetBadgeIcon(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Icon, "", false));
    badge->SetBadgeStyle(ParseUtil::GetEnumValue<BadgeStyle>(json, AdaptiveCardSchemaKey::Style, BadgeStyle::Default,
                                                                     BadgeStyleFromString));
    badge->SetBadgeSize(ParseUtil::GetEnumValue<BadgeSize>(json, AdaptiveCardSchemaKey::Size, BadgeSize::Medium,
                                                        BadgeSizeFromString));
    badge->SetShape(ParseUtil::GetEnumValue<Shape>(json, AdaptiveCardSchemaKey::Shape, Shape::Circular,
                                                           ShapeFromString));
    badge->SetHorizontalAlignment(ParseUtil::GetOptionalEnumValue<HorizontalAlignment>(
            json, AdaptiveCardSchemaKey::HorizontalAlignment, HorizontalAlignmentFromString));

    badge->SetIconPosition(ParseUtil::GetEnumValue<IconPosition>(
            json, AdaptiveCardSchemaKey::IconPosition, IconPosition::Before,
            IconPositionFromString));

    badge->SetBadgeAppearance(ParseUtil::GetEnumValue<BadgeAppearance>(
            json, AdaptiveCardSchemaKey::Appearance, BadgeAppearance::Filled,
            BadgeAppearanceFromString));
    badge->SetTooltip(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Tooltip, "",false));

    return badge;
}

std::shared_ptr<BaseCardElement> BadgeParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return BadgeParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

void Badge::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
            {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Appearance),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Icon),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::IconPosition),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Appearance),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Shape),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Text)});
}

