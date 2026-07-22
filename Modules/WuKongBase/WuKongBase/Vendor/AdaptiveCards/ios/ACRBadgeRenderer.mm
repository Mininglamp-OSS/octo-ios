//
//  ACRBadgeRenderer.m
//  AdaptiveCards
//
//  Created by reenulnu on 08/10/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElementPrivate.h"
#import "ACOBundle.h"
#import "ACOHostConfigPrivate.h"
#import "ACRInputLabelViewPrivate.h"
#import "ACRBadgeRenderer.h"
#import "UtiliOS.h"
#import "Badge.h"
#import "Icon.h"
#import "ACRSVGImageView.h"
#import "ACRSVGIconHoldingView.h"
#include "IconInfo.h"
#import "ACRBadgeView.h"

@implementation ACRBadgeRenderer

+ (ACRBadgeRenderer *)getInstance
{
    static ACRBadgeRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRBadge;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
          rootView:(ACRView *)rootView
            inputs:(NSMutableArray *)inputs
   baseCardElement:(ACOBaseCardElement *)acoElem
        hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<Badge> badge = std::dynamic_pointer_cast<Badge>(elem);
    NSString *iconName = [NSString stringWithCString:badge->GetBadgeIcon().c_str() encoding:NSUTF8StringEncoding];
    NSArray *components = [iconName componentsSeparatedByString:@","];
    BOOL isFilled = YES;
    NSString *svgPayloadURL;
    if(components != nil && components.count >1)
    {
        iconName = components[0];
        NSString  *iconStyle = components[1];
        NSString *regular = [NSString stringWithCString:IconStyleToString(IconStyle::Regular).c_str() encoding:NSUTF8StringEncoding];
        if ([iconStyle isEqualToString:regular])
        {
            isFilled = NO;
        }
    }
    if(iconName != nil && iconName.length != 0)
    {
        NSString *iconUrl = [[NSString alloc] initWithFormat:@"%@/%@.json",iconName,iconName];
        svgPayloadURL = cdnURLForIcon(iconUrl);
    }
    ACRBadgeView *badgeView = [[ACRBadgeView alloc] initWithRootView:rootView
                                                                text:[NSString stringWithCString:badge->GetText().c_str() encoding:NSUTF8StringEncoding]
                                                             toolTip:[NSString stringWithCString:badge->GetTooltip().c_str() encoding:NSUTF8StringEncoding]
                                                             iconUrl:svgPayloadURL
                                                            isFilled:isFilled
                                                          appearance:getBadgeAppearance(badge->GetBadgeAppearance())
                                                        iconPosition:getIconPosition(badge->GetIconPosition())
                                                                size:getBadgeSize(badge->GetBadgeSize())
                                                               shape:getShape(badge->GetShape())
                                                               style:getBadgeStyle(badge->GetBadgeStyle())
                                                          hostConfig:acoConfig];
    
    
    UIView *wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    wrapperView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeView.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapperView addSubview:badgeView];
    
    [NSLayoutConstraint activateConstraints:@[
        [wrapperView.topAnchor constraintEqualToAnchor:badgeView.topAnchor],
        [wrapperView.bottomAnchor constraintEqualToAnchor:badgeView.bottomAnchor],
        [wrapperView.leadingAnchor constraintLessThanOrEqualToAnchor:badgeView.leadingAnchor constant:0],
        [wrapperView.trailingAnchor constraintGreaterThanOrEqualToAnchor:badgeView.trailingAnchor constant:0]
    ]];
    
    ACRHorizontalAlignment acrHorizontalAlignment = getACRHorizontalAlignment(badge->GetHorizontalAlignment().value_or(HorizontalAlignment::Right));
    
    switch (acrHorizontalAlignment)
    {
        case ACRCenter:
            [NSLayoutConstraint activateConstraints:@[
                [wrapperView.centerXAnchor constraintEqualToAnchor:badgeView.centerXAnchor]
            ]];
            break;
        case ACRRight:
            [NSLayoutConstraint activateConstraints:@[
                [wrapperView.trailingAnchor constraintEqualToAnchor:badgeView.trailingAnchor],
            ]];
            break;
        case ACRLeft:
            [NSLayoutConstraint activateConstraints:@[
                [wrapperView.leadingAnchor constraintEqualToAnchor:badgeView.leadingAnchor]
            ]];
    }
    NSLayoutConstraint *width = [wrapperView.widthAnchor constraintEqualToAnchor:badgeView.widthAnchor];
    width.priority = 239;
    [width setActive:YES];
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:wrapperView withAreaName:areaName];
    
    return wrapperView;
}

@end
