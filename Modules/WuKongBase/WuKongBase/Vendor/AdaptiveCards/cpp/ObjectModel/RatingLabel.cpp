// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "ParseContext.h"
#include "TextBlock.h"
#include "DateTimePreparser.h"
#include "ParseUtil.h"
#include "Util.h"
#include "RatingLabel.h"

using namespace AdaptiveCards;

RatingLabel::RatingLabel() :
    BaseCardElement(CardElementType::RatingLabel), m_hAlignment(std::nullopt), m_max(5)
{
    PopulateKnownPropertiesSet();
}

Json::Value RatingLabel::SerializeToJsonValue() const
{
    Json::Value root = BaseCardElement::SerializeToJsonValue();

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Max)] = m_max;
    
    if (m_count)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Count)] = *m_count;
    }

    if (m_value)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Value)] = m_value;
    }
    
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

std::optional<HorizontalAlignment> RatingLabel::GetHorizontalAlignment() const
{
    return m_hAlignment;
}

void RatingLabel::SetHorizontalAlignment(const std::optional<HorizontalAlignment> value)
{
    m_hAlignment = value;
}

RatingSize RatingLabel::GetRatingSize() const
{
    return m_size;
}

void RatingLabel::SetRatingSize(RatingSize value)
{
    m_size = value;
}

RatingColor RatingLabel::GetRatingColor() const
{
    return m_color;
}

void RatingLabel::SetRatingColor(RatingColor value)
{
    m_color = value;
}

RatingStyle RatingLabel::GetRatingStyle() const
{
    return m_style;
}

void RatingLabel::SetRatingStyle(RatingStyle value)
{
    m_style = value;
}

double RatingLabel::GetValue() const
{
    return m_value;
}

void RatingLabel::SetValue(const double value)
{
    m_value = value;
}

double RatingLabel::GetMax() const
{
    return m_max;
}

void RatingLabel::SetMax(const double value)
{
    m_max = value;
}

std::optional<unsigned int> RatingLabel::GetCount() const
{
    return m_count;
}

void RatingLabel::SetCount(const std::optional<unsigned int>& value)
{
    m_count = value;
}

std::shared_ptr<BaseCardElement> RatingLabelParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::RatingLabel);

    std::shared_ptr<RatingLabel> ratingLabel = BaseCardElement::Deserialize<RatingLabel>(context, json);
    ratingLabel->SetValue(ParseUtil::GetDouble(json, AdaptiveCardSchemaKey::Value, 0, true));
    ratingLabel->SetMax(ParseUtil::GetDouble(json, AdaptiveCardSchemaKey::Max, 5));
    ratingLabel->SetCount(ParseUtil::GetOptionalInt(json, AdaptiveCardSchemaKey::Count));
    ratingLabel->SetHorizontalAlignment(ParseUtil::GetEnumValue<HorizontalAlignment>(
        json, AdaptiveCardSchemaKey::HorizontalAlignment, HorizontalAlignment::Left, HorizontalAlignmentFromString));
    ratingLabel->SetRatingSize(ParseUtil::GetEnumValue<RatingSize>(json, AdaptiveCardSchemaKey::Size, RatingSize::Medium, RatingSizeFromString));
    ratingLabel->SetRatingColor(ParseUtil::GetEnumValue<RatingColor>(json, AdaptiveCardSchemaKey::Color, RatingColor::Neutral, RatingColorFromString));
    ratingLabel->SetRatingStyle(ParseUtil::GetEnumValue<RatingStyle>(json, AdaptiveCardSchemaKey::Style, RatingStyle::Default, RatingStyleFromString));
    
    if (ratingLabel->GetValue() > ratingLabel->GetMax())
    {
        ratingLabel->SetMax(ratingLabel->GetValue());
    }

    return ratingLabel;
}

std::shared_ptr<BaseCardElement> RatingLabelParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return RatingLabelParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

void RatingLabel::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
                             {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Value),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Max),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Count),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Color),
                                 AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)});
}
