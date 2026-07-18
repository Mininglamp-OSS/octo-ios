// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include <iomanip>
#include <regex>
#include <iostream>
#include <codecvt>
#include "ParseContext.h"
#include "ParseUtil.h"
#include "Util.h"
#include "ProgressRing.h"

using namespace AdaptiveCards;

const static std::string DEFAULT_LABEL = "";
const static LabelPosition DEFAULT_LABEL_POSITION = LabelPosition::Above;
const static ProgressSize DEFAULT_SIZE = ProgressSize::Medium;
const static HorizontalAlignment DEFAULT_HORIZONTAL_ALIGNMENT = HorizontalAlignment::Left;

ProgressRing::ProgressRing() : BaseCardElement(CardElementType::ProgressRing)
    ,m_label(DEFAULT_LABEL), m_labelPosition(DEFAULT_LABEL_POSITION), m_size(DEFAULT_SIZE), m_horizontalAlignment(DEFAULT_HORIZONTAL_ALIGNMENT) {
    PopulateKnownPropertiesSet();
}

void ProgressRing::PopulateKnownPropertiesSet(){
    m_knownProperties.insert({
        AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Label),
        AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::LabelPosition),
        AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size),
        AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment),
    });
}

const std::string ProgressRing::GetLabel() const {
    return m_label;
}

const LabelPosition ProgressRing::GetLabelPosition() const {
    return m_labelPosition;
}

const ProgressSize ProgressRing::GetSize() const {
    return m_size;
}

const HorizontalAlignment ProgressRing::GetHorizontalAlignment() const {
    return m_horizontalAlignment;
}

Json::Value ProgressRing::SerializeToJsonValue() const {
    Json::Value root = BaseCardElement::SerializeToJsonValue();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Label)] = GetLabel();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::LabelPosition)] = LabelPositionToString(GetLabelPosition());
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Size)] = ProgressSizeToString(GetSize());
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::HorizontalAlignment)] = HorizontalAlignmentToString(m_horizontalAlignment);
    return root;
}

std::shared_ptr<BaseCardElement> ProgressRingParser::Deserialize(ParseContext& context, const Json::Value& json) {
    ParseUtil::ExpectTypeString(json, CardElementType::ProgressRing);

    std::shared_ptr<ProgressRing> element = BaseCardElement::Deserialize<ProgressRing>(context, json);
    element->m_label = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Label,
                                            DEFAULT_LABEL, false);
    element->m_labelPosition = ParseUtil::GetEnumValue<LabelPosition>(json, AdaptiveCardSchemaKey::LabelPosition,
                                                                      DEFAULT_LABEL_POSITION, LabelPositionFromString,
                                                                      false);
    element->m_size = ParseUtil::GetEnumValue<ProgressSize>(json, AdaptiveCardSchemaKey::Size,
                                                            DEFAULT_SIZE, ProgressSizeFromString,
                                                            false);
    element->m_horizontalAlignment = ParseUtil::GetEnumValue<HorizontalAlignment>(
            json, AdaptiveCardSchemaKey::HorizontalAlignment,
            DEFAULT_HORIZONTAL_ALIGNMENT, HorizontalAlignmentFromString,
            false);

    return element;
}

std::shared_ptr<BaseCardElement> ProgressRingParser::DeserializeFromString(ParseContext& context, const std::string& jsonString) {
    return ProgressRingParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}



