// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards {

    class ProgressBar;

class ProgressBar : public BaseCardElement {
    friend class ProgressBarParser;

    public:
        ProgressBar();
        ProgressBar(const ProgressBar&) = default;
        ProgressBar(ProgressBar&&) = default;
        ProgressBar& operator=(const ProgressBar&) = default;
        ProgressBar& operator=(ProgressBar&&) = default;
        ~ProgressBar() = default;

        ProgressBar(ProgressBarColor color, float max, float value) :BaseCardElement(CardElementType::ProgressBar),
            m_color(color),
            m_max(max),
            m_value(value) {
            PopulateKnownPropertiesSet();
        }

        ProgressBarColor GetColor() const;
        double GetMax() const;
        std::optional<double> GetValue() const;
        const HorizontalAlignment GetHorizontalAlignment() const;

        Json::Value SerializeToJsonValue() const override;
    
        ProgressBarColor GetColor() {
            return m_color;
        }
    
        double GetMax() {
            return m_max;
        }
    
        std::optional<double> GetValue() {
            return m_value;
        }

    private:
        void PopulateKnownPropertiesSet();

        ProgressBarColor m_color;
        double m_max{};
        std::optional<double> m_value{};
        HorizontalAlignment m_horizontalAlignment;
};

class ProgressBarParser : public BaseCardElementParser {

    public:
        ProgressBarParser() = default;
        ProgressBarParser(const ProgressBarParser&) = default;
        ProgressBarParser(ProgressBarParser&&) = default;
        ProgressBarParser& operator=(const ProgressBarParser&) = default;
        ProgressBarParser& operator=(ProgressBarParser&&) = default;
        virtual ~ProgressBarParser() = default;

        std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
        std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
} // namespace AdaptiveCards
