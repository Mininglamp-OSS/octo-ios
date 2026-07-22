//
// Created by mejain on 10/08/25.
//
#include "pch.h"
#include "ParseUtil.h"
#include "Resources.h"
#include "StringResource.h"

using namespace AdaptiveCards;

// Indicates non-default values have been set. If false, serialization can be safely skipped.
bool Resources::ShouldSerialize() const {
    return !m_strings.empty();
}

std::string Resources::Serialize() const {
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value Resources::SerializeToJsonValue() const {
    Json::Value root;
    if (!m_strings.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Strings)] = Json::Value(Json::objectValue);
        for (const auto& pair : m_strings) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Strings)][pair.first] = pair.second->SerializeToJsonValue();
        }
    }
    return root;
}

const std::unordered_map<std::string, std::shared_ptr<StringResource>> Resources::GetStrings() const {
    return m_strings;
}

std::shared_ptr<Resources> Resources::DeserializeFromString(ParseContext& context, const std::string& jsonString) {
    return Resources::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<Resources> Resources::Deserialize(ParseContext& context, const Json::Value& json) {
    std::shared_ptr<Resources> resources = std::make_shared<Resources>();
    if (json.isObject()) {
        auto strings = ParseUtil::GetGenericMap<StringResource>(context, json, AdaptiveCardSchemaKey::Strings, StringResource::Deserialize, false);
        resources->m_strings = std::move(strings);
    }
    return resources;
}
