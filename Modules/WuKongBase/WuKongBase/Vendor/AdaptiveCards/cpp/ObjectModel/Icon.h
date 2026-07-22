// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseActionElement.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards
{
class Icon : public BaseCardElement
{
public:
    Icon();
    Icon(const Icon&) = default;
    Icon(Icon&&) = default;
    Icon& operator=(const Icon&) = default;
    Icon& operator=(Icon&&) = default;
    ~Icon() = default;

    Json::Value SerializeToJsonValue() const override;

    ForegroundColor getForgroundColor() const;
    void setForgroundColor(const ForegroundColor value);

    IconSize getIconSize() const;
    void setIconSize(const IconSize value);

    IconStyle getIconStyle() const;
    void setIconStyle(const IconStyle value);

    std::string GetName() const;
    void SetName(const std::string& value);

    std::shared_ptr<BaseActionElement> GetSelectAction() const;
    void SetSelectAction(const std::shared_ptr<BaseActionElement> action);

    std::string GetSVGPath() const;

    void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo) override;

private:
    void PopulateKnownPropertiesSet();


    ForegroundColor m_foregroundColor;
    IconStyle m_iconStyle;
    IconSize m_iconSize;
    std::string m_name;
    std::shared_ptr<BaseActionElement> m_selectAction;
};

class IconParser : public BaseCardElementParser
{
public:
    IconParser() = default;
    IconParser(const IconParser&) = default;
    IconParser(IconParser&&) = default;
    IconParser& operator=(const IconParser&) = default;
    IconParser& operator=(IconParser&&) = default;
    virtual ~IconParser() = default;

    std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
    std::shared_ptr<BaseCardElement> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
    std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
};
} // namespace AdaptiveCards
