// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "ValueChangedAction.h"
#include "ParseContext.h"
#include "ParseUtil.h"

using namespace AdaptiveCards;

std::vector<std::string>& ValueChangedAction::GetTargetInputIds()
{
    return m_targetInputIds;
}

void ValueChangedAction::SetTargetInputIds(std::vector<std::string> targetInputIds)
{
    m_targetInputIds = targetInputIds;

}

ValueChangedActionType ValueChangedAction::GetValueChangedActionType() const
{
    return m_valueChangedActionType;
}

void ValueChangedAction::SetValueChangedActionType(const ValueChangedActionType& value)
{
    m_valueChangedActionType = value;
}


// Indicates non-default values have been set. If false, serialization can be safely skipped.
bool ValueChangedAction::ShouldSerialize() const
{
    return !m_targetInputIds.empty();
}

std::string ValueChangedAction::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value ValueChangedAction::SerializeToJsonValue() const
{
    Json::Value root;


    if (!m_targetInputIds.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetInputIds)] = Json::Value(
                Json::arrayValue);
        for (std::string targetInputId: m_targetInputIds) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::TargetInputIds)].append(targetInputId);
        }
    }
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::ValueChangedActionType)] = ValueChangedActionTypeToString(m_valueChangedActionType);

    return root;
}

std::shared_ptr<ValueChangedAction> ValueChangedAction::Deserialize(const Json::Value& json)
{
    if (json.empty())
    {
        return nullptr;
    }

    std::shared_ptr<ValueChangedAction> valueChangedAction = std::make_shared<ValueChangedAction>();

    valueChangedAction->SetTargetInputIds(ParseUtil::GetStringArray(json, AdaptiveCardSchemaKey::TargetInputIds, true));

    valueChangedAction->SetValueChangedActionType(ParseUtil::GetEnumValue<ValueChangedActionType>(
            json, AdaptiveCardSchemaKey::ValueChangedActionType, ValueChangedActionType::ResetInputs, ValueChangedActionTypeFromString));

    return valueChangedAction;
}

std::shared_ptr<ValueChangedAction> ValueChangedAction::DeserializeFromString(const std::string& jsonString)
{
    return ValueChangedAction::Deserialize(ParseUtil::GetJsonValueFromString(jsonString));
}
