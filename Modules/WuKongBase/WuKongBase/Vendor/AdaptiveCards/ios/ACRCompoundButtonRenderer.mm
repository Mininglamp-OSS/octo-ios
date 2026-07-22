//
//  ACRCompoundButtonRenderer.m
//  AdaptiveCards
//
//  Created by Abhishek on 24/04/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRColumnView.h"
#import "ACRContentHoldingUIView.h"
#import "ACRImageProperties.h"
#import "ACRTapGestureRecognizerFactory.h"
#import "ACRUIImageView.h"
#import "ACRView.h"
#import "Enums.h"
#import "Icon.h"
#import "SharedAdaptiveCard.h"
#import "UtiliOS.h"
#import "ACRSVGImageView.h"
#import "ACRSVGIconHoldingView.h"
#import "CompoundButton.h"
#import "ACRCompoundButtonRenderer.h"
#import "ACRUILabel.h"
#import "UtiliOS.h"
#import "ARCGridViewLayout.h"

@implementation ACRCompoundButtonRenderer

+ (ACRCompoundButtonRenderer *)getInstance
{
    static ACRCompoundButtonRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRCompoundButton;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<CompoundButton> compoundButton = std::dynamic_pointer_cast<CompoundButton>(elem);
    std::shared_ptr<IconInfo> icon = compoundButton->getIcon();
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];

    UIStackView *verticalStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    verticalStack.axis = UILayoutConstraintAxisVertical;
    verticalStack.translatesAutoresizingMaskIntoConstraints = NO;
    verticalStack.alignment = UIStackViewAlignmentLeading;
    verticalStack.distribution = UIStackViewDistributionEqualSpacing;
    verticalStack.spacing = 4;
    
    UIStackView *horizontalStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    horizontalStack.translatesAutoresizingMaskIntoConstraints = NO;
    horizontalStack.spacing = 8;
    horizontalStack.alignment = UIStackViewAlignmentCenter;
    horizontalStack.distribution = UIStackViewDistributionEqualCentering;
    
    if(icon != nil)
    {
        ACRSVGIconHoldingView* iconView = [self getIconViewWithIconInfo:icon
                                                               rootView:rootView
                                                             hostConfig:acoConfig];
        [horizontalStack addArrangedSubview:iconView];
    }
   
    
    UILabel *titleLabel = [self getTitleLabelWithText:compoundButton->getTitle() viewGroup:viewGroup hostConfig:acoConfig];
    
    UILabel* descriptionLabel = [self getDescriptionLabelWithText:compoundButton->getDescription()
                                                           viewGroup:viewGroup
                                                          hostConfig:acoConfig];

   
    
    [horizontalStack addArrangedSubview:titleLabel];
    if(!compoundButton->getBadge().empty()) {
        UIView *badgeView = [self getBadgeLabelWithText:compoundButton->getBadge()
                                                   viewGroup:viewGroup
                                                  hostConfig:acoConfig];
        [horizontalStack addArrangedSubview:badgeView];
    }
    [verticalStack addArrangedSubview:horizontalStack];
    [verticalStack addArrangedSubview:descriptionLabel];
    
    UIView *compoundButtonView = [[UIView alloc] initWithFrame:CGRectZero];
    compoundButtonView.translatesAutoresizingMaskIntoConstraints = NO;
    compoundButtonView.layer.borderWidth = 1;
    std::string compoundButtonViewBorderColor = config->GetCompoundButtonConfig().borderColor;
    compoundButtonView.layer.borderColor = [ACOHostConfig convertHexColorCodeToUIColor:compoundButtonViewBorderColor].CGColor;
    compoundButtonView.layer.cornerRadius = 12;
    [compoundButtonView addSubview:verticalStack];
    [NSLayoutConstraint activateConstraints:@[
        [verticalStack.leadingAnchor constraintEqualToAnchor:compoundButtonView.leadingAnchor constant:16],
        [verticalStack.trailingAnchor constraintEqualToAnchor:compoundButtonView.trailingAnchor constant:-16],
        [verticalStack.topAnchor constraintEqualToAnchor:compoundButtonView.topAnchor constant:16],
        [verticalStack.bottomAnchor constraintLessThanOrEqualToAnchor:compoundButtonView.bottomAnchor constant:-16]
    ]];

    configRtl(compoundButtonView, rootView.context);
    
    std::shared_ptr<BaseActionElement> selectAction = compoundButton->GetSelectAction();
    ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:selectAction];
    addSelectActionToView(acoConfig, acoSelectAction, rootView, compoundButtonView, viewGroup);
    compoundButtonView.accessibilityLabel = @(compoundButton->getTitle().c_str());
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:compoundButtonView withAreaName:areaName];
    return compoundButtonView;
}

-(UILabel*) getTitleLabelWithText:(std::string) title
                             viewGroup:(UIView<ACRIContentHoldingView> *)viewGroup
                            hostConfig:(ACOHostConfig *)acoConfig
{
    UILabel * titleLabel = [[UILabel alloc] init];
    titleLabel.textColor =  [acoConfig getTextBlockColor:[viewGroup style] textColor:ForegroundColor::Default subtleOption:NO];
    titleLabel.text = @(title.c_str());
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    return titleLabel;
}

-(ACRSVGIconHoldingView*) getIconViewWithIconInfo:(std::shared_ptr<IconInfo>) icon
                                      rootView:(ACRView *)rootView
                                    hostConfig:(ACOHostConfig *)acoConfig
{
    
    NSString *svgPayloadURL = cdnURLForIcon(@(icon->GetSVGPath().c_str()));
    UIColor *imageTintColor = [acoConfig getTextBlockColor:(ACRContainerStyle::ACRDefault) textColor:icon->getForgroundColor() subtleOption:false];
    
    CGSize size = CGSizeMake(getIconSize(icon->getIconSize()), getIconSize(icon->getIconSize()));
    
    BOOL isFilled = (icon->getIconStyle() == IconStyle::Filled);
    ACRSVGImageView *iconView = [[ACRSVGImageView alloc] init:svgPayloadURL
                                                          rtl:rootView.context.rtl
                                                     isFilled:isFilled
                                                         size:size
                                                    tintColor:imageTintColor];
    ACRSVGIconHoldingView *iconViewWraper = [[ACRSVGIconHoldingView alloc] init:iconView size:size];
    iconViewWraper.translatesAutoresizingMaskIntoConstraints = NO;
    return iconViewWraper;
}

-(UILabel*) getDescriptionLabelWithText:(std::string) description
                             viewGroup:(UIView<ACRIContentHoldingView> *)viewGroup
                            hostConfig:(ACOHostConfig *)acoConfig
{
    UILabel * descriptionLabel = [[UILabel alloc] init];
    descriptionLabel.textColor =  [acoConfig getTextBlockColor:[viewGroup style] textColor:ForegroundColor::Default subtleOption:NO];
    descriptionLabel.text = @(description.c_str());
    descriptionLabel.backgroundColor = [UIColor clearColor];
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    descriptionLabel.numberOfLines = 0;
    descriptionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    return descriptionLabel;
}

-(UIView*) getBadgeLabelWithText:(std::string) badge
                             viewGroup:(UIView<ACRIContentHoldingView> *)viewGroup
                            hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    UIView *badgeContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    badgeContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    badgeContainerView.layer.cornerRadius = 9;
    badgeContainerView.clipsToBounds = YES;
    std::string badgeBackgroundColor = config->GetCompoundButtonConfig().badgeConfig.backgroundColor;
    badgeContainerView.backgroundColor = [ACOHostConfig convertHexColorCodeToUIColor:badgeBackgroundColor];
    badgeContainerView.layer.borderWidth = 2.4;
    badgeContainerView.layer.borderColor = [ACOHostConfig convertHexColorCodeToUIColor:badgeBackgroundColor].CGColor;
    UILabel * badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    badgeLabel.textColor =  [acoConfig getBackgroundColorForContainerStyle:[viewGroup style]];
    badgeLabel.text = @(badge.c_str());
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    badgeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [badgeContainerView addSubview:badgeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [badgeLabel.leadingAnchor constraintEqualToAnchor:badgeContainerView.leadingAnchor constant:7.2],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:badgeContainerView.trailingAnchor constant:-7.2],
        [badgeLabel.topAnchor constraintEqualToAnchor:badgeContainerView.topAnchor constant:2.4],
        [badgeLabel.bottomAnchor constraintEqualToAnchor:badgeContainerView.bottomAnchor constant:-2.4],
        [badgeLabel.widthAnchor constraintLessThanOrEqualToConstant:80]
    ]];

    return badgeContainerView;
}

@end
