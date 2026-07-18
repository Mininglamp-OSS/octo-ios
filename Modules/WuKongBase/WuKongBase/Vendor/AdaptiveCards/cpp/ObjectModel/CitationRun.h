// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "ElementParserRegistration.h"
#include "Inline.h"
#include "RichTextElementProperties.h"

namespace AdaptiveCards {

    class CitationRun : public Inline {
    public:
        CitationRun();
        CitationRun(const CitationRun&) = default;
        CitationRun(CitationRun&&) = default;
        CitationRun& operator=(const CitationRun&) = default;
        CitationRun& operator=(CitationRun&&) = default;
        ~CitationRun() = default;

        Json::Value SerializeToJsonValue() const override;

        int GetReferenceIndex() const;
        std::string GetText() const;
        DateTimePreparser GetTextForDateParsing() const;

        static std::shared_ptr<Inline> Deserialize(ParseContext& context, const Json::Value& root);

private:
    std::shared_ptr<RichTextElementProperties> m_textElementProperties;
    int m_referenceIndex;

    void PopulateKnownPropertiesSet();
};
} // namespace AdaptiveCards
