// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "ParseUtil.h"
#include "RemoteResourceInformation.h"
#include "BaseElement.h"
#include "Enums.h"
#include "ThemedUrl.h"

void HandleUnknownProperties(const Json::Value& json, const std::unordered_set<std::string>& knownProperties, Json::Value& unknownProperties);

namespace AdaptiveCards
{
class BaseActionElement : public BaseElement
{
public:
    BaseActionElement(ActionType type);

    BaseActionElement() = default;
    BaseActionElement(const BaseActionElement&) = default;
    BaseActionElement(BaseActionElement&&) = default;
    BaseActionElement& operator=(const BaseActionElement&) = default;
    BaseActionElement& operator=(BaseActionElement&&) = default;
    ~BaseActionElement() = default;

    const std::string& GetTitle() const;

    virtual void SetTitle(std::string&& value);
    virtual void SetTitle(const std::string& value);

    const std::string& GetIconUrl(const ACTheme theme) const;
    const std::string& GetIconUrl() const;
    std::string GetSVGPath() const;
    std::string GetSVGPath(const std::string& iconUrl) const;

    void SetIconUrl(std::string&& value);
    void SetIconUrl(const std::string& value);

    const std::string& GetStyle() const;

    void SetStyle(std::string&& value);
    void SetStyle(const std::string& value);

    const std::string& GetTooltip() const;

    virtual void SetTooltip(std::string&& value);
    virtual void SetTooltip(const std::string& value);

    ActionType GetElementType() const;

    Mode GetMode() const;
    void SetMode(const Mode mode);

    bool GetIsEnabled() const;
    void SetIsEnabled(const bool isEnabled);

    bool GetIsRtl() const;
    void SetIsRtl(const bool isRtl);

    ActionRole GetRole() const;
    void SetRole(const ActionRole role);

    void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceUris) override;
    Json::Value SerializeToJsonValue() const override;

    bool GetIsSplitAction() const;
    const std::vector<std::shared_ptr<AdaptiveCards::BaseActionElement>>& GetMenuActions() const;

    template <typename T>
    static std::shared_ptr<T> Deserialize(ParseContext& context, const Json::Value& json);

    static std::shared_ptr<BaseActionElement> DeserializeBasePropertiesFromString(ParseContext& context, const std::string& jsonString);
    static std::shared_ptr<BaseActionElement> DeserializeBaseProperties(ParseContext& context, const Json::Value& json);

    static void ParseJsonObject(AdaptiveCards::ParseContext& context, const Json::Value& json, std::shared_ptr<BaseElement>& element);

    static const bool IsSplitActionSupported(const ActionType actionType) {
        return actionType == ActionType::Execute
               || actionType == ActionType::OpenUrl
               //|| actionType == ActionType::ResetInputs // Todo add ResetInputs once implemented
               || actionType == ActionType::ShowCard
               || actionType == ActionType::Submit
               || actionType == ActionType::ToggleVisibility;
    }

    /**
     * Determines if the given action type is a valid menu action.
     * @param actionType The type of action to be validated.
     * @return `true` if the action type is valid, `false` otherwise.
     * @note The `ActionType::ResetInputs` is planned for future implementation and is
     * currently commented out in the code.
     */
    static const bool IsValidMenuAction(const ActionType actionType) {
        return actionType == ActionType::Execute
               || actionType == ActionType::OpenUrl
               //|| actionType == ActionType::ResetInputs // Todo add ResetInputs once implemented
               || actionType == ActionType::Submit
               || actionType == ActionType::ToggleVisibility;
    }

    static const std::string GetSVGPathForIconUrl(const std::string& iconUrl) {
        std::regex regex{R"([,:]+)"}; // split on ':' and ','
        std::sregex_token_iterator it{iconUrl.begin(), iconUrl.end(), regex, -1};
        std::vector<std::string> config{it, {}};
        std::string iconStyle = IconStyleToString(IconStyle::Regular);
        std::string iconName = "";
        if(config.size() >= 2) {
            iconName = config[1];
            if(config.size() > 2) {
                iconStyle = config[config.size() - 1];
            }
        }
        std::string m_url = iconName + "/" + iconName + ".json";
        return m_url;
    }


private:
    void PopulateKnownPropertiesSet();
    static void DeserializeBaseProperties(ParseContext& context, const Json::Value& json, std::shared_ptr<BaseActionElement>& element);

    static constexpr const char* const defaultStyle = "default";

    std::string m_title;
    std::string m_iconUrl;
    std::string m_style;
    std::string m_tooltip;

    bool m_isEnabled;
    bool m_isRtl;

    ActionType m_type;
    Mode m_mode;
    ActionRole m_role;
    std::vector<std::shared_ptr<AdaptiveCards::BaseActionElement>> m_menuActions;
    std::vector<std::shared_ptr<AdaptiveCards::ThemedUrl>> m_themedIconUrls;
};

template <typename T>
std::shared_ptr<T> BaseActionElement::Deserialize(ParseContext& context, const Json::Value& json)
{
    std::shared_ptr<T> cardElement = std::make_shared<T>();
    std::shared_ptr<BaseActionElement> baseActionElement = std::static_pointer_cast<BaseActionElement>(cardElement);
    DeserializeBaseProperties(context, json, baseActionElement);

    // Walk all properties and put any unknown ones in the additional properties json
    HandleUnknownProperties(json, baseActionElement->m_knownProperties, baseActionElement->m_additionalProperties);

    return cardElement;
}
} // namespace AdaptiveCards
