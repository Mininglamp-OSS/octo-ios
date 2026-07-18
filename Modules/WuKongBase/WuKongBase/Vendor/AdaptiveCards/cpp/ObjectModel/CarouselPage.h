//
//  CarouselPage.h
//  AdaptiveCards
//
//  Created by Abhishek Gupta on 30/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#pragma once

#include "BaseActionElement.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"
#include "StyledCollectionElement.h"
#include "Layout.h"
#include "pch.h"
namespace AdaptiveCards
{
    class CarouselPage : public StyledCollectionElement
    {
        public:
            CarouselPage();
            CarouselPage(const CarouselPage&) = default;
            CarouselPage(CarouselPage&&) = default;
            CarouselPage& operator=(const CarouselPage&) = default;
            CarouselPage& operator=(CarouselPage&&) = default;
            ~CarouselPage() = default;

            Json::Value SerializeToJsonValue() const override;
            void PopulateKnownPropertiesSet();
            static std::shared_ptr<CarouselPage> Deserialize(ParseContext& context, const Json::Value& root) ;
            static std::shared_ptr<CarouselPage> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
            void DeserializeChildren(ParseContext& context, const Json::Value& value) override;
            std::vector<std::shared_ptr<AdaptiveCards::Layout>>& GetLayouts();
            void SetLayouts(const std::vector<std::shared_ptr<AdaptiveCards::Layout>>& value);
            std::vector<std::shared_ptr<BaseCardElement>>& GetItems();
            const std::vector<std::shared_ptr<BaseCardElement>>& GetItems() const;
            std::optional<bool> GetRtl() const;
            void SetRtl(const std::optional<bool>& value);

            void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo) override;

        private:
            std::vector<std::shared_ptr<AdaptiveCards::BaseCardElement>> m_items;
            std::vector<std::shared_ptr<Layout>> m_layouts;
            std::optional<bool> m_rtl;
    };

    class CarouselPageParser : public BaseCardElementParser
    {
        public:
            CarouselPageParser() = default;
            CarouselPageParser(const CarouselPageParser&) = default;
            CarouselPageParser(CarouselPageParser&&) = default;
            CarouselPageParser& operator=(const class CarouselPageParser&) = default;
            CarouselPageParser& operator=(CarouselPageParser&&) = default;
            virtual ~CarouselPageParser() = default;

            std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
            std::shared_ptr<BaseCardElement> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
            std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
}
