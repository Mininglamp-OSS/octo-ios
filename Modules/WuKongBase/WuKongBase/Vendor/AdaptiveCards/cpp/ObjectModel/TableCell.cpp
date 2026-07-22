// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "TableCell.h"
#include "FlowLayout.h"
#include "AreaGridLayout.h"

using namespace AdaptiveCards;

namespace AdaptiveCards
{
TableCell::TableCell() : Container(CardElementType::TableCell)
{
}

std::shared_ptr<TableCell> TableCell::DeserializeTableCell(ParseContext& context, const Json::Value& value)
{
    const auto& idProperty = ParseUtil::GetString(value, AdaptiveCardSchemaKey::Id);
    const InternalId internalId = InternalId::Next();
    
    context.PushElement(idProperty, internalId);
    
    auto cell = StyledCollectionElement::Deserialize<TableCell>(context, value);
    cell->SetRtl(ParseUtil::GetOptionalBool(value, AdaptiveCardSchemaKey::Rtl));
    
    if (const auto& layoutArray = ParseUtil::GetArray(value, AdaptiveCardSchemaKey::Layouts, false); !layoutArray.empty())
    {
        auto& layouts = cell->GetLayouts();
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
    
    context.PopElement();
    
    return cell;
}

std::shared_ptr<TableCell> TableCell::DeserializeTableCellFromString(ParseContext& context, const std::string& jsonString)
{
    return TableCell::DeserializeTableCell(context, ParseUtil::GetJsonValueFromString(jsonString));
}
} // namespace AdaptiveCards
