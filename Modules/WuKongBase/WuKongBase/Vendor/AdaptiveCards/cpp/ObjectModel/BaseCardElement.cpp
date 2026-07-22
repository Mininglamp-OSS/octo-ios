// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "BaseCardElement.h"
#include "AdaptiveCardParseException.h"
#include "ParseUtil.h"
#include "ElementParserRegistration.h"
#include "ShowCardAction.h"
#include "OpenUrlAction.h"
#include "SubmitAction.h"

using namespace AdaptiveCards;

BaseCardElement::BaseCardElement(CardElementType type, Spacing spacing, bool separator, HeightType height, TargetWidthType targetWidthType) :
    m_type(type), m_spacing(spacing), m_height(height), m_targetWidth(targetWidthType), m_separator(separator), m_isVisible(true)
{
    SetTypeString(CardElementTypeToString(type));
    PopulateKnownPropertiesSet();
}

BaseCardElement::BaseCardElement(CardElementType type) :
    m_type(type), m_spacing(Spacing::Default), m_height(HeightType::Auto), m_targetWidth(TargetWidthType::Default), m_separator(false), m_isVisible(true)
{
    SetTypeString(CardElementTypeToString(type));
    PopulateKnownPropertiesSet();
}

void BaseCardElement::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Height),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::IsVisible),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MinHeight),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetWidth),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Separator),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Spacing)});
}

bool BaseCardElement::GetSeparator() const
{
    return m_separator;
}

void BaseCardElement::SetSeparator(bool value)
{
    m_separator = value;
}

Spacing BaseCardElement::GetSpacing() const
{
    return m_spacing;
}

void BaseCardElement::SetSpacing(Spacing value)
{
    m_spacing = value;
}

HeightType BaseCardElement::GetHeight() const
{
    return m_height;
}

void BaseCardElement::SetHeight(HeightType value)
{
    m_height = value;
}

TargetWidthType BaseCardElement::GetTargetWidth() const
{
    return m_targetWidth;
}

void BaseCardElement::SetTargetWidth(TargetWidthType value)
{
    m_targetWidth = value;
}

bool BaseCardElement::GetIsVisible() const
{
    return m_isVisible;
}

void BaseCardElement::SetIsVisible(bool value)
{
    m_isVisible = value;
}

std::optional<std::string> BaseCardElement::GetAreaGridName() const
{
    return m_areaGridName;
}

void BaseCardElement::SetAreaGridName(const std::optional<std::string> &value)
{
    m_areaGridName = value;
}

std::string BaseCardElement::GetNonOptionalAreaGridName() const
{
    return m_nonOptionalAreaGridName;
}

void BaseCardElement::SetNonOptionalAreaGridName(const std::string &value)
{
    m_nonOptionalAreaGridName = value;
}

CardElementType BaseCardElement::GetElementType() const
{
    return m_type;
}

Json::Value BaseCardElement::SerializeToJsonValue() const
{
    Json::Value root = BaseElement::SerializeToJsonValue();

    if (m_height != HeightType::Auto)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Height)] = HeightTypeToString(GetHeight());
    }

    if (m_spacing != Spacing::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Spacing)] = SpacingToString(m_spacing);
    }

    if (m_separator)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Separator)] = true;
    }

    if (m_areaGridName.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::AreaGridName)] = m_areaGridName.value();
    }

    if (m_targetWidth != TargetWidthType::Default)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetWidth)] = TargetWidthTypeToString(GetTargetWidth());
    }

    if (!m_isVisible)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::IsVisible)] = false;
    }

    return root;
}

Json::Value BaseCardElement::SerializeSelectAction(const std::shared_ptr<BaseActionElement>& selectAction)
{
    if (selectAction != nullptr)
    {
        return selectAction->SerializeToJsonValue();
    }
    return Json::Value();
}

void BaseCardElement::ParseJsonObject(AdaptiveCards::ParseContext& context, const Json::Value& json, std::shared_ptr<BaseElement>& element)
{
    const std::string typeString = ParseUtil::GetTypeAsString(json);
    std::shared_ptr<BaseCardElementParser> parser = context.elementParserRegistration->GetParser(typeString);

    if (parser == nullptr)
    {
        parser = context.elementParserRegistration->GetParser("Unknown");
    }

    auto parsedElement = parser->Deserialize(context, json);
    if (parsedElement != nullptr)
    {
        element = std::move(parsedElement);
        return;
    }

    throw AdaptiveCardParseException(ErrorStatusCode::InvalidPropertyValue, "Unable to parse element of type " + typeString);
}

bool BaseCardElement::MeetsTargetWidthRequirement(HostWidth hostWidth)  const
{
    if (m_targetWidth == TargetWidthType::Default || hostWidth == HostWidth::Default)
    {
        return true;
    }

    switch(m_targetWidth) {
        case TargetWidthType::Wide:
            return hostWidth == HostWidth::Wide;
        case TargetWidthType::Standard:
            return hostWidth == HostWidth::Standard;
        case TargetWidthType::Narrow:
            return hostWidth == HostWidth::Narrow;
        case TargetWidthType::VeryNarrow:
            return hostWidth == HostWidth::VeryNarrow;
        case TargetWidthType::AtLeastWide:
            return hostWidth >= HostWidth::Wide;
        case TargetWidthType::AtLeastStandard:
            return hostWidth >= HostWidth::Standard;
        case TargetWidthType::AtLeastNarrow:
            return hostWidth >= HostWidth::Narrow;
        case TargetWidthType::AtLeastVeryNarrow:
            return hostWidth >= HostWidth::VeryNarrow;
        case TargetWidthType::AtMostWide:
            return hostWidth <= HostWidth::Wide;
        case TargetWidthType::AtMostStandard:
            return hostWidth <= HostWidth::Standard;
        case TargetWidthType::AtMostNarrow:
            return hostWidth <= HostWidth::Narrow;
        case TargetWidthType::AtMostVeryNarrow:
            return hostWidth <= HostWidth::VeryNarrow;
        default:
            return true;
    }
}

std::shared_ptr<BaseCardElement> BaseCardElement::DeserializeBasePropertiesFromString(ParseContext& context, const std::string& jsonString)
{
    return BaseCardElement::DeserializeBaseProperties(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<BaseCardElement> BaseCardElement::DeserializeBaseProperties(ParseContext& context, const Json::Value& json)
{
    std::shared_ptr<BaseCardElement> baseCardElement = std::make_shared<BaseCardElement>();
    DeserializeBaseProperties(context, json, baseCardElement);
    return baseCardElement;
}

void BaseCardElement::DeserializeBaseProperties(ParseContext& context, const Json::Value& json, std::shared_ptr<BaseCardElement>& element)
{
    ParseUtil::ThrowIfNotJsonObject(json);

    element->DeserializeBase<BaseCardElement>(context, json);
    element->SetCanFallbackToAncestor(context.GetCanFallbackToAncestor());
    element->SetHeight(ParseUtil::GetEnumValue<HeightType>(json, AdaptiveCardSchemaKey::Height, HeightType::Auto, HeightTypeFromString));
    element->SetTargetWidth(ParseUtil::GetEnumValue<TargetWidthType>(json, AdaptiveCardSchemaKey::TargetWidth, TargetWidthType::Default, TargetWidthTypeFromString));
    element->SetIsVisible(ParseUtil::GetBool(json, AdaptiveCardSchemaKey::IsVisible, true));
    element->SetSeparator(ParseUtil::GetBool(json, AdaptiveCardSchemaKey::Separator, false));
    element->SetSpacing(ParseUtil::GetEnumValue<Spacing>(json, AdaptiveCardSchemaKey::Spacing, Spacing::Default, SpacingFromString));
    element->SetAreaGridName(ParseUtil::GetString(json, AdaptiveCardSchemaKey::AreaGridName, "", false));
    element->SetNonOptionalAreaGridName(ParseUtil::GetOptionalString(json, AdaptiveCardSchemaKey::AreaGridName).has_value() ?
    ParseUtil::GetString(json, AdaptiveCardSchemaKey::AreaGridName) : "");
}
