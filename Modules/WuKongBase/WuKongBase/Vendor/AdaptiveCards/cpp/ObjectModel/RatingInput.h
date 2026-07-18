// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseInputElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards
{
class RatingInput : public BaseInputElement
{
public:
    RatingInput();
    RatingInput(const RatingInput&) = default;
    RatingInput(RatingInput&&) = default;
    RatingInput& operator=(const RatingInput&) = default;
    RatingInput& operator=(RatingInput&&) = default;
    ~RatingInput() = default;

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

private:
    void PopulateKnownPropertiesSet();

    std::optional<HorizontalAlignment> m_hAlignment;
    double m_value;
    double m_max;
    RatingSize m_size;
    RatingColor m_color;
};

class RatingInputParser : public BaseCardElementParser
{
public:
    RatingInputParser() = default;
    RatingInputParser(const RatingInputParser&) = default;
    RatingInputParser(RatingInputParser&&) = default;
    RatingInputParser& operator=(const RatingInputParser&) = default;
    RatingInputParser& operator=(RatingInputParser&&) = default;
    virtual ~RatingInputParser() = default;

    std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
    std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
};
} // namespace AdaptiveCards
