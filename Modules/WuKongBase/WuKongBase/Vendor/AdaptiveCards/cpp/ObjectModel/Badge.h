// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"

namespace AdaptiveCards
{
class BadgeParser;

class Badge : public BaseCardElement
{
    friend BadgeParser;

public:
    Badge();
    Badge(const Badge&) = default;
    Badge(Badge&&) = default;
    Badge& operator=(const Badge&) = default;
    Badge& operator=(Badge&&) = default;
    ~Badge() = default;

    Json::Value SerializeToJsonValue() const override;

    std::optional<HorizontalAlignment> GetHorizontalAlignment() const;
    void SetHorizontalAlignment(const std::optional<HorizontalAlignment> value);

    std::string GetText() const;
    void SetText(const std::string& value);

    std::string GetBadgeIcon() const;
    void SetBadgeIcon(const std::string& value);

    std::string GetTooltip() const;
    void SetTooltip(const std::string& value);

    BadgeStyle GetBadgeStyle() const;
    void SetBadgeStyle(BadgeStyle value);

    Shape GetShape() const;
    void SetShape(Shape value);

    BadgeSize GetBadgeSize() const;
    void SetBadgeSize(BadgeSize value);

    BadgeAppearance GetBadgeAppearance() const;
    void SetBadgeAppearance(BadgeAppearance value);

    IconPosition GetIconPosition() const;
    void SetIconPosition(IconPosition value);

private:
    void PopulateKnownPropertiesSet();
    std::string  m_text;
    std::string m_icon;
    std::string m_tooltip;
    BadgeStyle m_badgeStyle;
    Shape m_shape;
    BadgeSize m_badgeSize;
    BadgeAppearance m_badgeAppearance;
    IconPosition m_iconPosition;
    std::optional<HorizontalAlignment> m_hAlignment;
};

    class BadgeParser : public BaseCardElementParser
    {
    public:
        BadgeParser() = default;
        BadgeParser(const BadgeParser&) = default;
        BadgeParser(BadgeParser&&) = default;
        BadgeParser& operator=(const BadgeParser&) = default;
        BadgeParser& operator=(BadgeParser&&) = default;
        virtual ~BadgeParser() = default;

        std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
        std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
} // namespace AdaptiveCards
