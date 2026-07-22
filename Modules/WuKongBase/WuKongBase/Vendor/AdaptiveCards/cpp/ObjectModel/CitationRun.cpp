// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "CitationRun.h"

using namespace AdaptiveCards;

CitationRun::CitationRun() :
        Inline(InlineElementType::CitationRun), m_textElementProperties(std::make_shared<RichTextElementProperties>()),
        m_referenceIndex(1) {
    PopulateKnownPropertiesSet();
}

void CitationRun::PopulateKnownPropertiesSet() {
    m_textElementProperties->PopulateKnownPropertiesSet(m_knownProperties);
}

Json::Value CitationRun::SerializeToJsonValue() const {
    Json::Value root{};
    root = m_textElementProperties->SerializeToJsonValue(root);
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Type)] = GetInlineTypeString();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ReferenceIndex)] = m_referenceIndex;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Text)] = m_textElementProperties->GetText();
    return root;
}

int CitationRun::GetReferenceIndex() const {
    return m_referenceIndex;
}

std::string CitationRun::GetText() const {
    return m_textElementProperties->GetText();
}

DateTimePreparser CitationRun::GetTextForDateParsing() const {
    return m_textElementProperties->GetTextForDateParsing();
}

std::shared_ptr<Inline> CitationRun::Deserialize(ParseContext& context, const Json::Value& json) {
    std::shared_ptr<CitationRun> inlineCitationRun = std::make_shared<CitationRun>();
    ParseUtil::ExpectTypeString(json, InlineElementTypeToString(InlineElementType::CitationRun));

    inlineCitationRun->m_textElementProperties->Deserialize(context, json);
    inlineCitationRun->m_referenceIndex = ParseUtil::GetInt(json, AdaptiveCardSchemaKey::ReferenceIndex, 1, true);
    HandleUnknownProperties(json, inlineCitationRun->m_knownProperties, inlineCitationRun->m_additionalProperties);

    return inlineCitationRun;
}
