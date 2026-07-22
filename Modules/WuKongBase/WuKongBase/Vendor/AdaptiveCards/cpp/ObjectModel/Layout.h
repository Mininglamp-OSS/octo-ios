// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
#pragma once

#include "pch.h"
#include "ParseContext.h"
#include "BaseElement.h"

namespace AdaptiveCards
{
class Layout
{
public:
    Layout() :
        m_layoutContainerType(LayoutContainerType::None), m_targetWidth(TargetWidthType::Default)
    {
    }
    
    Layout(const Layout&) = default;
    Layout(Layout&&) = default;
    Layout& operator=(const Layout&) = default;
    Layout& operator=(Layout&&) = default;
    virtual ~Layout() = default;
    
    LayoutContainerType GetLayoutContainerType() const;
    void SetLayoutContainerType(const LayoutContainerType& value);
    
    TargetWidthType GetTargetWidth() const;
    void SetTargetWidth(TargetWidthType value);

    bool ShouldSerialize() const;
    std::string Serialize() const;
    Json::Value SerializeToJsonValue() const;
    
    bool MeetsTargetWidthRequirement(HostWidth hostWidth) const;

    static std::shared_ptr<Layout> Deserialize(const Json::Value& json);
    static std::shared_ptr<Layout> DeserializeFromString(const std::string& jsonString);

private:
    LayoutContainerType m_layoutContainerType = LayoutContainerType::None;
    TargetWidthType m_targetWidth;
};
} // namespace AdaptiveCards
