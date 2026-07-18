// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards
{
class RatingLabelParser;

class RatingLabel : public BaseCardElement
{
    friend RatingLabelParser;

public:
    RatingLabel();
    RatingLabel(const RatingLabel&) = default;
    RatingLabel(RatingLabel&&) = default;
    RatingLabel& operator=(const RatingLabel&) = default;
    RatingLabel& operator=(RatingLabel&&) = default;
    ~RatingLabel() = default;

    Json::Value SerializeToJsonValue() const override;

    std::optional<HorizontalAlignment> GetHorizontalAlignment() const;
    void SetHorizontalAlignment(const std::optional<HorizontalAlignment> value);

    double GetValue() const;
    void SetValue(const double value);

    double GetMax() const;
    void SetMax(const double value);
    
    RatingSize GetRatingSize() const;
    void SetRatingSize(RatingSize value);
    
    RatingColor GetRatingColor() const;
    void SetRatingColor(RatingColor value);
    
    RatingStyle GetRatingStyle() const;
    void SetRatingStyle(RatingStyle value);
    
    std::optional<unsigned int> GetCount() const;
    void SetCount(const std::optional<unsigned int>& value);

private:
    void PopulateKnownPropertiesSet();
    
    std::optional<HorizontalAlignment> m_hAlignment;
    double m_value;
    double m_max;
    RatingSize m_size;
    RatingColor m_color;
    RatingStyle m_style;
    std::optional<unsigned int>m_count;
};

class RatingLabelParser : public BaseCardElementParser
{
public:
    RatingLabelParser() = default;
    RatingLabelParser(const RatingLabelParser&) = default;
    RatingLabelParser(RatingLabelParser&&) = default;
    RatingLabelParser& operator=(const RatingLabelParser&) = default;
    RatingLabelParser& operator=(RatingLabelParser&&) = default;
    virtual ~RatingLabelParser() = default;

    std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
    std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
};
} // namespace AdaptiveCards
