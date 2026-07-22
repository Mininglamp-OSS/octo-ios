//
//  FlowLayout.cpp
//  AdaptiveCards
//
//  Created by Abhishek on 02/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#include "FlowLayout.h"
#include "pch.h"
#include "ParseContext.h"
#include "ParseUtil.h"
#include "Util.h"

using namespace AdaptiveCards;

ItemFit FlowLayout::GetItemFit() const
{
    return m_itemFit;
}

void FlowLayout::setItemFit(const ItemFit& value)
{
    m_itemFit = value;
}

Spacing FlowLayout::GetRowSpacing() const
{
    return m_rowSpacing;
}

void FlowLayout::SetRowSpacing(const Spacing& value)
{
    m_rowSpacing = value;
}

Spacing FlowLayout::GetColumnSpacing() const
{
    return m_columnSpacing;
}

void FlowLayout::SetColumnSpacing(const Spacing& value)
{
    m_columnSpacing = value;
}

HorizontalAlignment FlowLayout::GetHorizontalAlignment() const
{
    return m_horizontalAlignment;
}

void FlowLayout::SetHorizontalAlignment(const HorizontalAlignment& value)
{
    m_horizontalAlignment = value;
}

std::optional<std::string> FlowLayout::GetItemWidth() const
{
    return m_itemWidth;
}

void FlowLayout::SetItemWidth(const std::optional<std::string>& value)
{
    m_itemWidth = value;
}

std::optional<std::string> FlowLayout::GetMinItemWidth() const
{
    return m_minItemWidth;
}

void FlowLayout::SetMinItemWidth(const std::optional<std::string>& value)
{
    m_minItemWidth = value;
}

std::optional<std::string> FlowLayout::GetMaxItemWidth() const
{
    return m_maxItemWidth;
}

void FlowLayout::SetMaxItemWidth(const std::optional<std::string>& value)
{
    m_maxItemWidth = value;
}

bool FlowLayout::ShouldSerialize() const
{
    return true;
}

std::string FlowLayout::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

int FlowLayout::GetItemPixelWidth() const
{
    return m_pixelItemWidth;
}

void FlowLayout::SetItemPixelWidth(int value)
{
    m_pixelItemWidth = value;
}

int FlowLayout::GetMinItemPixelWidth() const
{
    return m_itemMinPixelWidth;
}

void FlowLayout::SetMinItemPixelWidth(int value)
{
    m_itemMinPixelWidth = value;
}

int FlowLayout::GetMaxItemPixelWidth() const
{
    return m_itemMaxPixelWidth;
}

void FlowLayout::SetMaxItemPixelWidth(int value)
{
    m_itemMaxPixelWidth = value;
}

Json::Value FlowLayout::SerializeToJsonValue() const
{
    Json::Value root;

    if (m_itemFit != ItemFit::Fit)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ItemFit)] = ItemFitToString(m_itemFit);
    }

    if (m_rowSpacing != Spacing::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::RowSpacing)] = SpacingToString(m_rowSpacing);
    }

    if (m_columnSpacing != Spacing::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ColumnSpacing)] = SpacingToString(m_columnSpacing);
    }

    if (m_horizontalAlignment != HorizontalAlignment::Center)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalItemsAlignment)] = HorizontalAlignmentToString(m_horizontalAlignment);
    }

    if (m_itemWidth.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ItemWidth)] = m_itemWidth.value_or("");
    }

    if (m_minItemWidth.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MinItemWidth)] = m_minItemWidth.value_or("");
    }

    if (m_maxItemWidth.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MaxItemWidth)] = m_maxItemWidth.value_or("");
    }

    return root;
}

std::shared_ptr<FlowLayout> FlowLayout::Deserialize(const Json::Value& json)
{

    std::shared_ptr<Layout> base_layout = Layout::Deserialize(json);
    std::shared_ptr<FlowLayout> layout = std::make_shared<FlowLayout>();
    layout->SetLayoutContainerType(base_layout->GetLayoutContainerType());
    layout->SetTargetWidth(base_layout->GetTargetWidth());
    layout->setItemFit(ParseUtil::GetEnumValue<ItemFit>(json, AdaptiveCardSchemaKey::ItemFit, ItemFit::Fit, ItemFitFromString));
    layout->SetRowSpacing(ParseUtil::GetEnumValue<Spacing>(json, AdaptiveCardSchemaKey::RowSpacing, Spacing::Default, SpacingFromString));
    layout->SetColumnSpacing(ParseUtil::GetEnumValue<Spacing>(json, AdaptiveCardSchemaKey::ColumnSpacing, Spacing::Default, SpacingFromString));
    layout->SetHorizontalAlignment(ParseUtil::GetEnumValue<HorizontalAlignment>(json, AdaptiveCardSchemaKey::HorizontalItemsAlignment, HorizontalAlignment::Center, HorizontalAlignmentFromString));
    layout->SetItemWidth(ParseUtil::GetOptionalString(json, AdaptiveCardSchemaKey::ItemWidth));
    layout->SetMinItemWidth(ParseUtil::GetOptionalString(json, AdaptiveCardSchemaKey::MinItemWidth));
    layout->SetMaxItemWidth(ParseUtil::GetOptionalString(json, AdaptiveCardSchemaKey::MaxItemWidth));
    int itemWidth = ParseSizeForPixelSize(ParseUtil::GetString(json, AdaptiveCardSchemaKey::ItemWidth), nullptr).value_or(-1);
    int minItemWidth = ParseSizeForPixelSize(ParseUtil::GetString(json, AdaptiveCardSchemaKey::MinItemWidth), nullptr).value_or(-1);
    int maxItemWidth = ParseSizeForPixelSize(ParseUtil::GetString(json, AdaptiveCardSchemaKey::MaxItemWidth), nullptr).value_or(-1);
    layout->SetItemPixelWidth(itemWidth);
    layout->SetMinItemPixelWidth(minItemWidth);
    layout->SetMaxItemPixelWidth(maxItemWidth);
    return layout;
}

std::shared_ptr<FlowLayout> FlowLayout::DeserializeFromString(const std::string& jsonString)
{
    return FlowLayout::Deserialize(ParseUtil::GetJsonValueFromString(jsonString));
}
