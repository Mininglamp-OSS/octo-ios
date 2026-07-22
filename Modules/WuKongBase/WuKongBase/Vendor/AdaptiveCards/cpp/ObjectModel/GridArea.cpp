//
//  AreaGridLayout.cpp
//  AdaptiveCards
//

#include "GridArea.h"
#include "pch.h"
#include "ParseContext.h"
#include "ParseUtil.h"

using namespace AdaptiveCards;

std::string GridArea::GetName() const
{
    return m_name;
}

void GridArea::SetName(const std::string &value)
{
    m_name = value;
}

int GridArea::GetRow() const
{
    return m_row;
}

void GridArea::SetRow(const int value)
{
    m_row = value;
}

int GridArea::GetRowSpan() const
{
    return m_rowSpan;
}

void GridArea::SetRowSpan(const int value)
{
    m_rowSpan = value;
}

int GridArea::GetColumn() const
{
    return m_column;
}

void GridArea::SetColumn(const int value)
{
    m_column = value;
}

int GridArea::GetColumnSpan() const
{
    return m_columnSpan;
}

void GridArea::SetColumnSpan(const int value)
{
    m_columnSpan = value;
}

bool GridArea::ShouldSerialize() const
{
    return true;
}

std::string GridArea::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value GridArea::SerializeToJsonValue() const
{
    Json::Value root;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Name)] = m_name;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Row)] = m_row;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Column)] = m_column;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ColumnSpan)] = m_columnSpan;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::RowSpan)] = m_rowSpan;
    return root;
}

std::shared_ptr<GridArea> GridArea::Deserialize(const Json::Value& json)
{

    std::shared_ptr<GridArea> area = std::make_shared<GridArea>();
    area->SetName(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Name));
    area->SetRow(ParseUtil::GetInt(json, AdaptiveCardSchemaKey::Row, 1));
    area->SetRowSpan(ParseUtil::GetInt(json, AdaptiveCardSchemaKey::RowSpan, 1));
    area->SetColumn(ParseUtil::GetInt(json, AdaptiveCardSchemaKey::Column, 1));
    area->SetColumnSpan(ParseUtil::GetInt(json, AdaptiveCardSchemaKey::ColumnSpan, 1));
    return area;
}

std::shared_ptr<GridArea> GridArea::DeserializeFromString(const std::string& jsonString)
{
    return GridArea::Deserialize(ParseUtil::GetJsonValueFromString(jsonString));
}
