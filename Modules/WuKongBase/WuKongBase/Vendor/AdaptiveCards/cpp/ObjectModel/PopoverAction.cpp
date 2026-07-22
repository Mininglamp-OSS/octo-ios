// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "SharedAdaptiveCard.h"
#include "ParseUtil.h"
#include "PopoverAction.h"
#include "ParseContext.h"

using namespace AdaptiveCards;

static const bool DEFAULT_DISPLAY_ARROW = true;
static const std::string DEFAULT_MAX_POPOVER_WIDTH = "";
static const LabelPosition DEFAULT_POSITION = LabelPosition::Above;

PopoverAction::PopoverAction() : BaseActionElement(ActionType::Popover),
    m_displayArrow(DEFAULT_DISPLAY_ARROW), m_position(DEFAULT_POSITION) {
    PopulateKnownPropertiesSet();
}

Json::Value PopoverAction::SerializeToJsonValue() const {
    Json::Value root = BaseActionElement::SerializeToJsonValue();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Content)] = GetContent()->SerializeToJsonValue();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::DisplayArrow)] = GetDisplayArrow();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MaxPopoverWidth)] = GetMaxPopoverWidth();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Position)] = LabelPositionToString(GetPosition());
    return root;
}

void PopoverAction::PopulateKnownPropertiesSet() {
    m_knownProperties.insert({AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Content)});
    m_knownProperties.insert({AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::DisplayArrow)});
    m_knownProperties.insert({AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MaxPopoverWidth)});
    m_knownProperties.insert({AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Position)});
}

const std::shared_ptr<BaseCardElement> PopoverAction::GetContent() const {
    return m_content;
}

const bool PopoverAction::GetDisplayArrow() const {
    return m_displayArrow;
}

const std::string PopoverAction::GetMaxPopoverWidth() const {
    return m_maxPopoverWidth;
}

const LabelPosition PopoverAction::GetPosition() const {
    return m_position;
}

std::shared_ptr<BaseActionElement> PopoverActionParser::Deserialize(ParseContext& context, const Json::Value& json) {
    std::shared_ptr<PopoverAction> action = BaseActionElement::Deserialize<PopoverAction>(context, json);

    auto content = ParseUtil::ExtractJsonValue(json, AdaptiveCardSchemaKey::Content, true);
    std::shared_ptr<BaseElement> curElement;
    ParseJsonObject<BaseCardElement>(context, content, curElement);
    action->m_content = std::static_pointer_cast<BaseCardElement>(curElement);

    action->m_displayArrow = ParseUtil::GetBool(json, AdaptiveCardSchemaKey::DisplayArrow,DEFAULT_DISPLAY_ARROW,false);
    action->m_maxPopoverWidth = ParseUtil::GetString(json, AdaptiveCardSchemaKey::MaxPopoverWidth,DEFAULT_MAX_POPOVER_WIDTH, false);
    action->m_position = ParseUtil::GetEnumValue(json, AdaptiveCardSchemaKey::Position, DEFAULT_POSITION,LabelPositionFromString,false);
    return action;
}

std::shared_ptr<BaseActionElement> PopoverActionParser::DeserializeFromString(ParseContext& context, const std::string& jsonString) {
    return PopoverActionParser::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}
