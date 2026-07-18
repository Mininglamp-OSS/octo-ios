// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards {

    class ProgressRing;

class ProgressRing : public BaseCardElement {
    friend class ProgressRingParser;

    public:
        ProgressRing();
        ProgressRing(const ProgressRing&) = default;
        ProgressRing(ProgressRing&&) = default;
        ProgressRing& operator=(const ProgressRing&) = default;
        ProgressRing& operator=(ProgressRing&&) = default;
        ~ProgressRing() = default;

        const std::string GetLabel() const;
        const LabelPosition GetLabelPosition() const;
        const ProgressSize GetSize() const;
        const HorizontalAlignment GetHorizontalAlignment() const;

        ProgressRing(ProgressSize  progressSize, LabelPosition labelPosition, std::string const& label, HorizontalAlignment horizontalAlignment)
            :BaseCardElement(CardElementType::ProgressRing),
            m_labelPosition(labelPosition),
            m_label(label),
            m_size(progressSize),
            m_horizontalAlignment(horizontalAlignment) {
            PopulateKnownPropertiesSet();
        }

        Json::Value SerializeToJsonValue() const override;
    
        LabelPosition GetLabelPosition() {
            return m_labelPosition;
        }
    
        std::string GetLabel() {
            return m_label;
        }
    
        ProgressSize GetSize() {
            return m_size;
        }
    
        HorizontalAlignment GetHorizontalAlignment() {
            return m_horizontalAlignment;
        }

    private:
        void PopulateKnownPropertiesSet();

        std::string m_label;
        LabelPosition m_labelPosition;
        ProgressSize m_size;
        HorizontalAlignment m_horizontalAlignment;
};

class ProgressRingParser : public BaseCardElementParser {

    public:
        ProgressRingParser() = default;
        ProgressRingParser(const ProgressRingParser&) = default;
        ProgressRingParser(ProgressRingParser&&) = default;
        ProgressRingParser& operator=(const ProgressRingParser&) = default;
        ProgressRingParser& operator=(ProgressRingParser&&) = default;
        virtual ~ProgressRingParser() = default;

        std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
        std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
} // namespace AdaptiveCards
