//
//  ACRTableCellRenderer
//  ACRTableCellRenderer.mm
//
//  Copyright © 2021 Microsoft. All rights reserved.
//

#import "ACRTableCellRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRRendererPrivate.h"
#import "ACRTableCellView.h"
#import "TableCell.h"
#import "UtiliOS.h"
#import "ACRLayoutHelper.h"
#import "FlowLayout.h"
#import "AreaGridLayout.h"
#import "ACRFlowLayout.h"
#import "ARCGridViewLayout.h"

@implementation ACRTableCellRenderer

+ (ACRTableCellRenderer *)getInstance
{
    static ACRTableCellRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRTableCell;
}


- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    auto cellElement = std::dynamic_pointer_cast<TableCell>(elem);
    
    float widthOfElement = [rootView widthForElement:elem->GetInternalId().Hash()];
    std::shared_ptr<Layout> final_layout = [[[ACRLayoutHelper alloc] init] layoutToApplyFrom:cellElement->GetLayouts() andHostConfig:acoConfig];
    ACRFlowLayout *flowContainer;
    ARCGridViewLayout *gridLayout;
    if(final_layout->GetLayoutContainerType() == LayoutContainerType::Flow)
    {
        NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
        BOOL isFlowLayoutEnabled = [featureFlagResolver boolForFlag:@"isFlowLayoutEnabled"] ?: NO;
        if (isFlowLayoutEnabled)
        {
            std::shared_ptr<FlowLayout> flow_layout = std::dynamic_pointer_cast<FlowLayout>(final_layout);
            // layout using flow layout
            flowContainer = [[ACRFlowLayout alloc] initWithFlowLayout:flow_layout
                                                                style:(ACRContainerStyle)cellElement->GetStyle()
                                                          parentStyle:[viewGroup style]
                                                           hostConfig:acoConfig
                                                             maxWidth:widthOfElement
                                                            superview:viewGroup];
            
            [ACRRenderer renderInGridOrFlow:flowContainer
                                   rootView:rootView
                                     inputs:inputs
                              withCardElems:cellElement->GetItems()
                              andHostConfig:acoConfig];
        }
    }
    else if (final_layout->GetLayoutContainerType() == LayoutContainerType::AreaGrid)
    {
        NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
        BOOL isGridLayoutEnabled = [featureFlagResolver boolForFlag:@"isGridLayoutEnabled"] ?: NO;
        if (isGridLayoutEnabled) 
        {
            std::shared_ptr<AreaGridLayout> grid_layout = std::dynamic_pointer_cast<AreaGridLayout>(final_layout);
            gridLayout = [[ARCGridViewLayout alloc] initWithGridLayout:grid_layout
                                                                 style:(ACRContainerStyle)cellElement->GetStyle()
                                                           parentStyle:[viewGroup style]
                                                            hostConfig:acoConfig
                                                             superview:viewGroup];
            [ACRRenderer renderInGridOrFlow:gridLayout
                                   rootView:rootView
                                     inputs:inputs
                              withCardElems:cellElement->GetItems()
                              andHostConfig:acoConfig];
        }
    }
    ACRColumnView *cell = (ACRColumnView *)viewGroup;

    cell.rtl = rootView.context.rtl;

    renderBackgroundImage(cellElement->GetBackgroundImage(), cell, rootView);
    
    if(flowContainer != nil)
    {
        [cell addArrangedSubview:flowContainer];
    }
    else if(gridLayout)
    {
        [cell addArrangedSubview:gridLayout];
    }
    else
    {
        [ACRRenderer render:cell
                   rootView:rootView
                     inputs:inputs
              withCardElems:cellElement->GetItems()
              andHostConfig:acoConfig];
    }

    [cell setClipsToBounds:NO];

    std::shared_ptr<BaseActionElement> selectAction = cellElement->GetSelectAction();
    ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:selectAction];
    [cell configureForSelectAction:acoSelectAction rootView:rootView];

    [cell configureLayoutAndVisibility:rootView.context.verticalContentAlignment
                             minHeight:cellElement->GetMinHeight()
                            heightType:GetACRHeight(cellElement->GetHeight())
                                  type:ACRContainer];

    return cell;
}


@end
