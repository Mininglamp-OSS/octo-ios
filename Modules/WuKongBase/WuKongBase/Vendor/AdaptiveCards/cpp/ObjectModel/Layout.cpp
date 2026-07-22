// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "Layout.h"
#include "ParseContext.h"
#include "ParseUtil.h"

using namespace AdaptiveCards;

LayoutContainerType Layout::GetLayoutContainerType() const
{
    return m_layoutContainerType;
}

void Layout::SetLayoutContainerType(const LayoutContainerType& value)
{
    m_layoutContainerType = value;
}

TargetWidthType Layout::GetTargetWidth() const
{
    return m_targetWidth;
}

void Layout::SetTargetWidth(TargetWidthType value)
{
    m_targetWidth = value;
}

bool Layout::ShouldSerialize() const
{
    return true;
}

bool Layout::MeetsTargetWidthRequirement(HostWidth hostWidth)  const
{
    if (m_targetWidth == TargetWidthType::Default || hostWidth == HostWidth::Default)
    {
        return true;
    }

    switch(m_targetWidth) {
        case TargetWidthType::Wide:
            return hostWidth == HostWidth::Wide;
        case TargetWidthType::Standard:
            return hostWidth == HostWidth::Standard;
        case TargetWidthType::Narrow:
            return hostWidth == HostWidth::Narrow;
        case TargetWidthType::VeryNarrow:
            return hostWidth == HostWidth::VeryNarrow;
        case TargetWidthType::AtLeastWide:
            return hostWidth >= HostWidth::Wide;
        case TargetWidthType::AtLeastStandard:
            return hostWidth >= HostWidth::Standard;
        case TargetWidthType::AtLeastNarrow:
            return hostWidth >= HostWidth::Narrow;
        case TargetWidthType::AtLeastVeryNarrow:
            return hostWidth >= HostWidth::VeryNarrow;
        case TargetWidthType::AtMostWide:
            return hostWidth <= HostWidth::Wide;
        case TargetWidthType::AtMostStandard:
            return hostWidth <= HostWidth::Standard;
        case TargetWidthType::AtMostNarrow:
            return hostWidth <= HostWidth::Narrow;
        case TargetWidthType::AtMostVeryNarrow:
            return hostWidth <= HostWidth::VeryNarrow;
        default:
            return true;
    }
}

std::string Layout::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value Layout::SerializeToJsonValue() const
{
    Json::Value root;

    if (m_targetWidth != TargetWidthType::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetWidth)] = TargetWidthTypeToString(m_targetWidth);
    }

    if (m_layoutContainerType != LayoutContainerType::Stack)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Layout)] = LayoutContainerTypeToString(m_layoutContainerType);
    }

    return root;
}

std::shared_ptr<Layout> Layout::Deserialize(const Json::Value& json)
{
    
    std::shared_ptr<Layout> layout = std::make_shared<Layout>();
    layout->SetTargetWidth(ParseUtil::GetEnumValue<TargetWidthType>(json, AdaptiveCardSchemaKey::TargetWidth, TargetWidthType::Default, TargetWidthTypeFromString));
    layout->SetLayoutContainerType(ParseUtil::GetEnumValue<LayoutContainerType>(json, AdaptiveCardSchemaKey::Type, LayoutContainerType::Stack, LayoutContainerTypeFromString));

    return layout;
}

std::shared_ptr<Layout> Layout::DeserializeFromString(const std::string& jsonString)
{
    return Layout::Deserialize(ParseUtil::GetJsonValueFromString(jsonString));
}
