//
//  ACRContainerRenderer
//  ACRContainerRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRContainerRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRColumnView.h"
#import "ACRRendererPrivate.h"
#import "ACRViewPrivate.h"
#import "Container.h"
#import "SharedAdaptiveCard.h"
#import "UtiliOS.h"
#import "FlowLayout.h"
#import "AreaGridLayout.h"
#import "ACRFlowLayout.h"
#import "ARCGridViewLayout.h"
#import "ACRLayoutHelper.h"

@implementation ACRContainerRenderer

+ (ACRContainerRenderer *)getInstance
{
    static ACRContainerRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRContainer;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<Container> containerElem = std::dynamic_pointer_cast<Container>(elem);
    
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

    configBleed(rootView, elem, container, acoConfig);

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

- (void)configUpdateForUIImageView:(ACRView *)rootView acoElem:(ACOBaseCardElement *)acoElem config:(ACOHostConfig *)acoConfig image:(UIImage *)image imageView:(UIImageView *)imageView
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<Container> containerElem = std::dynamic_pointer_cast<Container>(elem);
    auto backgroundImageProperties = containerElem->GetBackgroundImage();

    renderBackgroundImage(rootView, backgroundImageProperties.get(), imageView, image);
}

- (void)configureBorderForElement:(ACOBaseCardElement *)acoElem container:(ACRContentStackView *)container config:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<Container> containerElem = std::dynamic_pointer_cast<Container>(elem);
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
