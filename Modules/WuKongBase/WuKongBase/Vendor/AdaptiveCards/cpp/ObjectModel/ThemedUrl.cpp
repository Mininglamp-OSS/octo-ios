//
//  ThemedUrl.cpp
//  AdaptiveCards
//
//  Created by Meeth Jain.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#include "pch.h"
#include "ParseUtil.h"
#include "ParseContext.h"
#include "Util.h"
#include "ThemedUrl.h"

using namespace AdaptiveCards;

ThemedUrl::ThemedUrl() : m_theme(ACTheme::Light) {
    PopulateKnownPropertiesSet();
}

Json::Value ThemedUrl::SerializeToJsonValue() const
{
    Json::Value root = Json::Value();

    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Theme)] = ACThemeToString(m_theme);
    if (!m_url.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Url)] = m_url;
    }

    return root;
}

const ACTheme ThemedUrl::GetTheme() const {
    return m_theme;
}

const std::string& ThemedUrl::GetUrl() const {
    return m_url;
}

std::shared_ptr<ThemedUrl> ThemedUrl::Deserialize(ParseContext&, const Json::Value& json) {
    if (json.empty() || !json.isObject()) {
        return nullptr;
    }

    std::shared_ptr<ThemedUrl> themedUrlObject = std::make_shared<ThemedUrl>();
    themedUrlObject->m_url = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Url, true);
    themedUrlObject->m_theme = ParseUtil::GetEnumValue<ACTheme>(json, AdaptiveCardSchemaKey::Theme, ACTheme::Light, ACThemeFromString);
    return themedUrlObject;
}

void ThemedUrl::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert({AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Theme),
                              AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Url)});
}
