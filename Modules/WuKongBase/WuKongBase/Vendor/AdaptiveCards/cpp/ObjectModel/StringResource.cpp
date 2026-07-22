//
// Created by mejain on 10/08/25.
//
#include "StringResource.h"

using namespace AdaptiveCards;

bool StringResource::ShouldSerialize() const {
    return false;
}

std::string StringResource::Serialize() const {
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value StringResource::SerializeToJsonValue() const {
    Json::Value root;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::DefaultValue)] = m_defaultValue;

    if (!m_localizedValues.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::LocalizedValues)] = Json::Value(Json::objectValue);
        for (const auto& pair : m_localizedValues) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::LocalizedValues)][pair.first] = pair.second;
        }
    }
    return root;
}

std::string AdaptiveCards::StringResource::GetDefaultValue() const {
    return m_defaultValue;
}

std::string AdaptiveCards::StringResource::GetDefaultValue(const std::string &locale, const std::string& fallback) const {
    auto value = m_localizedValues.find(locale);
    if (value != m_localizedValues.end()) {
        return value->second;
    }
    if (!m_defaultValue.empty()) {
        return m_defaultValue;
    }
    return fallback;
}

std::unordered_map<std::string, std::string> StringResource::GetLocalizedValue() const {
    return m_localizedValues;
}

std::shared_ptr<StringResource> StringResource::Deserialize(ParseContext& context, const Json::Value& json) {
    std::shared_ptr<StringResource> stringResource = std::make_shared<StringResource>();
    stringResource->m_defaultValue = ParseUtil::GetString(json, AdaptiveCardSchemaKey::DefaultValue, false);
    // lowercase the keys to avoid case mismatch
    stringResource->m_localizedValues = ParseUtil::GetStringMap(json, AdaptiveCardSchemaKey::LocalizedValues, false, true);
    return stringResource;
}

std::shared_ptr<StringResource> StringResource::DeserializeFromString(ParseContext &context, const std::string &jsonString) {
    return StringResource::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}
