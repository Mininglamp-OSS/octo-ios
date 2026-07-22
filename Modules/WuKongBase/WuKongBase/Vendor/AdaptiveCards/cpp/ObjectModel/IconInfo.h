
//
//  IconInfo.h
//  AdaptiveCards
//
//  Created by Abhishek Gupta on 16/05/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#pragma once

#include "ParseContext.h"

namespace AdaptiveCards {
    class IconInfo {
    public:
        IconInfo();
        IconInfo(const IconInfo&) = default;
        IconInfo(IconInfo&&) = default;
        IconInfo& operator=(const IconInfo&) = default;
        IconInfo& operator=(IconInfo&&) = default;
        ~IconInfo() = default;
        Json::Value SerializeToJsonValue() const;
        static std::shared_ptr<IconInfo> Deserialize(const Json::Value& json);
        std::string GetSVGPath() const;

        ForegroundColor getForgroundColor() const;
        void setForgroundColor(const ForegroundColor value);

        IconSize getIconSize() const;
        void setIconSize(const IconSize value);

        IconStyle getIconStyle() const;
        void setIconStyle(const IconStyle value);

        std::string GetName() const;
        void SetName(const std::string& value);


        ForegroundColor m_foregroundColor;
        IconStyle m_iconStyle;
        IconSize m_iconSize;
        std::string m_name;

    protected:
        std::unordered_set<std::string> m_knownProperties;

    private:
        void PopulateKnownPropertiesSet();
    };
}
