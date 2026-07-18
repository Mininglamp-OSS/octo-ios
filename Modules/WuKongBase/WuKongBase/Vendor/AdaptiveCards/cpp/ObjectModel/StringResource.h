// Created by mejain on 10/08/25.
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include <utility>

#include "pch.h"
#include "BaseActionElement.h"

namespace AdaptiveCards {
    class StringResource {
    public:
        StringResource()= default;
        StringResource(std::string defaultValue, std::unordered_map<std::string, std::string> localizedValues) :
            m_defaultValue(std::move(defaultValue)), m_localizedValues(std::move(localizedValues)) {
        }

        bool ShouldSerialize() const;
        std::string Serialize() const;
        Json::Value SerializeToJsonValue() const;

        std::string GetDefaultValue() const;
        std::string GetDefaultValue(const std::string& locale, const std::string& fallback) const;
        std::unordered_map<std::string, std::string> GetLocalizedValue() const;

        static std::shared_ptr<StringResource> Deserialize(ParseContext& context, const Json::Value& json);
        static std::shared_ptr<StringResource> DeserializeFromString(ParseContext& context, const std::string& jsonString);

    private:
        std::string m_defaultValue;
        std::unordered_map<std::string, std::string> m_localizedValues;
    };
} // namespace AdaptiveCards
