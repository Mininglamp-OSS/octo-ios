//
//  AreaGridLayout.cpp
//  AdaptiveCards
//

#include "AreaGridLayout.h"
#include "pch.h"
#include "ParseContext.h"
#include "ParseUtil.h"

using namespace AdaptiveCards;

Spacing AreaGridLayout::GetRowSpacing() const
{
    return m_rowSpacing;
}

void AreaGridLayout::SetRowSpacing(const Spacing& value)
{
    m_rowSpacing = value;
}

Spacing AreaGridLayout::GetColumnSpacing() const
{
    return m_columnSpacing;
}

void AreaGridLayout::SetColumnSpacing(const Spacing& value)
{
    m_columnSpacing = value;
}

std::vector<std::string>& AreaGridLayout::GetColumns()
{
    return m_columns;
}

void AreaGridLayout::SetColumns(std::vector<std::string> columns)
{
    m_columns = columns;
}

std::vector<std::shared_ptr<GridArea>>& AreaGridLayout::GetAreas()
{
    return m_areas;
}
const std::vector<std::shared_ptr<GridArea>>& AreaGridLayout::GetAreas() const
{
    return m_areas;
}

void AreaGridLayout::SetAreas(const std::vector<std::shared_ptr<GridArea>>& value)
{
    m_areas = value;
}

bool AreaGridLayout::ShouldSerialize() const
{
    return true;
}

std::string AreaGridLayout::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value AreaGridLayout::SerializeToJsonValue() const
{
    Json::Value root;

    if (!m_areas.empty())
    {
        const std::string& areasPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Areas);
        root[areasPropertyName] = Json::Value(Json::arrayValue);
        for (const auto& areas : m_areas)
        {
            root[areasPropertyName].append(areas->SerializeToJsonValue());
        }
    }
    
    if (!m_columns.empty()) 
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetInputIds)] = Json::Value(
                Json::arrayValue);
        for (std::string column: m_columns) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Columns)].append(column);
        }
    }
    
    if (m_rowSpacing != Spacing::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::RowSpacing)] = SpacingToString(m_rowSpacing);
    }
    
    if (m_columnSpacing != Spacing::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ColumnSpacing)] = SpacingToString(m_columnSpacing);
    }

    return root;
}

std::shared_ptr<AreaGridLayout> AreaGridLayout::Deserialize(const Json::Value& json)
{
    std::shared_ptr<Layout> base_layout = Layout::Deserialize(json);
    std::shared_ptr<AreaGridLayout> layout = std::make_shared<AreaGridLayout>();
    layout->SetLayoutContainerType(base_layout->GetLayoutContainerType());
    layout->SetTargetWidth(base_layout->GetTargetWidth());
    layout->SetRowSpacing(ParseUtil::GetEnumValue<Spacing>(json, AdaptiveCardSchemaKey::RowSpacing, Spacing::Default, SpacingFromString));
    layout->SetColumnSpacing(ParseUtil::GetEnumValue<Spacing>(json, AdaptiveCardSchemaKey::ColumnSpacing, Spacing::Default, SpacingFromString));
    layout->SetColumns(ParseUtil::GetStringArray(json, AdaptiveCardSchemaKey::Columns));
    
    if (const auto& areasArray = ParseUtil::GetArray(json, AdaptiveCardSchemaKey::Areas, false); !areasArray.empty())
    {
        auto& areas = layout->GetAreas();
        for (const auto& areaJson : areasArray)
        {
            areas.push_back(GridArea::Deserialize(areaJson));
        }
    }
    return layout;
}

std::shared_ptr<AreaGridLayout> AreaGridLayout::DeserializeFromString(const std::string& jsonString)
{
    return AreaGridLayout::Deserialize(ParseUtil::GetJsonValueFromString(jsonString));
}
