// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "Icon.h"
#include "ParseUtil.h"
#include "ParseContext.h"
#include "Util.h"

using namespace AdaptiveCards;

Icon::Icon() :
    BaseCardElement(CardElementType::Icon), m_foregroundColor(ForegroundColor::Default), m_iconStyle(IconStyle::Regular), m_iconSize(IconSize::Standard)
{
    PopulateKnownPropertiesSet();
}

Json::Value Icon::SerializeToJsonValue() const
{
    Json::Value root = BaseCardElement::SerializeToJsonValue();

    if (m_iconSize != IconSize::Standard)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size)] = IconSizeToString(m_iconSize);
    }

    if (m_iconStyle != IconStyle::Regular)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style)] = IconStyleToString(m_iconStyle);
    }

    if (m_foregroundColor != ForegroundColor::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color)] = ForegroundColorToString(m_foregroundColor);
    }

    if (!m_name.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Name)] = m_name;
    }

    if (m_selectAction != nullptr)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction)] =
            BaseCardElement::SerializeSelectAction(m_selectAction);
    }

    return root;
}

ForegroundColor Icon::getForgroundColor() const
{
    return m_foregroundColor;
}

void Icon::setForgroundColor(const ForegroundColor value)
{
    m_foregroundColor = value;
}

IconSize Icon::getIconSize() const
{
    return m_iconSize;
}

void Icon::setIconSize(const IconSize value)
{
    m_iconSize = value;
}

IconStyle Icon::getIconStyle() const
{
    return m_iconStyle;
}

void Icon::setIconStyle(const IconStyle value)
{
    m_iconStyle = value;
}

std::string Icon::GetName() const
{
    return m_name;
}

void Icon::SetName(const std::string& value)
{
    m_name = value;
}

std::shared_ptr<BaseActionElement> Icon::GetSelectAction() const
{
    return m_selectAction;
}

void Icon::SetSelectAction(const std::shared_ptr<BaseActionElement> action)
{
    m_selectAction = action;
}

std::shared_ptr<BaseCardElement> IconParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return IconParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<BaseCardElement> IconParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::Icon);
    return IconParser::DeserializeWithoutCheckingType(context, json);
}

std::shared_ptr<BaseCardElement> IconParser::DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& json)
{
    std::shared_ptr<Icon> icon = BaseCardElement::Deserialize<Icon>(context, json);
    
    icon->setIconSize(ParseUtil::GetEnumValue<IconSize>(json, AdaptiveCardSchemaKey::Size, IconSize::Standard, IconSizeFromString));
    
    icon->setIconStyle(ParseUtil::GetEnumValue<IconStyle>(json, AdaptiveCardSchemaKey::Style, IconStyle::Regular, IconStyleFromString));
    
    icon->setForgroundColor(ParseUtil::GetEnumValue<ForegroundColor>(json, AdaptiveCardSchemaKey::Color, ForegroundColor::Default, ForegroundColorFromString));
    
    icon->SetName(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Name));

    // Parse optional selectAction
    icon->SetSelectAction(ParseUtil::GetAction(context, json, AdaptiveCardSchemaKey::SelectAction, false));
    return icon;
}

void Icon::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Name),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction)});
}

void Icon::GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo)
{
    RemoteResourceInformation imageResourceInfo;
    imageResourceInfo.url = GetSVGPath();
    imageResourceInfo.mimeType = "image";
    resourceInfo.push_back(imageResourceInfo);
}

std::string Icon::GetSVGPath() const
{
    // format: "<baseIconCDNUrl><Icon Name>/<IconName>.json"
    std::string m_url = GetName() + "/" + GetName() + ".json";
    return m_url;
}
