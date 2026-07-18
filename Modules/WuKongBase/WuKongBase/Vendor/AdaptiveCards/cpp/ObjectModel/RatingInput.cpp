// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "RatingInput.h"
#include "ParseUtil.h"
#include "Util.h"

using namespace AdaptiveCards;

RatingInput::RatingInput() : BaseInputElement(CardElementType::RatingInput)
{
    PopulateKnownPropertiesSet();
}

Json::Value RatingInput::SerializeToJsonValue() const
{
    Json::Value root = BaseInputElement::SerializeToJsonValue();
    
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Max)] = m_max;

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Value)] = m_value;
    
    if (m_hAlignment.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)] =
            HorizontalAlignmentToString(m_hAlignment.value_or(HorizontalAlignment::Left));
    }
    
    if (m_size != RatingSize::Medium)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size)] = RatingSizeToString(m_size);
    }
    
    if (m_color != RatingColor::Neutral)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color)] = RatingColorToString(m_color);
    }

    return root;
}

std::optional<HorizontalAlignment> RatingInput::GetHorizontalAlignment() const
{
    return m_hAlignment;
}

void RatingInput::SetHorizontalAlignment(const std::optional<HorizontalAlignment> value)
{
    m_hAlignment = value;
}

RatingSize RatingInput::GetRatingSize() const
{
    return m_size;
}

void RatingInput::SetRatingSize(RatingSize value)
{
    m_size = value;
}

RatingColor RatingInput::GetRatingColor() const
{
    return m_color;
}

void RatingInput::SetRatingColor(RatingColor value)
{
    m_color = value;
}

double RatingInput::GetValue() const
{
    return m_value;
}

void RatingInput::SetValue(const double value)
{
    m_value = value;
}

double RatingInput::GetMax() const
{
    return m_max;
}

void RatingInput::SetMax(const double value)
{
    m_max = value;
}

std::shared_ptr<BaseCardElement> RatingInputParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::RatingInput);

    std::shared_ptr<RatingInput> ratingInput = BaseInputElement::Deserialize<RatingInput>(context, json);
    ratingInput->SetValue(ParseUtil::GetDouble(json, AdaptiveCardSchemaKey::Value, 0));
    ratingInput->SetMax(ParseUtil::GetDouble(json, AdaptiveCardSchemaKey::Max, 5));
    ratingInput->SetHorizontalAlignment(ParseUtil::GetEnumValue<HorizontalAlignment>(
        json, AdaptiveCardSchemaKey::HorizontalAlignment, HorizontalAlignment::Left, HorizontalAlignmentFromString));
    ratingInput->SetRatingSize(ParseUtil::GetEnumValue<RatingSize>(json, AdaptiveCardSchemaKey::Size, RatingSize::Medium, RatingSizeFromString));
    ratingInput->SetRatingColor(ParseUtil::GetEnumValue<RatingColor>(json, AdaptiveCardSchemaKey::Color, RatingColor::Neutral, RatingColorFromString));
    
    if (ratingInput->GetValue() > ratingInput->GetMax())
    {
        ratingInput->SetMax(ratingInput->GetValue());
    }

    return ratingInput;
}

std::shared_ptr<BaseCardElement> RatingInputParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return RatingInputParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

void RatingInput::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
                             {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Value),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Max),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)});
}
