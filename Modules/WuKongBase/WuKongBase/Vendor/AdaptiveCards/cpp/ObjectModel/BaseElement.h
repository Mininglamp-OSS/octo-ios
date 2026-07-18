// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "json/json.h"
#include "InternalId.h"
#include "ParseContext.h"
#include "ParseUtil.h"
#include "SemanticVersion.h"
#include "RemoteResourceInformation.h"
#include "FeatureRegistration.h"

namespace AdaptiveCards
{
#ifdef _MSC_VER
class ParseContext;
#endif
class FeatureRegistration;

class BaseElement
{
public:
    BaseElement() :
        m_typeString{}, m_additionalProperties{}, m_requires{},
        m_fallbackContent(nullptr), m_id{}, m_internalId{InternalId::Current()}, m_fallbackType(FallbackType::None),
        m_canFallbackToAncestor(false)
    {
        PopulateKnownPropertiesSet();
    }

    BaseElement(const BaseElement&) = default;
    BaseElement(BaseElement&&) = default;
    BaseElement& operator=(const BaseElement&) = default;
    BaseElement& operator=(BaseElement&&) = default;
    virtual ~BaseElement() = default;

    // Element type and identity
    const std::string& GetElementTypeString() const;
    void SetElementTypeString(std::string&& value);
    void SetElementTypeString(const std::string& value);

    const std::string& GetId() const;
    virtual void SetId(std::string&& value);
    virtual void SetId(const std::string& value);

    InternalId GetInternalId() const
    {
        return m_internalId;
    }

    template <typename T>
    void DeserializeBase(AdaptiveCards::ParseContext& context, const Json::Value& json);

    virtual std::string Serialize() const;
    virtual Json::Value SerializeToJsonValue() const;
    const Json::Value& GetAdditionalProperties() const;
    void SetAdditionalProperties(Json::Value&& additionalProperties);
    void SetAdditionalProperties(const Json::Value& additionalProperties);

    // Fallback and Requires support
    FallbackType GetFallbackType() const
    {
        return m_fallbackType;
    }
    const std::shared_ptr<BaseElement>& GetFallbackContent() const
    {
        return m_fallbackContent;
    }
    bool CanFallbackToAncestor() const
    {
        return m_canFallbackToAncestor;
    }
    void SetFallbackType(FallbackType type)
    {
        m_fallbackType = type;
    }
    void SetFallbackContent(std::shared_ptr<BaseElement> element)
    {
        m_fallbackContent = std::move(element);
    }

    bool MeetsRequirements(const AdaptiveCards::FeatureRegistration& hostProvides) const;

    std::unordered_map<std::string, AdaptiveCards::SemanticVersion>& GetRequirements();
    const std::unordered_map<std::string, AdaptiveCards::SemanticVersion>& GetRequirements() const;

    // Misc.
    virtual void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceUris);

protected:
    void SetTypeString(std::string&& type)
    {
        m_typeString = std::move(type);
    }
    void SetTypeString(const std::string& type)
    {
        m_typeString = type;
    }
    void SetCanFallbackToAncestor(bool value)
    {
        m_canFallbackToAncestor = value;
    }

    std::string m_typeString;
    std::unordered_set<std::string> m_knownProperties;
    Json::Value m_additionalProperties;

private:
    void PopulateKnownPropertiesSet();

    std::unordered_map<std::string, AdaptiveCards::SemanticVersion> m_requires;
    std::shared_ptr<BaseElement> m_fallbackContent;
    std::string m_id;
    InternalId m_internalId;
    FallbackType m_fallbackType;
    bool m_canFallbackToAncestor;
};

template <typename T>
void BaseElement::DeserializeBase(ParseContext& context, const Json::Value& json)
{
    ParseUtil::ThrowIfNotJsonObject(json);

    // Order matters here -- we need to set the id property *prior* to parsing fallback so that we can detect id
    // collisions.
    SetId(ParseUtil::GetString(json, AdaptiveCardSchemaKey::Id));
    ParseUtil::ParseFallback<T>(context, json, m_fallbackType, m_fallbackContent, GetId(), GetInternalId());
    ParseUtil::ParseRequires(context, json, m_requires);
}
} // namespace AdaptiveCards
