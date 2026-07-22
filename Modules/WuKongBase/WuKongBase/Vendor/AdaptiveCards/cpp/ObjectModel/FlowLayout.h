//
//  FlowLayout.h
//  AdaptiveCards
//

#pragma once

#include "pch.h"
#include "ParseContext.h"
#include "Layout.h"

namespace AdaptiveCards
{
class FlowLayout: public Layout
{
public:
    FlowLayout() :
    m_itemFit(ItemFit::Fit), m_pixelItemWidth(-1), m_itemMinPixelWidth(-1), m_itemMaxPixelWidth(-1), m_rowSpacing(Spacing::Default), m_columnSpacing(Spacing::Default), m_horizontalAlignment(HorizontalAlignment::Center)
    {
    }
    FlowLayout(const FlowLayout&) = default;
    FlowLayout(FlowLayout&&) = default;
    FlowLayout& operator=(const FlowLayout&) = default;
    FlowLayout& operator=(FlowLayout&&) = default;
    ~FlowLayout() = default;
    
    ItemFit GetItemFit() const;
    void setItemFit(const ItemFit& value);
    
    std::optional<std::string> GetItemWidth() const;
    void SetItemWidth(const std::optional<std::string>& value);
    
    int GetItemPixelWidth() const;
    void SetItemPixelWidth(int value);
    
    int GetMinItemPixelWidth() const;
    void SetMinItemPixelWidth(int value);
    
    int GetMaxItemPixelWidth() const;
    void SetMaxItemPixelWidth(int value);
    
    std::optional<std::string> GetMinItemWidth() const;
    void SetMinItemWidth(const std::optional<std::string>& value);
    
    std::optional<std::string> GetMaxItemWidth() const;
    void SetMaxItemWidth(const std::optional<std::string>& value);
    
    Spacing GetColumnSpacing() const;
    void SetColumnSpacing(const Spacing& value);
    
    Spacing GetRowSpacing() const;
    void SetRowSpacing(const Spacing& value);
    
    HorizontalAlignment GetHorizontalAlignment() const;
    void SetHorizontalAlignment(const HorizontalAlignment& value);
    
    bool ShouldSerialize() const;
    std::string Serialize() const;
    Json::Value SerializeToJsonValue() const;
    
    static std::shared_ptr<FlowLayout> Deserialize(const Json::Value& json);
    static std::shared_ptr<FlowLayout> DeserializeFromString(const std::string& jsonString);
    
private:
    ItemFit m_itemFit = ItemFit::Fit;
    std::optional<std::string> m_itemWidth;
    std::optional<std::string> m_minItemWidth;
    std::optional<std::string> m_maxItemWidth;
    int m_pixelItemWidth;
    int m_itemMinPixelWidth;
    int m_itemMaxPixelWidth;
    
    Spacing m_rowSpacing = Spacing::Default;
    Spacing m_columnSpacing = Spacing::Default;
    
    HorizontalAlignment m_horizontalAlignment = HorizontalAlignment::Center;
};
} // namespace AdaptiveCards
