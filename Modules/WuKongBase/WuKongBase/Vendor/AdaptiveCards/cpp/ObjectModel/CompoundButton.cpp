// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "Icon.h"
#include "ParseUtil.h"
#include "ParseContext.h"
#include "Util.h"
#include "CompoundButton.h"


using namespace AdaptiveCards;

CompoundButton::CompoundButton() :
        BaseCardElement(CardElementType::CompoundButton)
{
    PopulateKnownPropertiesSet();
}

Json::Value CompoundButton::SerializeToJsonValue() const
{
    Json::Value root = BaseCardElement::SerializeToJsonValue();

    if (!m_badge.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Badge)] = m_badge;
    }

    if (!m_title.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Title)] = m_title;
    }

    if (!m_description.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Description)] = m_description;
    }

    if(m_icon != nullptr)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Icon)] = m_icon -> SerializeToJsonValue();
    }

    if (m_selectAction != nullptr)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction)] =
                BaseCardElement::SerializeSelectAction(m_selectAction);
    }

    return root;
}

std::string CompoundButton::getBadge() const
{
    return m_badge;
}

void CompoundButton::setBadge(std::string value)
{
    m_badge = value;
}

std::string CompoundButton::getTitle() const
{
    return m_title;
}

void CompoundButton::setTitle(const std::string value)
{
    m_title = value;
}

std::string CompoundButton::getDescription() const
{
    return m_description;
}

void CompoundButton::setDescription(const std::string value)
{
    m_description = value;
}

std::shared_ptr<BaseActionElement> CompoundButton::GetSelectAction() const
{
    return m_selectAction;
}

void CompoundButton::SetSelectAction(const std::shared_ptr<BaseActionElement> action) {
    m_selectAction = action;
}

std::shared_ptr<AdaptiveCards::IconInfo> CompoundButton::getIcon() const
{
    return m_icon;
}

void CompoundButton::setIcon(const std::shared_ptr<AdaptiveCards::IconInfo> value)
{
    m_icon = value;
}

std::shared_ptr<BaseCardElement> CompoundButtonParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return CompoundButtonParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<BaseCardElement> CompoundButtonParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::CompoundButton);
    return CompoundButtonParser::DeserializeWithoutCheckingType(context, json);
}

std::shared_ptr<BaseCardElement> CompoundButtonParser::DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& json)
{
    std::shared_ptr<CompoundButton> compoundButton = BaseCardElement::Deserialize<CompoundButton>(context, json);
    compoundButton->setBadge(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Badge));
    compoundButton->setTitle(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Title, true));
    compoundButton-> setDescription(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Description));
    auto icon = ParseUtil::DeserializeValue<IconInfo>(json,
                                                      AdaptiveCardSchemaKey::Icon,
                                                      IconInfo::Deserialize,
                                                      false);
    compoundButton->SetSelectAction(ParseUtil::GetAction(context, json, AdaptiveCardSchemaKey::SelectAction, false));
    compoundButton->setIcon(icon);
    compoundButton->SetSelectAction(ParseUtil::GetAction(context, json, AdaptiveCardSchemaKey::SelectAction, false));
    return compoundButton;
}

void CompoundButton::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
            {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Badge),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Title),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Description),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Icon),
             AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction)});
}
