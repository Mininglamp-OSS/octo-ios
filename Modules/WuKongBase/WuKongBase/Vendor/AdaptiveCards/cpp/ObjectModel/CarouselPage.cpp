//
//  CarouselPage.cpp
//  AdaptiveCards
//
//  Created by Abhishek Gupta on 02/09/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#include "CarouselPage.h"
#include "FlowLayout.h"
#include "AreaGridLayout.h"
#include "pch.h"

using namespace AdaptiveCards;

CarouselPage::CarouselPage() : StyledCollectionElement(CardElementType::CarouselPage)
{
    PopulateKnownPropertiesSet();
}

// value is present if and only if "rtl" property is explicitly set
std::optional<bool> CarouselPage::GetRtl() const
{
    return m_rtl;
}

void CarouselPage::SetRtl(const std::optional<bool>& value)
{
    m_rtl = value;
}

Json::Value CarouselPage::SerializeToJsonValue() const
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

const std::vector<std::shared_ptr<BaseCardElement>>& CarouselPage::GetItems() const
{
    return m_items;
}

std::vector<std::shared_ptr<BaseCardElement>>& CarouselPage::GetItems()
{
    return m_items;
}

std::vector<std::shared_ptr<Layout>>& CarouselPage::GetLayouts()
{
    return m_layouts;
}

void CarouselPage::SetLayouts(const std::vector<std::shared_ptr<Layout>>& value)
{
    m_layouts = value;
}

std::shared_ptr<CarouselPage> CarouselPage::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::CarouselPage);
    return CarouselPage::DeserializeWithoutCheckingType(context, json);
}

std::shared_ptr<CarouselPage> CarouselPage::DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& json)
{
    std::shared_ptr<CarouselPage> carouselPage = StyledCollectionElement::Deserialize<CarouselPage>(context, json);
    carouselPage->SetRtl(ParseUtil::GetOptionalBool(json, AdaptiveCardSchemaKey::Rtl));

    if (const auto& layoutArray = ParseUtil::GetArray(json, AdaptiveCardSchemaKey::Layouts, false); !layoutArray.empty())
    {
        auto &layouts = carouselPage->GetLayouts();
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

    return carouselPage;
}

void CarouselPage::DeserializeChildren(ParseContext& context, const Json::Value& value)
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

void CarouselPage::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
            {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Items),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Layouts)});
}

void CarouselPage::GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo)
{
    auto items = GetItems();
    StyledCollectionElement::GetResourceInformation<BaseCardElement>(resourceInfo, items);
    return;
}

std::shared_ptr<BaseCardElement> CarouselPageParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return CarouselPageParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<BaseCardElement> CarouselPageParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::CarouselPage);
    return CarouselPageParser::DeserializeWithoutCheckingType(context, json);
}

std::shared_ptr<BaseCardElement> CarouselPageParser::DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& json)
{
    return CarouselPage::DeserializeWithoutCheckingType(context, json);
}
