// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "Column.h"
#include "ParseContext.h"
#include "ParseUtil.h"
#include "Util.h"
#include "FlowLayout.h"
#include "AreaGridLayout.h"

using namespace AdaptiveCards;

Column::Column() : StyledCollectionElement(CardElementType::Column), m_width("Auto"), m_pixelWidth(0)
{
    PopulateKnownPropertiesSet();
}

std::string Column::GetWidth() const
{
    return m_width;
}

void Column::SetWidth(const std::string& value)
{
    SetWidth(value, nullptr);
}

void Column::SetWidth(const std::string& value, std::vector<std::shared_ptr<AdaptiveCards::AdaptiveCardParseWarning>>* warnings)
{
    m_width = ParseUtil::ToLowercase(value);
    m_pixelWidth = ParseSizeForPixelSize(m_width, warnings).value_or(0);
}

// explicit width takes precedence over relative width
int Column::GetPixelWidth() const
{
    return m_pixelWidth;
}

void Column::SetPixelWidth(const int value)
{
    m_pixelWidth = value;
    std::ostringstream pixelString;
    pixelString << value << "px";
    m_width = pixelString.str();
}

const std::vector<std::shared_ptr<BaseCardElement>>& Column::GetItems() const
{
    return m_items;
}

std::vector<std::shared_ptr<BaseCardElement>>& Column::GetItems()
{
    return m_items;
}

// value is present if and only if "rtl" property is explicitly set
std::optional<bool> Column::GetRtl() const
{
    return m_rtl;
}

void Column::SetRtl(const std::optional<bool>& value)
{
    m_rtl = value;
}

std::vector<std::shared_ptr<Layout>>& Column::GetLayouts()
{
    return m_layouts;
}

const std::vector<std::shared_ptr<Layout>>& Column::GetLayouts() const
{
    return m_layouts;
}

void Column::SetLayouts(const std::vector<std::shared_ptr<Layout>>& value)
{
    m_layouts = value;
}

std::string Column::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value Column::SerializeToJsonValue() const
{
    Json::Value root = StyledCollectionElement::SerializeToJsonValue();

    if (!m_width.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Width)] = m_width;
    }

    const std::string& propertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Items);
    root[propertyName] = Json::Value(Json::arrayValue);
    for (const auto& cardElement : m_items)
    {
        root[propertyName].append(cardElement->SerializeToJsonValue());
    }

    if (m_rtl.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Rtl)] = m_rtl.value_or("");
    }

    return root;
}

void Column::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Items),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Rtl),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Width),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::VerticalContentAlignment)});
}

void Column::GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo)
{
    auto columnItems = GetItems();
    StyledCollectionElement::GetResourceInformation<BaseCardElement>(resourceInfo, columnItems);
    return;
}

void Column::DeserializeChildren(ParseContext& context, const Json::Value& value)
{
    // Parse Items
    auto cardElements = ParseUtil::GetElementCollection<BaseCardElement>(
        true, // isTopToBottomContainer
        context,
        value,
        AdaptiveCardSchemaKey::Items,
        false); // isRequired
    m_items = std::move(cardElements);
}

std::shared_ptr<BaseCardElement> ColumnParser::Deserialize(ParseContext& context, const Json::Value& value)
{
    auto column = StyledCollectionElement::Deserialize<Column>(context, value);

    const auto& fallbackElement = column->GetFallbackContent();
    if (fallbackElement)
    {
        bool isFallbackColumn;
        try
        {
            isFallbackColumn = CardElementTypeFromString(fallbackElement->GetElementTypeString()) == CardElementType::Column;
        }
        catch (const std::out_of_range&)
        {
            isFallbackColumn = false;
        }

        if (!isFallbackColumn)
        {
            context.warnings.emplace_back(std::make_shared<AdaptiveCardParseWarning>(
                WarningStatusCode::UnknownElementType, "Column Fallback must be a Column. Fallback content dropped."));

            column->SetFallbackContent(nullptr);
            column->SetFallbackType(FallbackType::None);
        }
    }

    std::string columnWidth = ParseUtil::GetValueAsString(value, AdaptiveCardSchemaKey::Width);
    if (columnWidth == "")
    {
        // Look in "size" for back-compat with pre V1.0 cards
        columnWidth = ParseUtil::GetValueAsString(value, AdaptiveCardSchemaKey::Size);
    }

    column->SetWidth(ParseUtil::ToLowercase(columnWidth), &context.warnings);

    column->SetRtl(ParseUtil::GetOptionalBool(value, AdaptiveCardSchemaKey::Rtl));
    
    if (const auto& layoutArray = ParseUtil::GetArray(value, AdaptiveCardSchemaKey::Layouts, false); !layoutArray.empty())
    {
        auto& layouts = column->GetLayouts();
        for (const auto& layoutJson : layoutArray)
        {
            std::shared_ptr<Layout> layout = Layout::Deserialize(layoutJson);
            if(layout->GetLayoutContainerType() == LayoutContainerType::Flow)
            {
                layouts.push_back(FlowLayout::Deserialize(layoutJson));
            }
            else if (layout->GetLayoutContainerType() == LayoutContainerType::AreaGrid)
            {
                std::shared_ptr<AreaGridLayout> areaGridLayout = AreaGridLayout::Deserialize(layoutJson);
                if (areaGridLayout->GetAreas().size() == 0 && areaGridLayout->GetColumns().size() == 0)
                {
                    // this needs to be stack layout
                    std::shared_ptr<Layout> stackLayout = std::make_shared<Layout>();
                    stackLayout->SetLayoutContainerType(LayoutContainerType::Stack);
                    layouts.push_back(stackLayout);
                }
                else if (areaGridLayout->GetAreas().size() == 0)
                {
                    // this needs to be flow layout
                    std::shared_ptr<FlowLayout> flowLayout = std::make_shared<FlowLayout>();
                    flowLayout->SetLayoutContainerType(LayoutContainerType::Flow);
                    layouts.push_back(flowLayout);
                }
                else
                {
                   layouts.push_back(AreaGridLayout::Deserialize(layoutJson));
                }
            }
        }
    }

    return column;
}

std::shared_ptr<BaseCardElement> ColumnParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return ColumnParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}
