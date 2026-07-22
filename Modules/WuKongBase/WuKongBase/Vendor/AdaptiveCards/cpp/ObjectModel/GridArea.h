//
//  AreaGridLayout.hpp
//  AdaptiveCards
//

#pragma once

#include "pch.h"
#include "ParseContext.h"

namespace AdaptiveCards
{
class GridArea
{
public:
    GridArea() :m_row(1), m_column(1), m_rowSpan(1), m_columnSpan(1)
    {
    }
    
    std::string GetName() const;
    void SetName(const std::string& value);
    
    int GetRow() const;
    void SetRow(const int value);
    
    int GetRowSpan() const;
    void SetRowSpan(const int value);
    
    int GetColumn() const;
    void SetColumn(const int value);
    
    int GetColumnSpan() const;
    void SetColumnSpan(const int value);

    bool ShouldSerialize() const;
    std::string Serialize() const;
    Json::Value SerializeToJsonValue() const;

    static std::shared_ptr<GridArea> Deserialize(const Json::Value& json);
    static std::shared_ptr<GridArea> DeserializeFromString(const std::string& jsonString);

private:
    std::string m_name;
    int m_row;
    int m_column;
    int m_rowSpan;
    int m_columnSpan;
};
} // namespace AdaptiveCards
