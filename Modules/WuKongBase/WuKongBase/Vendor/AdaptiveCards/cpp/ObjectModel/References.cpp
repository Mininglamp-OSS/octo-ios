//
// Created by mejain on 10/08/25.
//
#include "pch.h"
#include "ParseUtil.h"
#include "ACReferences.h"

using namespace AdaptiveCards;

const ReferenceType References::GetType() const {
    return m_type;
}

const ReferenceIcon References::GetIcon() const {
    return m_icon;
}

void References::SetIcon(ReferenceIcon icon) {
    m_icon = icon;
}

const std::string References::GetAbstract() const {
    return m_abstract;
}

const std::string References::GetTitle() const {
    return m_title;
}

const std::string References::GetUrl() const {
    return m_url;
}

const std::vector<std::string> References::GetKeywords() const {
    return m_keywords;
}

std::shared_ptr<AdaptiveCards::AdaptiveCard> References::GetContent() const {
    return m_content;
}

// Indicates non-default values have been set. If false, serialization can be safely skipped.
bool References::ShouldSerialize() const {
    return true;
}

std::string References::Serialize() const {
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

Json::Value References::SerializeToJsonValue() const {
    Json::Value root;

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Abstract)] = m_abstract;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Title)] = m_title;
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Type)] = ReferenceTypeToString(m_type);
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Url)] = m_url;

    if (!m_keywords.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Keywords)] = Json::Value(Json::arrayValue);
        for (const auto& keyword : m_keywords) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Keywords)].append(keyword);
        }
    }

    if (m_content != nullptr) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Content)] = m_content->SerializeToJsonValue();
    }

    return root;
}

std::shared_ptr<References> References::DeserializeFromString(ParseContext& context, const std::string& jsonString) {
    return References::Deserialize(context, ParseUtil::GetJsonValueFromString(jsonString));
}

std::shared_ptr<References> References::Deserialize(ParseContext& context, const Json::Value& json) {
    std::shared_ptr<References> references = std::make_shared<References>();

    references->m_type = ParseUtil::GetEnumValue(json, AdaptiveCardSchemaKey::Type, ReferenceType::Document,ReferenceTypeFromString,true);
    references->m_icon = ParseUtil::GetEnumValue(json, AdaptiveCardSchemaKey::Icon, ReferenceIcon::Image,ReferenceIconFromString,false);
    references->m_title = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Title, true);
    references->m_abstract = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Abstract, true);
    references->m_url = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Url, false);
    auto keywords = ParseUtil::GetStringArray(json, AdaptiveCardSchemaKey::Keywords, true);
    // Truncate to at most 3 elements
    if (keywords.size() > 3) {
        keywords.resize(3);
    }
    references->m_keywords = std::move(keywords);

    if (references->m_type == ReferenceType::AdaptiveCard && json.isMember(AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Content))) {
        auto parseResult = AdaptiveCard::Deserialize(json.get(AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Content), Json::Value()), "", context);
        auto showCardWarnings = parseResult->GetWarnings();
        context.warnings.insert(context.warnings.end(), showCardWarnings.begin(), showCardWarnings.end());
        references->m_content = parseResult->GetAdaptiveCard();
    }

    return references;
}
