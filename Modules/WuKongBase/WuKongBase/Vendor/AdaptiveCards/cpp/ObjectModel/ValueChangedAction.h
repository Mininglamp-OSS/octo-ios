// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"

namespace AdaptiveCards
{
    class ValueChangedAction
    {
    public:
        ValueChangedAction() :
                m_targetInputIds(), m_valueChangedActionType(ValueChangedActionType::ResetInputs)
        {
        }
        ValueChangedAction(std::vector<std::string> targetInputIds) : m_targetInputIds(targetInputIds), m_valueChangedActionType(ValueChangedActionType::ResetInputs)
        {
        }
        ValueChangedAction(std::vector<std::string> targetInputIds, ValueChangedActionType type) : m_targetInputIds(targetInputIds), m_valueChangedActionType(type)
        {
        }

        std::vector<std::string>& GetTargetInputIds();
        void SetTargetInputIds(std::vector<std::string>);

        ValueChangedActionType GetValueChangedActionType() const;
        void SetValueChangedActionType(const ValueChangedActionType& value);

        bool ShouldSerialize() const;
        std::string Serialize() const;
        Json::Value SerializeToJsonValue() const;

        static std::shared_ptr<ValueChangedAction> Deserialize(const Json::Value& json);
        static std::shared_ptr<ValueChangedAction> DeserializeFromString(const std::string& jsonString);

    private:
        std::vector<std::string> m_targetInputIds;
        ValueChangedActionType m_valueChangedActionType = ValueChangedActionType::ResetInputs;
    };
} // namespace AdaptiveCards
