// Created by mejain on 10/08/25.
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include <utility>

#include "pch.h"
#include "BaseActionElement.h"
#include "StringResource.h"

namespace AdaptiveCards {

    class Resources {

    public:
        Resources(){}
        Resources(std::unordered_map<std::string, std::shared_ptr<StringResource>> strings) :
                m_strings(std::move(strings)) {
        }

        bool ShouldSerialize() const;
        std::string Serialize() const;
        Json::Value SerializeToJsonValue() const;

        const std::unordered_map<std::string, std::shared_ptr<StringResource>> GetStrings() const;

        static std::shared_ptr<Resources> Deserialize(ParseContext& context, const Json::Value& json);
        static std::shared_ptr<Resources> DeserializeFromString(ParseContext& context, const std::string& jsonString);

    private:
        std::unordered_map<std::string, std::shared_ptr<StringResource>> m_strings;
    };
} // namespace AdaptiveCards
