//
//  IconInfo.cpp
//  AdaptiveCards
//
//  Created by Abhishek Gupta on 16/05/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#include "pch.h"
#include "ParseUtil.h"
#include "ParseContext.h"
#include "Util.h"
#include "CompoundButton.h"
#include "Icon.h"

using namespace AdaptiveCards;

IconInfo::IconInfo():m_foregroundColor(ForegroundColor::Default), m_iconStyle(IconStyle::Regular), m_iconSize(IconSize::Standard)
{
    PopulateKnownPropertiesSet();
}

Json::Value IconInfo::SerializeToJsonValue() const
{
    Json::Value root = Json::Value();

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

    return root;
}

ForegroundColor IconInfo::getForgroundColor() const
{
    return m_foregroundColor;
}

void IconInfo::setForgroundColor(const ForegroundColor value)
{
    m_foregroundColor = value;
}

IconSize IconInfo::getIconSize() const
{
    return m_iconSize;
}

void IconInfo::setIconSize(const IconSize value)
{
    m_iconSize = value;
}

IconStyle IconInfo::getIconStyle() const
{
    return m_iconStyle;
}

void IconInfo::setIconStyle(const IconStyle value)
{
    m_iconStyle = value;
}

std::string IconInfo::GetName() const
{
    return m_name;
}

void IconInfo::SetName(const std::string& value)
{
    m_name = value;
}

std::shared_ptr<IconInfo> IconInfo::Deserialize(const Json::Value& json)
{
    if(json.empty() || !json.isObject())
    {
        return nullptr;
    }

    std::shared_ptr<IconInfo> iconInfo = std::make_shared<IconInfo>();
    iconInfo->setIconSize(ParseUtil::GetEnumValue<IconSize>(json, AdaptiveCardSchemaKey::Size, IconSize::Standard, IconSizeFromString));

    iconInfo->setIconStyle(ParseUtil::GetEnumValue<IconStyle>(json, AdaptiveCardSchemaKey::Style, IconStyle::Regular, IconStyleFromString));

    iconInfo->setForgroundColor(ParseUtil::GetEnumValue<ForegroundColor>(json, AdaptiveCardSchemaKey::Color, ForegroundColor::Default, ForegroundColorFromString));

    iconInfo->SetName(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Name,true));
    return iconInfo;
}

void IconInfo::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Name),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style)});
}

std::string IconInfo::GetSVGPath() const
{
    // format: "<baseIconCDNUrl><Icon Name>/<IconName>.json"
    std::string m_url = GetName() + "/" + GetName() + ".json";
    return m_url;
}
