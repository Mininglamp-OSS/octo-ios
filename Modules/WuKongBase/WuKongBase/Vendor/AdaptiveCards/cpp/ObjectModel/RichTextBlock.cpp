// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include <iomanip>
#include <regex>
#include <iostream>
#include <codecvt>
#include "ParseContext.h"
#include "RichTextBlock.h"
#include "DateTimePreparser.h"
#include "ParseUtil.h"
#include "Util.h"
#include "TextInput.h"
#include "CitationRun.h"
#include "TextRun.h"

using namespace AdaptiveCards;

RichTextBlock::RichTextBlock() : BaseCardElement(CardElementType::RichTextBlock), m_hAlignment(std::nullopt)
{
    PopulateKnownPropertiesSet();
}

Json::Value RichTextBlock::SerializeToJsonValue() const
{
    Json::Value root = BaseCardElement::SerializeToJsonValue();

    if (m_hAlignment.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)] =
            HorizontalAlignmentToString(m_hAlignment.value_or(HorizontalAlignment::Left));
    }

    const std::string& inlinesPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Inlines);
    root[inlinesPropertyName] = Json::Value(Json::arrayValue);
    for (const auto& currentInline : GetInlines())
    {
        root[inlinesPropertyName].append(currentInline->SerializeToJsonValue());
    }

    return root;
}

std::optional<HorizontalAlignment> RichTextBlock::GetHorizontalAlignment() const
{
    return m_hAlignment;
}

void RichTextBlock::SetHorizontalAlignment(const std::optional<HorizontalAlignment> value)
{
    m_hAlignment = value;
}

std::vector<std::shared_ptr<Inline>>& RichTextBlock::GetInlines()
{
    return m_inlines;
}

const std::vector<std::shared_ptr<Inline>>& RichTextBlock::GetInlines() const
{
    return m_inlines;
}

std::string RichTextBlock::GetLabelFor() const
{
    return m_labelFor;
}

std::shared_ptr<BaseCardElement> RichTextBlockParser::Deserialize(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ExpectTypeString(json, CardElementType::RichTextBlock);

    std::shared_ptr<RichTextBlock> richTextBlock = BaseCardElement::Deserialize<RichTextBlock>(context, json);
    richTextBlock->SetHorizontalAlignment(ParseUtil::GetOptionalEnumValue<HorizontalAlignment>(
        json, AdaptiveCardSchemaKey::HorizontalAlignment, HorizontalAlignmentFromString));

    auto inlines = ParseUtil::GetElementCollectionOfSingleType<Inline>(
        context, json, AdaptiveCardSchemaKey::Inlines, Inline::Deserialize, false);
    richTextBlock->m_inlines = std::move(inlines);
    richTextBlock->m_labelFor = ParseUtil::GetString(json, AdaptiveCardSchemaKey::LabelFor, "", false);

    if (!richTextBlock->m_labelFor.empty() && !richTextBlock->m_inlines.empty())
    {
        std::string label;
        for (const auto &item: richTextBlock->m_inlines)
        {
            if (item->GetInlineType() == InlineElementType::TextRun)
            {
                auto textRun = std::static_pointer_cast<TextRun>(item);
                label += textRun->GetText() + " ";
            } else if (item->GetInlineType() == InlineElementType::CitationRun) {
                auto citationRun = std::static_pointer_cast<CitationRun>(item);
                label += citationRun->GetText() + " ";
            }
        }

        if (!label.empty())
        {
            // Add label for corresponding ChoiceSetInput
            TextInput::addLabel(richTextBlock->m_labelFor, label);
        }
    }

    return richTextBlock;
}

std::shared_ptr<BaseCardElement> RichTextBlockParser::DeserializeFromString(ParseContext& context, const std::string& jsonString)
{
    return RichTextBlockParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

void RichTextBlock::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Inlines)});
}
