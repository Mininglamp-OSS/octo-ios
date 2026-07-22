//
//  ACRCarouselPageView.mm
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "UtiliOS.h"
#import "ACRFlowLayout.h"
#import "ARCGridViewLayout.h"
#import "ACRLayoutHelper.h"
#import "CarouselPage.h"
#import "ACRRendererPrivate.h"
#import "ACRCarouselPageView.h"

@implementation ACRCarouselPageView

-(UIView *) render:(UIView<ACRIContentHoldingView> *)viewGroup
                         rootView:(ACRView *)rootView
                           inputs:(NSMutableArray *)inputs
                  baseCardElement:(ACOBaseCardElement *)acoElem
                       hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<CarouselPage> containerElem = std::dynamic_pointer_cast<CarouselPage>(elem);
    
    [rootView.context pushBaseCardElementContext:acoElem];
    
    //Layout
    float widthOfElement = [rootView widthForElement:elem->GetInternalId().Hash()];
    std::shared_ptr<Layout> final_layout = [[[ACRLayoutHelper alloc] init] layoutToApplyFrom:containerElem->GetLayouts() andHostConfig:acoConfig];
    ACRFlowLayout *flowContainer;
    ARCGridViewLayout *gridLayout;
    BOOL useStackLayout = NO;
    if(final_layout->GetLayoutContainerType() == LayoutContainerType::Flow)
    {
        NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
        BOOL isFlowLayoutEnabled = [featureFlagResolver boolForFlag:@"isFlowLayoutEnabled"] ?: NO;
        
        if(isFlowLayoutEnabled)
        {
            std::shared_ptr<FlowLayout> flow_layout = std::dynamic_pointer_cast<FlowLayout>(final_layout);
            // layout using flow layout
            flowContainer = [[ACRFlowLayout alloc] initWithFlowLayout:flow_layout
                                                                style:(ACRContainerStyle)containerElem->GetStyle()
                                                          parentStyle:[viewGroup style]
                                                           hostConfig:acoConfig
                                                             maxWidth:widthOfElement
                                                            superview:viewGroup];
            
            [ACRRenderer renderInGridOrFlow:flowContainer
                                   rootView:rootView
                                     inputs:inputs
                              withCardElems:containerElem->GetItems()
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
                                                                 style:(ACRContainerStyle)containerElem->GetStyle()
                                                           parentStyle:[viewGroup style]
                                                            hostConfig:acoConfig
                                                             superview:viewGroup];
            [ACRRenderer renderInGridOrFlow:gridLayout
                                   rootView:rootView
                                     inputs:inputs
                              withCardElems:containerElem->GetItems()
                              andHostConfig:acoConfig];
        }
    }
    else
    {
        useStackLayout = YES;
    }

    ACRColumnView *container = [[ACRColumnView alloc] initWithStyle:(ACRContainerStyle)containerElem->GetStyle()
                                                        parentStyle:[viewGroup style]
                                                         hostConfig:acoConfig
                                                          superview:viewGroup];
    container.rtl = rootView.context.rtl;

    if(flowContainer != nil)
    {
        [container addArrangedSubview:flowContainer];
    }
    else if (gridLayout != nil)
    {
        [container addArrangedSubview:gridLayout];
    }
    
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:container withAreaName:areaName];
    
    [self configureBorderForElement:acoElem container:container config:acoConfig];


    renderBackgroundImage(containerElem->GetBackgroundImage(), container, rootView);

    container.frame = viewGroup.frame;
    
    if (useStackLayout)
    {
        [ACRRenderer render:container
                   rootView:rootView
                     inputs:inputs
              withCardElems:containerElem->GetItems()
              andHostConfig:acoConfig];
    }

    [container setClipsToBounds:NO];

    std::shared_ptr<BaseActionElement> selectAction = containerElem->GetSelectAction();
    ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:selectAction];
    [container configureForSelectAction:acoSelectAction rootView:rootView];

    [container configureLayoutAndVisibility:GetACRVerticalContentAlignment(containerElem->GetVerticalContentAlignment().value_or(VerticalContentAlignment::Top))
                                  minHeight:containerElem->GetMinHeight()
                                 heightType:GetACRHeight(containerElem->GetHeight())
                                       type:ACRContainer];

    [rootView.context popBaseCardElementContext:acoElem];

    container.accessibilityElements = [container getArrangedSubviews];

    return container;
}

- (void)configureBorderForElement:(ACOBaseCardElement *)acoElem container:(ACRContentStackView *)container config:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<CarouselPage> containerElem = std::dynamic_pointer_cast<CarouselPage>(elem);
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    bool shouldShowBorder = containerElem->GetShowBorder();
    if(shouldShowBorder)
    {
        ACRContainerStyle style = (ACRContainerStyle)containerElem->GetStyle();
        container.layer.borderWidth = config->GetBorderWidth(containerElem->GetElementType());
        auto borderColor = config->GetBorderColor([ACOHostConfig getSharedContainerStyle:style]);
        UIColor *color = [ACOHostConfig convertHexColorCodeToUIColor:borderColor];
        // we will add padding for any column element which has shouldShowBorder.
        [container applyPadding:config->GetSpacing().paddingSpacing priority:1000];
        [[container layer] setBorderColor:[color CGColor]];
    }
    
    bool roundedCorner = containerElem->GetRoundedCorners();
    if (roundedCorner)
    {
        container.layer.cornerRadius = config->GetCornerRadius(containerElem->GetElementType());
    }
}

@end

