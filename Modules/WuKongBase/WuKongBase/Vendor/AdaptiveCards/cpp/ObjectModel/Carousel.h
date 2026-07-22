//
//  Carousel.h
//  AdaptiveCards
//
//  Created by Abhishek Gupta on 30/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#pragma once

#include "pch.h"
#include "BaseActionElement.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"
#include "CarouselPage.h"
#include "StyledCollectionElement.h"

namespace AdaptiveCards
{
    class Carousel : public StyledCollectionElement
    {
        public:
            Carousel();
            Carousel(CardElementType derivedType);
            Carousel(const Carousel&) = default;
            Carousel(Carousel&&) = default;
            Carousel& operator=(const Carousel&) = default;
            Carousel& operator=(Carousel&&) = default;
            ~Carousel() = default;

            Json::Value SerializeToJsonValue() const override;
            void DeserializeChildren(ParseContext& context, const Json::Value& value) override;

            PageAnimation getPageAnimation();
            void setPageAnimation(const PageAnimation value);

            std::vector<std::shared_ptr<AdaptiveCards::CarouselPage>>& GetPages();
            const std::vector<std::shared_ptr<AdaptiveCards::CarouselPage>>& GetPages() const;

            void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo) override;
        private:
            void PopulateKnownPropertiesSet();

            PageAnimation m_pageAnimation;
            std::vector<std::shared_ptr<AdaptiveCards::CarouselPage>> m_pages;
    };

    class CarouselParser : public BaseCardElementParser
    {
        public:
            CarouselParser() = default;
            CarouselParser(const CarouselParser&) = default;
            CarouselParser(CarouselParser&&) = default;
            CarouselParser& operator=(const class CarouselParser&) = default;
            CarouselParser& operator=(CarouselParser&&) = default;
            virtual ~CarouselParser() = default;

            std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
            std::shared_ptr<BaseCardElement> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
            std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
    };
} // namespace AdaptiveCards
