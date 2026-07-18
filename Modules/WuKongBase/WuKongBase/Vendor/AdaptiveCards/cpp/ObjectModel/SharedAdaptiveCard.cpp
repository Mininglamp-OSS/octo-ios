// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#include "pch.h"
#include "SharedAdaptiveCard.h"
#include "ParseUtil.h"
#include "Util.h"
#include "ShowCardAction.h"
#include "TextBlock.h"
#include "AdaptiveCardParseWarning.h"
#include "SemanticVersion.h"
#include "ParseContext.h"
#include "BackgroundImage.h"
#include "FlowLayout.h"
#include "AreaGridLayout.h"
#include "ACReferences.h"
#include "Resources.h"

using namespace AdaptiveCards;

AdaptiveCard::AdaptiveCard() :
    AdaptiveCard("", "", std::shared_ptr<BackgroundImage>(), ContainerStyle::None, "", "", VerticalContentAlignment::Top, HeightType::Auto, 0)
{
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::string const& backgroundImageUrl,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight) :
    AdaptiveCard(version, fallbackText, std::make_shared<BackgroundImage>(backgroundImageUrl), style, speak, language, verticalContentAlignment, height, minHeight)
{
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::string const& backgroundImageUrl,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight,
    std::vector<std::shared_ptr<BaseCardElement>>& body,
    std::vector<std::shared_ptr<BaseActionElement>>& actions) :
    AdaptiveCard(
        version, fallbackText, std::make_shared<BackgroundImage>(backgroundImageUrl), style, speak, language, verticalContentAlignment, height, minHeight, body, actions)
{
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::shared_ptr<BackgroundImage> backgroundImage,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight) :
    m_version(version),
    m_fallbackText(fallbackText), m_backgroundImage(backgroundImage), m_speak(speak), m_style(style),
    m_language(language), m_verticalContentAlignment(verticalContentAlignment), m_height(height),
    m_minHeight(minHeight), m_internalId{InternalId::Next()}, m_additionalProperties{}
{
    PopulateKnownPropertiesSet();
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::shared_ptr<BackgroundImage> backgroundImage,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight,
    std::vector<std::shared_ptr<BaseCardElement>>& body,
    std::vector<std::shared_ptr<BaseActionElement>>& actions) :
    AdaptiveCard(
        version,
        fallbackText,
        backgroundImage,
        std::shared_ptr<Refresh>(),
        std::shared_ptr<Authentication>(),
        style,
        speak,
        language,
        verticalContentAlignment,
        height,
        minHeight,
        body,
        actions)
{
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::shared_ptr<BackgroundImage> backgroundImage,
    std::shared_ptr<Refresh> refresh,
    std::shared_ptr<Authentication> authentication,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight,
    std::vector<std::shared_ptr<BaseCardElement>>& body,
    std::vector<std::shared_ptr<BaseActionElement>>& actions) :
    m_version(version),
    m_fallbackText(fallbackText), m_backgroundImage(backgroundImage), m_refresh(refresh),
    m_authentication(authentication), m_speak(speak), m_style(style), m_language(language),
    m_verticalContentAlignment(verticalContentAlignment), m_height(height),
    m_minHeight(minHeight), m_internalId{InternalId::Next()}, m_additionalProperties{}, m_body(body), m_actions(actions),
    m_requires{}, m_fallbackContent{}, m_fallbackType(FallbackType::None)
{
    PopulateKnownPropertiesSet();
}

AdaptiveCard::AdaptiveCard(
    std::string const& version,
    std::string const& fallbackText,
    std::shared_ptr<BackgroundImage> backgroundImage,
    std::shared_ptr<Refresh> refresh,
    std::shared_ptr<Authentication> authentication,
    ContainerStyle style,
    std::string const& speak,
    std::string const& language,
    VerticalContentAlignment verticalContentAlignment,
    HeightType height,
    unsigned int minHeight,
    std::vector<std::shared_ptr<BaseCardElement>>& body,
    std::vector<std::shared_ptr<BaseActionElement>>& actions,
    std::unordered_map<std::string, AdaptiveCards::SemanticVersion>& p_requires,
    std::shared_ptr<BaseElement>& fallbackContent,
    FallbackType& fallbackType) :
    m_version(version),
    m_fallbackText(fallbackText), m_backgroundImage(backgroundImage), m_refresh(refresh),
    m_authentication(authentication), m_speak(speak), m_style(style), m_language(language),
    m_verticalContentAlignment(verticalContentAlignment), m_height(height), m_minHeight(minHeight), m_internalId{InternalId::Next()}, m_additionalProperties{}, m_body(body), m_actions(actions), m_requires(p_requires), m_fallbackContent(fallbackContent), m_fallbackType(fallbackType)
{
    PopulateKnownPropertiesSet();
}

const std::unordered_map<std::string, AdaptiveCards::SemanticVersion> AdaptiveCard::GetFeaturesSupported()
{
    // Include all features using ParseUtil::ToLowercase
    return {{ParseUtil::ToLowercase("responsiveLayout"), AdaptiveCards::SemanticVersion("1.0")}};
}

#ifdef __ANDROID__
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromFile(const std::string& jsonFile, std::string rendererVersion) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromFile(const std::string& jsonFile, const std::string& rendererVersion)
#endif // __ANDROID__
{
    ParseContext context;
    return AdaptiveCard::DeserializeFromFile(jsonFile, rendererVersion, context);
}

#ifdef __ANDROID__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdynamic-exception-spec"
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromFile(
    const std::string& jsonFile, std::string rendererVersion, ParseContext& context) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromFile(const std::string& jsonFile, const std::string& rendererVersion, ParseContext& context)
#endif // __ANDROID__
{
    std::ifstream jsonFileStream(jsonFile);

    Json::Value root;
    jsonFileStream >> root;

    return AdaptiveCard::Deserialize(root, rendererVersion, context);
}

// Replace all occurrences of ${rs:key} with value from the map
std::string AdaptiveCard::ReplaceStringResources(
        const std::string& input,
        std::shared_ptr<AdaptiveCards::Resources> resources,
        const std::string& locale) {

    if (!resources)
    {
        return input;
    }
    auto strings = resources->GetStrings();
    // Add validation checks to skip replacement & return the same string
    if (!IsStringResourcePresent(input) || strings.empty()) {
        return input;
    }

    std::regex pattern(R"(\$\{rs:([^}]+)\})");  // Matches ${rs:key}
    std::string result;
    std::sregex_iterator it(input.begin(), input.end(), pattern);
    std::sregex_iterator end;

    size_t lastPos = 0;

    for (; it != end; ++it) {
        const std::smatch& match = *it;
        std::string fullMatch = match.str(); // e.g., ${rs:catImageURL}
        std::string key = match[1].str(); // e.g., catImageURL
        size_t matchPos = match.position();

        // Append text before match
        result += input.substr(lastPos, matchPos - lastPos);

        auto pair = strings.find(key);
        if (pair != strings.end()) {
            auto stringResource = pair->second;
            // lowercase the locale to avoid case mismatch
            result += stringResource->GetDefaultValue(ParseUtil::ToLowercase(locale), fullMatch);
        } else {
            result += fullMatch; // Leave it unchanged if not found
        }

        lastPos = matchPos + fullMatch.length();
    }
    // Append any remaining text after the last match
    result += input.substr(lastPos);
    return result;
}

bool AdaptiveCard::IsStringResourcePresent(const std::string& input) {
    // Regular expression to match pattern ${rs:key}
    std::regex pattern(R"(\$\{rs:[^}]+\})");
    return std::regex_search(input, pattern);
}

void AdaptiveCard::_ValidateLanguage(const std::string& language, std::vector<std::shared_ptr<AdaptiveCardParseWarning>>& warnings)
{
    try
    {
        if (language.empty() || language.length() == 2 || language.length() == 3)
        {
            auto locale = std::locale(language.c_str());
        }
        else
        {
            warnings.push_back(std::make_shared<AdaptiveCardParseWarning>(
                AdaptiveCards::WarningStatusCode::InvalidLanguage, "Invalid language identifier: " + language));
        }
    }
    catch (std::runtime_error)
    {
        warnings.push_back(std::make_shared<AdaptiveCardParseWarning>(
            AdaptiveCards::WarningStatusCode::InvalidLanguage, "Invalid language identifier: " + language));
    }
}

#ifdef __ANDROID__
std::shared_ptr<ParseResult> AdaptiveCard::Deserialize(
    const Json::Value& json, std::string rendererVersion, ParseContext& context) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<ParseResult> AdaptiveCard::Deserialize(const Json::Value& json, const std::string& rendererVersion, ParseContext& context)
#endif // __ANDROID__
{
    ParseUtil::ThrowIfNotJsonObject(json);

    const bool enforceVersion = !rendererVersion.empty();

    // Verify this is an adaptive card
    ParseUtil::ExpectTypeString(json, CardElementType::AdaptiveCard);

    std::string version = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Version, enforceVersion);
    std::string fallbackText = ParseUtil::GetString(json, AdaptiveCardSchemaKey::FallbackText);
    std::string language = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Language);
    std::string speak = ParseUtil::GetString(json, AdaptiveCardSchemaKey::Speak);
#ifndef __APPLE__
    // check if language is valid
    _ValidateLanguage(language, context.warnings);
#endif
    if (language.size())
    {
        context.SetLanguage(language);
    }
    else
    {
        language = context.GetLanguage();
    }

    // Perform version validation
    if (enforceVersion)
    {
        const SemanticVersion rendererMaxVersion(rendererVersion);
        const SemanticVersion cardVersion(version);

        if (rendererVersion < cardVersion)
        {
            if (fallbackText.empty())
            {
                fallbackText = "We're sorry, this card couldn't be displayed";
            }

            if (speak.empty())
            {
                speak = fallbackText;
            }

            context.warnings.push_back(std::make_shared<AdaptiveCardParseWarning>(
                AdaptiveCards::WarningStatusCode::UnsupportedSchemaVersion, "Schema version not supported"));
            return std::make_shared<ParseResult>(MakeFallbackTextCard(fallbackText, language, speak), context.warnings);
        }
    }

    auto backgroundImage =
        ParseUtil::DeserializeValue<BackgroundImage>(json, AdaptiveCardSchemaKey::BackgroundImage, BackgroundImage::Deserialize);
    std::vector<std::shared_ptr<Layout>> layouts;
    if (const auto& layoutArray = ParseUtil::GetArray(json, AdaptiveCardSchemaKey::Layouts, false); !layoutArray.empty())
    {
        for (const auto& layoutJson : layoutArray)
        {
            std::shared_ptr<Layout> layout = Layout::Deserialize(layoutJson);
            if(layout->GetLayoutContainerType() == LayoutContainerType::Flow)
            {
                layouts.push_back(FlowLayout::Deserialize(layoutJson));
            }
            else if (layout->GetLayoutContainerType() == LayoutContainerType::AreaGrid)
            {
                std::shared_ptr<AreaGridLayout> areaGridLayout = AreaGridLayout::Deserialize(layoutJson);
                if (areaGridLayout->GetAreas().size() == 0 && areaGridLayout->GetColumns().size() == 0)
                {
                    // this needs to be stack layout
                    std::shared_ptr<Layout> stackLayout = std::make_shared<Layout>();
                    stackLayout->SetLayoutContainerType(LayoutContainerType::Stack);
                    layouts.push_back(stackLayout);
                }
                else if (areaGridLayout->GetAreas().size() == 0)
                {
                    // this needs to be flow layout
                    std::shared_ptr<FlowLayout> flowLayout = std::make_shared<FlowLayout>();
                    flowLayout->SetLayoutContainerType(LayoutContainerType::Flow);
                    layouts.push_back(flowLayout);
                }
                else
                {
                   layouts.push_back(AreaGridLayout::Deserialize(layoutJson));
                }
            }
        }
    }
    auto refresh = ParseUtil::DeserializeValue<Refresh>(context, json, AdaptiveCardSchemaKey::Refresh, Refresh::Deserialize);
    auto authentication = ParseUtil::DeserializeValue<Authentication>(
        context, json, AdaptiveCardSchemaKey::Authentication, Authentication::Deserialize);

    ContainerStyle style =
        ParseUtil::GetEnumValue<ContainerStyle>(json, AdaptiveCardSchemaKey::Style, ContainerStyle::None, ContainerStyleFromString);
    context.SetParentalContainerStyle(style);

    VerticalContentAlignment verticalContentAlignment = ParseUtil::GetEnumValue<VerticalContentAlignment>(
        json, AdaptiveCardSchemaKey::VerticalContentAlignment, VerticalContentAlignment::Top, VerticalContentAlignmentFromString);
    HeightType height =
        ParseUtil::GetEnumValue<HeightType>(json, AdaptiveCardSchemaKey::Height, HeightType::Auto, HeightTypeFromString);

    unsigned int minHeight =
        ParseSizeForPixelSize(ParseUtil::GetString(json, AdaptiveCardSchemaKey::MinHeight), &context.warnings).value_or(0);

    // Parse required if present
    std::unordered_map<std::string, AdaptiveCards::SemanticVersion> requiresSet;
    ParseUtil::ParseRequires(context, json, requiresSet);
    // Parse actions if present
    auto actions = ParseUtil::GetActionCollection(context, json, AdaptiveCardSchemaKey::Actions, false);
    // Parse fallback if present
    std::shared_ptr<BaseElement> fallbackBaseElement;
    FallbackType fallbackType = FallbackType::None;
    ParseUtil::ParseFallback<BaseCardElement>(context, json, fallbackType, fallbackBaseElement, "rootFallbackId", InternalId::Current());

    // Parse optional resources
    auto resources = ParseUtil::DeserializeValue<Resources>(context, json, AdaptiveCardSchemaKey::Resources, Resources::Deserialize,false);
    auto references = ParseUtil::GetElementCollectionOfSingleType<References>(context, json, AdaptiveCardSchemaKey::References, References::Deserialize, false);

    if (MeetsRootRequirements(requiresSet))
    {
        // Parse body
        auto body = ParseUtil::GetElementCollection<BaseCardElement>(true, context, json, AdaptiveCardSchemaKey::Body, false);

        EnsureShowCardVersions(actions, version);

        auto result = std::make_shared<AdaptiveCard>(
            version, fallbackText, backgroundImage, refresh, authentication, style, speak, language, verticalContentAlignment, height, minHeight, body, actions, requiresSet, fallbackBaseElement, fallbackType);
        result->SetLanguage(language);
        result->SetRtl(ParseUtil::GetOptionalBool(json, AdaptiveCardSchemaKey::Rtl));
        result->m_resources = resources;
        result->m_references = std::move(references);

        // Parse optional selectAction
        result->SetSelectAction(ParseUtil::GetAction(context, json, AdaptiveCardSchemaKey::SelectAction, false));

        Json::Value additionalProperties;
        HandleUnknownProperties(json, result->GetKnownProperties(), additionalProperties);
        result->SetAdditionalProperties(additionalProperties);
        result->SetLayouts(layouts);

        return std::make_shared<ParseResult>(result, context.warnings);
    }
    else if (fallbackBaseElement == nullptr)
    {
        fallbackText = "We're sorry, this card couldn't be displayed";
        context.warnings.push_back(std::make_shared<AdaptiveCardParseWarning>(
            AdaptiveCards::WarningStatusCode::UnsupportedSchemaVersion, "Requirements not meet and root Fallback parsing failed"));
        return std::make_shared<ParseResult>(MakeFallbackTextCard(fallbackText, language, speak), context.warnings);
    }
    else
    {
        // Convert parsed fallback to collection of BaseCardElement
        std::shared_ptr<BaseCardElement> fallbackCardElement = std::static_pointer_cast<BaseCardElement>(fallbackBaseElement);
        std::vector<std::shared_ptr<BaseCardElement>> fallbackVector = {fallbackCardElement};

        auto result = std::make_shared<AdaptiveCard>(
            version, fallbackText, backgroundImage, refresh, authentication, style, speak, language, verticalContentAlignment, height, minHeight, fallbackVector, actions);
        result->SetLanguage(language);
        result->SetRtl(ParseUtil::GetOptionalBool(json, AdaptiveCardSchemaKey::Rtl));
        result->m_resources = resources;
        result->m_references = references;

        // Parse optional selectAction
        result->SetSelectAction(ParseUtil::GetAction(context, json, AdaptiveCardSchemaKey::SelectAction, false));
        result->SetLayouts(layouts);

        Json::Value additionalProperties;
        HandleUnknownProperties(json, result->GetKnownProperties(), additionalProperties);
        result->SetAdditionalProperties(additionalProperties);

        return std::make_shared<ParseResult>(result, context.warnings);
    }
}

bool AdaptiveCard::MeetsRootRequirements(std::unordered_map<std::string, AdaptiveCards::SemanticVersion> requiresSet)
{
    std::unordered_map<std::string, AdaptiveCards::SemanticVersion> featuresSupported = GetFeaturesSupported();

    for (const auto &featureToCheck : requiresSet)
    {
        auto foundFeature = featuresSupported.find(ParseUtil::ToLowercase(featureToCheck.first));

        if (foundFeature == featuresSupported.end())
        {
            return false;
        }
        else
        {
            AdaptiveCards::SemanticVersion localFeatureVersion = foundFeature->second;
            AdaptiveCards::SemanticVersion adaptiveCardVersion = featureToCheck.second;
            if (localFeatureVersion < adaptiveCardVersion)
            {
                return false;
            }
        }
    }
    return true;
}

#ifdef __ANDROID__
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromString(
    const std::string& jsonString, std::string rendererVersion) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromString(const std::string& jsonString, const std::string& rendererVersion)
#endif // __ANDROID__
{
    ParseContext context;
    return AdaptiveCard::DeserializeFromString(jsonString, rendererVersion, context);
}

#ifdef __ANDROID__
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromString(
    const std::string& jsonString, std::string rendererVersion, ParseContext& context) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<ParseResult> AdaptiveCard::DeserializeFromString(const std::string& jsonString, const std::string& rendererVersion, ParseContext& context)
#endif // __ANDROID__
{
    return AdaptiveCard::Deserialize(ParseUtil::GetJsonValueFromString(jsonString), rendererVersion, context);
}

Json::Value AdaptiveCard::SerializeToJsonValue() const
{
    Json::Value root = GetAdditionalProperties();
    root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Type)] = CardElementTypeToString(CardElementType::AdaptiveCard);

    if (!m_version.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Version)] = m_version;
    }
    else
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Version)] = "1.0";
    }

    if (!m_fallbackText.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::FallbackText)] = m_fallbackText;
    }
    if (m_backgroundImage != nullptr && m_backgroundImage->ShouldSerialize())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::BackgroundImage)] = m_backgroundImage->SerializeToJsonValue();
    }
    if (m_refresh != nullptr && m_refresh->ShouldSerialize())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Refresh)] = m_refresh->SerializeToJsonValue();
    }
    if (m_authentication != nullptr && m_authentication->ShouldSerialize())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Authentication)] = m_authentication->SerializeToJsonValue();
    }
    if (!m_speak.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Speak)] = m_speak;
    }
    if (!m_language.empty())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Language)] = m_language;
    }
    if (m_style != ContainerStyle::None)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style)] = ContainerStyleToString(m_style);
    }
    if (m_verticalContentAlignment != VerticalContentAlignment::Top)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::VerticalContentAlignment)] =
            VerticalContentAlignmentToString(m_verticalContentAlignment);
    }

    if (m_minHeight)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MinHeight)] = std::to_string(GetMinHeight()) + "px";
    }

    if (m_rtl.has_value())
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Rtl)] = m_rtl.value_or("");
    }

    const HeightType height = GetHeight();
    if (height != HeightType::Auto)
    {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Height)] = HeightTypeToString(GetHeight());
    }

    const std::string& bodyPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Body);
    root[bodyPropertyName] = Json::Value(Json::arrayValue);
    for (const auto& cardElement : GetBody())
    {
        root[bodyPropertyName].append(cardElement->SerializeToJsonValue());
    }

    const std::string& actionsPropertyName = AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Actions);
    root[actionsPropertyName] = Json::Value(Json::arrayValue);
    for (const auto& action : GetActions())
    {
        root[actionsPropertyName].append(action->SerializeToJsonValue());
    }

    if (!m_references.empty()) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::References)] = Json::Value(Json::arrayValue);
        for (const auto& reference : GetReferences()) {
            root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::References)].append(reference->SerializeToJsonValue());
        }
    }

    if (m_resources != nullptr) {
        root[AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Resources)] = m_resources->SerializeToJsonValue();
    }

    return root;
}

#ifdef __ANDROID__
std::shared_ptr<AdaptiveCard> AdaptiveCard::MakeFallbackTextCard(
    const std::string& fallbackText, const std::string& language, const std::string& speak) throw(AdaptiveCards::AdaptiveCardParseException)
#else
std::shared_ptr<AdaptiveCard> AdaptiveCard::MakeFallbackTextCard(
    const std::string& fallbackText, const std::string& language, const std::string& speak)
#endif // __ANDROID__
{
    std::shared_ptr<AdaptiveCard> fallbackCard = std::make_shared<AdaptiveCard>(
        "1.0", fallbackText, "", ContainerStyle::Default, speak, language, VerticalContentAlignment::Top, HeightType::Auto, 0);

    std::shared_ptr<TextBlock> textBlock = std::make_shared<TextBlock>();
    textBlock->SetText(fallbackText);
    textBlock->SetLanguage(language);

    fallbackCard->GetBody().push_back(textBlock);

    return fallbackCard;
}

std::string AdaptiveCard::Serialize() const
{
    return ParseUtil::JsonToString(SerializeToJsonValue());
}

std::string AdaptiveCard::GetVersion() const
{
    return m_version;
}

void AdaptiveCard::SetVersion(const std::string& value)
{
    m_version = value;
}

std::string AdaptiveCard::GetFallbackText() const
{
    return m_fallbackText;
}

void AdaptiveCard::SetFallbackText(const std::string& value)
{
    m_fallbackText = value;
}

std::shared_ptr<BackgroundImage> AdaptiveCard::GetBackgroundImage() const
{
    return m_backgroundImage;
}

void AdaptiveCard::SetBackgroundImage(const std::shared_ptr<BackgroundImage> value)
{
    m_backgroundImage = value;
}

std::shared_ptr<Refresh> AdaptiveCard::GetRefresh() const
{
    return m_refresh;
}

void AdaptiveCard::SetRefresh(const std::shared_ptr<Refresh> value)
{
    m_refresh = value;
}

std::shared_ptr<Authentication> AdaptiveCard::GetAuthentication() const
{
    return m_authentication;
}

void AdaptiveCard::SetAuthentication(const std::shared_ptr<Authentication> value)
{
    m_authentication = value;
}

std::vector<std::shared_ptr<Layout>>& AdaptiveCard::GetLayouts()
{
    return m_layouts;
}

const std::vector<std::shared_ptr<Layout>>& AdaptiveCard::GetLayouts() const
{
    return m_layouts;
}

void AdaptiveCard::SetLayouts(const std::vector<std::shared_ptr<Layout>>& value)
{
    m_layouts = value;
}

std::string AdaptiveCard::GetSpeak() const
{
    return m_speak;
}

void AdaptiveCard::SetSpeak(const std::string& value)
{
    m_speak = value;
}

ContainerStyle AdaptiveCard::GetStyle() const
{
    return m_style;
}

void AdaptiveCard::SetStyle(const ContainerStyle value)
{
    m_style = value;
}

const std::string& AdaptiveCard::GetLanguage() const
{
    return m_language;
}

void AdaptiveCard::SetLanguage(const std::string& value)
{
    m_language = value;
}

HeightType AdaptiveCard::GetHeight() const
{
    return m_height;
}

void AdaptiveCard::SetHeight(const HeightType value)
{
    m_height = value;
}

CardElementType AdaptiveCard::GetElementType() const
{
    return CardElementType::AdaptiveCard;
}

std::vector<std::shared_ptr<BaseCardElement>>& AdaptiveCard::GetBody()
{
    return m_body;
}

const std::vector<std::shared_ptr<BaseCardElement>>& AdaptiveCard::GetBody() const
{
    return m_body;
}

std::vector<std::shared_ptr<BaseActionElement>>& AdaptiveCard::GetActions()
{
    return m_actions;
}

const std::vector<std::shared_ptr<BaseActionElement>>& AdaptiveCard::GetActions() const
{
    return m_actions;
}

const std::vector<std::shared_ptr<References>>& AdaptiveCard::GetReferences() const {
    return m_references;
}

const std::optional<std::shared_ptr<References>> AdaptiveCard::GetReference(int index) const {
    if (index < 0 || index >= static_cast<int>(m_references.size())) {
        return std::nullopt;
    }
    return m_references[index];
}

std::shared_ptr<Resources> AdaptiveCard::GetResources() const {
    return m_resources;
}

std::shared_ptr<BaseActionElement> AdaptiveCard::GetSelectAction() const
{
    return m_selectAction;
}

void AdaptiveCard::SetSelectAction(const std::shared_ptr<BaseActionElement> action)
{
    m_selectAction = action;
}

VerticalContentAlignment AdaptiveCard::GetVerticalContentAlignment() const
{
    return m_verticalContentAlignment;
}

void AdaptiveCard::SetVerticalContentAlignment(const VerticalContentAlignment value)
{
    m_verticalContentAlignment = value;
}

unsigned int AdaptiveCard::GetMinHeight() const
{
    return m_minHeight;
}

void AdaptiveCard::SetMinHeight(const unsigned int value)
{
    m_minHeight = value;
}

// value is present if and only if "rtl" property is explicitly set
std::optional<bool> AdaptiveCard::GetRtl() const
{
    return m_rtl;
}

void AdaptiveCard::SetRtl(const std::optional<bool>& value)
{
    m_rtl = value;
}

void AdaptiveCard::PopulateKnownPropertiesSet()
{
    m_knownProperties.insert(
        {AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Type),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Version),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Body),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Actions),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::FallbackText),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::BackgroundImage),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Refresh),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Authentication),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::MinHeight),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Speak),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Language),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::VerticalContentAlignment),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Style),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::SelectAction),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Height),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Schema),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Requires),
         AdaptiveCardSchemaKeyToString(AdaptiveCardSchemaKey::Fallback)});
}

const std::unordered_set<std::string>& AdaptiveCard::GetKnownProperties() const
{
    return m_knownProperties;
}

const Json::Value& AdaptiveCard::GetAdditionalProperties() const
{
    return m_additionalProperties;
}

void AdaptiveCard::SetAdditionalProperties(Json::Value&& value)
{
    m_additionalProperties = std::move(value);
}
void AdaptiveCard::SetAdditionalProperties(const Json::Value& value)
{
    m_additionalProperties = value;
}

std::vector<RemoteResourceInformation> AdaptiveCard::GetResourceInformation()
{
    auto resourceVector = std::vector<RemoteResourceInformation>();

    auto backgroundImage = GetBackgroundImage();
    if (backgroundImage != nullptr)
    {
        RemoteResourceInformation backgroundImageInfo;
        backgroundImageInfo.url = backgroundImage->GetUrl();
        backgroundImageInfo.mimeType = "image";
        resourceVector.push_back(backgroundImageInfo);
    }

    for (auto item : m_body)
    {
        item->GetResourceInformation(resourceVector);
    }

    for (auto item : m_actions)
    {
        item->GetResourceInformation(resourceVector);
    }

    return resourceVector;
}

std::unordered_map<std::string, AdaptiveCards::SemanticVersion>& AdaptiveCard::GetRootRequires()
{
    return m_requires;
}

const std::unordered_map<std::string, AdaptiveCards::SemanticVersion>& AdaptiveCard::GetRootRequires() const
{
    return m_requires;
}

std::shared_ptr<BaseElement> AdaptiveCard::GetRootFallbackContent() const
{
    return m_fallbackContent;
}

FallbackType AdaptiveCard::GetRootFallbackType() const
{
    return m_fallbackType;
}
