//
//  AreaGridLayout.hpp
//  AdaptiveCards
//
//  Created by Abhishek on 05/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#pragma once

#include "pch.h"
#include "ParseContext.h"
#include "Layout.h"
#include "GridArea.h"

namespace AdaptiveCards
{
class AreaGridLayout: public Layout
{
public:
    AreaGridLayout() :
    m_columns({}), m_areas({}), m_rowSpacing(Spacing::Default), m_columnSpacing(Spacing::Default)
    {
    }
    
    AreaGridLayout(const AreaGridLayout&) = default;
    AreaGridLayout(AreaGridLayout&&) = default;
    AreaGridLayout& operator=(const AreaGridLayout&) = default;
    AreaGridLayout& operator=(AreaGridLayout&&) = default;
    ~AreaGridLayout() = default;
    
    std::vector<std::string>& GetColumns();
    void SetColumns(std::vector<std::string>);
    
    std::vector<std::shared_ptr<AdaptiveCards::GridArea>>& GetAreas();
    const std::vector<std::shared_ptr<AdaptiveCards::GridArea>>& GetAreas() const;
    void SetAreas(const std::vector<std::shared_ptr<AdaptiveCards::GridArea>>& value);
    
    Spacing GetColumnSpacing() const;
    void SetColumnSpacing(const Spacing& value);
    
    Spacing GetRowSpacing() const;
    void SetRowSpacing(const Spacing& value);

    bool ShouldSerialize() const;
    std::string Serialize() const;
    Json::Value SerializeToJsonValue() const;

    static std::shared_ptr<AreaGridLayout> Deserialize(const Json::Value& json);
    static std::shared_ptr<AreaGridLayout> DeserializeFromString(const std::string& jsonString);

private:
    std::vector<std::string> m_columns;
    std::vector<std::shared_ptr<GridArea>> m_areas;
    Spacing m_rowSpacing = Spacing::Default;
    Spacing m_columnSpacing = Spacing::Default;
};
} // namespace AdaptiveCards

