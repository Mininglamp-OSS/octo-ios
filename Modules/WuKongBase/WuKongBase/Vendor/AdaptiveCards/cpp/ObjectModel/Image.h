// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "BaseActionElement.h"
#include "BaseCardElement.h"
#include "ElementParserRegistration.h"
#include "Resources.h"

namespace AdaptiveCards
{

static ImageFitMode DEFAULT_IMAGE_FIT_MODE = ImageFitMode::Fill;
static HorizontalContentAlignment DEFAULT_HORIZONTAL_CONTENT_ALIGNMENT = HorizontalContentAlignment::Left;
static VerticalContentAlignment DEFAULT_VERTICAL_CONTENT_ALIGNMENT = VerticalContentAlignment::Top;

class Image : public BaseCardElement
{

    friend class ImageParser;

public:
    Image();
    Image(const Image&) = default;
    Image(Image&&) = default;
    Image& operator=(const Image&) = default;
    Image& operator=(Image&&) = default;
    ~Image() = default;

    Image(std::string const& url) : BaseCardElement(CardElementType::Image),
        m_url(url),
        m_imageStyle(ImageStyle::Default),
        m_imageSize(ImageSize::None),
        m_pixelWidth(0),
        m_pixelHeight(0),
        m_hAlignment(std::nullopt),
        m_imageFitMode(DEFAULT_IMAGE_FIT_MODE),
        m_horizontalContentAlignment(DEFAULT_HORIZONTAL_CONTENT_ALIGNMENT),
        m_verticalContentAlignment(DEFAULT_VERTICAL_CONTENT_ALIGNMENT) {
        PopulateKnownPropertiesSet();
    }

    Json::Value SerializeToJsonValue() const override;

    const std::string& GetUrl(
            const ACTheme theme,
            std::shared_ptr<AdaptiveCards::Resources> resources,
            const std::string& locale) const;

    std::string GetUrl() const;
    void SetUrl(const std::string& value);

    std::string GetBackgroundColor() const;
    void SetBackgroundColor(const std::string& value);

    ImageStyle GetImageStyle() const;
    void SetImageStyle(const ImageStyle value);

    ImageSize GetImageSize() const;
    void SetImageSize(const ImageSize value);

    const ImageFitMode GetImageFitMode() const;
    const HorizontalContentAlignment GetHorizontalContentAlignment() const;
    const VerticalContentAlignment GetVerticalContentAlignment() const;

    std::string GetAltText() const;
    void SetAltText(const std::string& value);

    std::optional<HorizontalAlignment> GetHorizontalAlignment() const;
    void SetHorizontalAlignment(const std::optional<HorizontalAlignment> value);

    std::shared_ptr<BaseActionElement> GetSelectAction() const;
    void SetSelectAction(const std::shared_ptr<BaseActionElement> action);

    unsigned int GetPixelWidth() const;
    void SetPixelWidth(unsigned int value);

    unsigned int GetPixelHeight() const;
    void SetPixelHeight(unsigned int value);

    void GetResourceInformation(std::vector<RemoteResourceInformation>& resourceInfo) override;

private:
    void PopulateKnownPropertiesSet();

    std::string m_url;
    std::string m_backgroundColor;
    ImageStyle m_imageStyle;
    ImageSize m_imageSize;
    ImageFitMode m_imageFitMode;
    HorizontalContentAlignment m_horizontalContentAlignment;
    VerticalContentAlignment m_verticalContentAlignment;
    unsigned int m_pixelWidth;
    unsigned int m_pixelHeight;
    std::string m_altText;
    std::optional<HorizontalAlignment> m_hAlignment;
    std::shared_ptr<BaseActionElement> m_selectAction;
    std::vector<std::shared_ptr<AdaptiveCards::ThemedUrl>> m_themedUrls;
};

class ImageParser : public BaseCardElementParser
{
public:
    ImageParser() = default;
    ImageParser(const ImageParser&) = default;
    ImageParser(ImageParser&&) = default;
    ImageParser& operator=(const ImageParser&) = default;
    ImageParser& operator=(ImageParser&&) = default;
    virtual ~ImageParser() = default;

    std::shared_ptr<BaseCardElement> Deserialize(ParseContext& context, const Json::Value& root) override;
    std::shared_ptr<BaseCardElement> DeserializeWithoutCheckingType(ParseContext& context, const Json::Value& root);
    std::shared_ptr<BaseCardElement> DeserializeFromString(ParseContext& context, const std::string& jsonString) override;
};
} // namespace AdaptiveCards
