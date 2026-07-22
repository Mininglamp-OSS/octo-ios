// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseActionElement.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"
#include "IconInfo.h"

namespace AdaptiveCards
{
    class CompoundButton : public BaseCardElement
    {
        public:
            CompoundButton();
            CompoundButton(const CompoundButton&) = default;
            CompoundButton(CompoundButton&&) = default;
            CompoundButton& operator=(const CompoundButton&) = default;
            CompoundButton& operator=(CompoundButton&&) = default;
            ~CompoundButton() = default;

            Json::Value SerializeToJsonValue() const ;

            std::string getBadge() const;
            void setBadge(const std::string value);

            std::string getTitle() const;
            void setTitle(const std::string value);

            std::string getDescription() const;
            void setDescription(const std::string value);

            std::shared_ptr<BaseActionElement> GetSelectAction() const;
            void SetSelectAction(const std::shared_ptr<BaseActionElement> action);

            std::shared_ptr<AdaptiveCards::IconInfo> getIcon() const;
            void setIcon(const std::shared_ptr<AdaptiveCards::IconInfo> value);

        private:
            void PopulateKnownPropertiesSet();

            std::string m_badge;
            std::string m_title;
            std::string m_description;
            std::shared_ptr<BaseActionElement> m_selectAction;
            std::shared_ptr<AdaptiveCards::IconInfo> m_icon;
    };

    class CompoundButtonParser : public BaseCardElementParser
    {
        public:
            CompoundButtonParser() = default;
            CompoundButtonParser(const CompoundButtonParser&) = default;
            CompoundButtonParser(CompoundButtonParser&&) = default;
            CompoundButtonParser& operator=(const class CompoundButtonParser&) = default;
            CompoundButtonParser& operator=(CompoundButtonParser&&) = default;
            virtual ~CompoundButtonParser() = default;

            std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
            std::shared_ptr<BaseCardElement> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
            std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
} // namespace AdaptiveCards
