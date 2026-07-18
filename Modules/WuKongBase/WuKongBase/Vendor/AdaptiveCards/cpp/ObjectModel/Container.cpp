// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "Container.h"
#include "TextBlock.h"
#include "ColumnSet.h"
#include "ParseUtil.h"
#include "Util.h"
#include "FlowLayout.h"
#include "AreaGridLayout.h"

using namespace AdaptiveCards;

// This ctor used by types that want to be exactly like Container, but with a different name (e.g. TableCell)
Container::Container(CardElementType derivedType) : StyledCollectionElement(derivedType)
{
    PopulateKnownPropertiesSet();
}

Container::Container() : StyledCollectionElement(CardElementType::Container)
{
    PopulateKnownPropertiesSet();
}

const std::vector<std::shared_ptr<BaseCardElement>>& Container::GetItems() const
{
    return m_items;
}

std::vector<std::shared_ptr<BaseCardElement>>& Container::GetItems()
{
    return m_items;
}

// value is present if and only if "rtl" property is explicitly set
std::optional<bool> Container::GetRtl() const
{
    return m_rtl;
}

void Container::SetRtl(const std::optional<bool>& value)
{
    m_rtl = value;
}

std::vector<std::shared_ptr<Layout>>& Container::GetLayouts()
{
    return m_layouts;
}

const std::vector<std::shared_ptr<Layout>>& Container::GetLayouts() const
{
    return m_layouts;
}

void Container::SetLayouts(const std::vector<std::shared_ptr<Layout>>& value)
{
    m_layouts = value;
}

Json::Value Container::SerializeToJsonValue() const
{
    Json::Value root = StyledCollectionElement::SerializeToJsonValue();
    std::string const& itemsPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Items);
    root[itemsPropertyName] = Json::Value(Json::arrayValue);
    for (const auto& cardElement : m_items)
    {
        root[itemsPropertyName].append(cardElement->SerializeToJsonValue());
    }
    
    std::string const& layoutsPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Layouts);
    root[layoutsPropertyName] = Json::Value(Json::arrayValue);
    for (const auto& layout : m_layouts)
    {
        root[layoutsPropertyName].append(layout->SerializeToJsonValue());
    }

    if (m_rtl.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Rtl)] = m_rtl.value_or("");
    }

    return root;
}

std::shared_ptr<BaseCardElement> ContainerParser::Deserialize(ParseContext& context, const Json::Value& value)
{
    ParseUtil::ExpectTypeString(value, CardElementType::Container);

    auto container = StyledCollectionElement::Deserialize<Container>(context, value);

    container->SetRtl(ParseUtil::GetOptionalBool(value, AdaptiveCardSchemaKey::Rtl));
        
    if (const auto& layoutArray = ParseUtil::GetArray(value, AdaptiveCardSchemaKey::Layouts, false); !layoutArray.empty())
    {
        auto& layouts = container->GetLayouts();
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
    
    return container;
}

void Container::DeserializeChildren(ParseContext& context, const Json::Value& value)
{
    // Parse items
    auto cardElements = ParseUtil::GetElementCollection<BaseCardElement>(
        true, // isTopToBottomContainer
        context,
        value,
        AdaptiveCardSchemaKey::Items,
        false); // isRequired
    m_items = std::move(cardElements);
}

std::shared_ptr<BaseCardElement> ContainerParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return ContainerParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

void Container::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Bleed),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Rtl),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::VerticalContentAlignment),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Items)});
}

void Container::GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo)
{
    auto items = GetItems();
    StyledCollectionElement::GetResourceInformation<BaseCardElement>(resourceInfo, items);
    return;
}
