//
//  ACRProgressRingRenderer.m
//  AdaptiveCards
//
//  Created by Harika P on 07/05/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRProgressRingRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRRegistration.h"
#import "ProgressRing.h"
#import "UtiliOS.h"

@implementation ACRProgressRingRenderer

+ (ACRProgressRingRenderer *)getInstance
{
    static ACRProgressRingRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRProgressRing;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<ProgressRing> progressRing = std::dynamic_pointer_cast<ProgressRing>(elem);
    UIActivityIndicatorViewStyle style;
    switch (progressRing->GetSize())
    {
        case AdaptiveCards::ProgressSize::Tiny:
        case AdaptiveCards::ProgressSize::Small:
            style = UIActivityIndicatorViewStyleMedium;
            break;
        case AdaptiveCards::ProgressSize::Medium:
        case AdaptiveCards::ProgressSize::Large:
            style = UIActivityIndicatorViewStyleLarge;
            break;
    }
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    [activityIndicator startAnimating];
    activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:15];
    label.numberOfLines = 0;
    label.adjustsFontSizeToFitWidth = NO;
    label.text = [NSString stringWithUTF8String:progressRing->GetLabel().c_str()];
    
    [activityIndicator setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [activityIndicator setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    
    UIStackView *loaderView;
    UILayoutConstraintAxis axis;
    
    switch (progressRing->GetLabelPosition())
    {
        case AdaptiveCards::LabelPosition::Above:
            loaderView = [[UIStackView alloc] initWithArrangedSubviews:@[label, activityIndicator]];
            axis = UILayoutConstraintAxisVertical;
            break;
        case AdaptiveCards::LabelPosition::Below:
            loaderView = [[UIStackView alloc] initWithArrangedSubviews:@[activityIndicator, label]];
            axis = UILayoutConstraintAxisVertical;
            break;
        case AdaptiveCards::LabelPosition::Before:
            loaderView = [[UIStackView alloc] initWithArrangedSubviews:@[label, activityIndicator]];
            axis = UILayoutConstraintAxisHorizontal;
            break;
        case AdaptiveCards::LabelPosition::After:
            loaderView = [[UIStackView alloc] initWithArrangedSubviews:@[activityIndicator, label]];
            axis = UILayoutConstraintAxisHorizontal;
            break;
    }
    
    loaderView.axis = axis;
    loaderView.spacing = 2;
    loaderView.alignment = UIStackViewAlignmentCenter;
    loaderView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *containerView = [[UIStackView alloc] initWithArrangedSubviews:@[loaderView]];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.axis = UILayoutConstraintAxisVertical;
    
    switch (progressRing->GetHorizontalAlignment())
    {
        case AdaptiveCards::HorizontalAlignment::Left:
            containerView.alignment = UIStackViewAlignmentLeading;
            break;
        case AdaptiveCards::HorizontalAlignment::Center:
            containerView.alignment = UIStackViewAlignmentCenter;
            break;
        case AdaptiveCards::HorizontalAlignment::Right:
            containerView.alignment = UIStackViewAlignmentTrailing;
            break;
    }
    
    viewGroup.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIStackView *wrapperView = [[UIStackView alloc] initWithArrangedSubviews:@[containerView]];
    
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:wrapperView withAreaName:areaName];
    return wrapperView;
}
@end
