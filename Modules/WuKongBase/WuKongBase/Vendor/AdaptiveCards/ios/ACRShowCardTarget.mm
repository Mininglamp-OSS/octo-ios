//
//  ACRShowCardTarget
//  ACRShowCardTarget.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRShowCardTarget.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRContentHoldingUIView.h"
#import "ACRIBaseInputHandler.h"
#import "ACRRendererPrivate.h"
#import "ACRViewPrivate.h"
#import "BaseActionElement.h"
#import "ACRToggleVisibilityTarget.h"
#import "ACRAggregateTarget.h"
#import "UtiliOS.h"
#import <UIKit/UIKit.h>

@implementation ACRShowCardTarget {
    std::shared_ptr<AdaptiveCards::AdaptiveCard> _adaptiveCard;
    ACOHostConfig *_config;
    __weak UIView<ACRIContentHoldingView> *_superview;
    __weak ACRView *_rootView;
    __weak ACRColumnView *_adcView;
    __weak UIButton *_button;
    ACOBaseActionElement *_actionElement;
}

- (instancetype)initWithActionElement:(std::shared_ptr<AdaptiveCards::ShowCardAction> const &)showCardActionElement
                               config:(ACOHostConfig *)config
                             rootView:(ACRView *)rootView
                               button:(UIButton *)button
{
    self = [super init];
    if (self) {
        _adaptiveCard = showCardActionElement->GetCard();
        _config = config;
        _superview = nil;
        _rootView = rootView;
        _adcView = nil;
        _button = button;
        _actionElement = [[ACOBaseActionElement alloc] initWithBaseActionElement:std::dynamic_pointer_cast<BaseActionElement>(showCardActionElement)];
    }
    return self;
}

- (void)createShowCard:(NSMutableArray *)inputs superview:(UIView<ACRIContentHoldingView> *)superview
{
    // configure padding using LayoutGuid
    unsigned int padding = [_config getHostConfig]->GetActions().showCard.inlineTopMargin;

    NSDictionary<NSString *, NSNumber *> *attributes =
        @{@"padding-top" : [NSNumber numberWithFloat:padding]};

    ACRColumnView *adcView = [[ACRColumnView alloc] initWithFrame:_rootView.frame
                                                       attributes:attributes];

    ACRColumnView *parentRenderedCard = [_rootView peekCurrentShowCard];

    [_rootView pushCurrentShowcard:adcView];

    [_rootView setParent:parentRenderedCard child:adcView];

    [ACRRenderer renderWithAdaptiveCards:_adaptiveCard
                                  inputs:adcView.inputHandlers
                                 context:_rootView
                          containingView:adcView
                              hostconfig:_config];

    ContainerStyle containerStyle = ([_config getHostConfig]->GetAdaptiveCard().allowCustomStyle) ? _adaptiveCard->GetStyle() : [_config getHostConfig]->GetActions().showCard.style;

    ACRContainerStyle style = (ACRContainerStyle)(containerStyle);

    if (style == ACRNone) {
        style = [superview style];
    }

    _adcView = adcView;
    _adcView.translatesAutoresizingMaskIntoConstraints = NO;

    CGFloat showCardPadding = [_config getHostConfig]->GetSpacing().paddingSpacing;

    _adcView.backgroundColor = UIColor.clearColor;
    
    _button.accessibilityValue = NSLocalizedString(@"card collapsed", nil);

    _adcView.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(showCardPadding, -showCardPadding, -showCardPadding, -showCardPadding);

    UIView *backgroundView = [[UIView alloc] init];
    [adcView addSubview:backgroundView];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundView.backgroundColor = [_config getBackgroundColorForContainerStyle:style];
    [adcView sendSubviewToBack:backgroundView];
    [backgroundView.leadingAnchor constraintEqualToAnchor:adcView.layoutMarginsGuide.leadingAnchor].active = YES;
    [backgroundView.trailingAnchor constraintEqualToAnchor:adcView.layoutMarginsGuide.trailingAnchor].active = YES;
    [backgroundView.topAnchor constraintEqualToAnchor:adcView.layoutMarginsGuide.topAnchor].active = YES;
    [backgroundView.bottomAnchor constraintEqualToAnchor:adcView.layoutMarginsGuide.bottomAnchor].active = YES;
    _adcView.hidden = YES;
    [superview addArrangedSubview:adcView withAreaName:nil];
    _superview = superview;
    superview.accessibilityElements = [((ACRContentStackView *)superview) getArrangedSubviews];
}

- (IBAction)toggleVisibilityOfShowCard
{
    NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
    BOOL isSplitButtonEnabled = [featureFlagResolver boolForFlag:@"isSplitButtonEnabled"] ?: NO;
    isSplitButtonEnabled = isSplitButtonEnabled &&
    [_rootView.acrActionDelegate respondsToSelector:@selector(showBottomSheetForSplitButton:completion:)];
    /// Perform default implementation if:
    /// 1. If split button is disabled or
    /// 2. There are no menuactions or
    /// 3.a. There are menuactions and
    /// 3.b. (If the action is from bottom sheet) or (If there's no implementation of showBottomSheetForSplitButton method in delegate)
    if (!isSplitButtonEnabled ||
        _actionElement.menuActions.count <= 0 ||
        (_actionElement.isActionFromSplitButtonBottomSheet && _actionElement.menuActions.count > 0))
    {
        BOOL isSelected = _button.selected;
        BOOL hidden = _adcView.hidden;
        [_superview hideAllShowCards];
        _adcView.hidden = !hidden;

        // send candidate background image view, if the sent view is UIImageView and has UIImage in it
        // AdatpiveCard will configure the backgroun
        if (hidden) {
            if ([_adcView.subviews count] > 1) {
                NSMutableArray<NSLayoutConstraint *> *constraints = [[NSMutableArray alloc] init];
                renderBackgroundCoverMode(_adcView.subviews[1], _adcView.backgroundView, constraints, _adcView);
                [NSLayoutConstraint activateConstraints:constraints];
            }
        }
        _button.selected = !isSelected;

        NSString *hint = hidden ? @"card expanded" : @"card collapsed";
        _button.accessibilityValue = NSLocalizedString(hint, nil);

        // Post accessibility notification so VoiceOver announces the state change
        // and moves focus to the expanded ShowCard content (fixes #166)
        if (hidden) {
            // Card was just expanded  move VoiceOver focus to the card content
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _adcView);
        } else {
            // Card was just collapsed  move VoiceOver focus back to the button
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _button);
        }

        if ([_rootView.acrActionDelegate respondsToSelector:@selector(didChangeVisibility:isVisible:)]) {
            [_rootView.acrActionDelegate didChangeVisibility:_button isVisible:(!_adcView.hidden)];
        }

        if ([_rootView.acrActionDelegate respondsToSelector:@selector(didChangeViewLayout:newFrame:)] && _adcView.hidden == NO) {
            CGRect showCardFrame = _adcView.frame;
            showCardFrame.origin = [_adcView convertPoint:_adcView.frame.origin toView:nil];
            CGRect oldFrame = showCardFrame;
            oldFrame.size.height = 0;
            showCardFrame.size.height += [_config getHostConfig]->GetActions().showCard.inlineTopMargin;
            [_rootView.acrActionDelegate didChangeViewLayout:oldFrame newFrame:showCardFrame];
        }
    }
    else
    {
        NSArray<ACOBaseActionElement *> *menuActions = [@[ _actionElement ] arrayByAddingObjectsFromArray:_actionElement.menuActions];
        __weak __typeof(self) weakSelf = self;
        [_rootView.acrActionDelegate showBottomSheetForSplitButton: menuActions completion:^(ACOBaseActionElement *acoElement) {
            __strong __typeof(self) strongSelf = weakSelf;
            if (acoElement.type == ACRShowCard)
            {
                [strongSelf toggleVisibilityOfShowCard];
            }
            if (acoElement.type == ACRToggleVisibility)
            {
                ACRToggleVisibilityTarget *toggleVisibility = [[ACRToggleVisibilityTarget alloc] initWithActionElement:acoElement config:strongSelf->_config rootView:strongSelf->_rootView];
                [toggleVisibility doSelectAction];
            }
            if (acoElement.type == ACRSubmit || acoElement.type == ACRExecute)
            {
                ACRAggregateTarget *target = [[ACRAggregateTarget alloc] initWithActionElement:acoElement rootView:strongSelf->_rootView];
                [target send:strongSelf->_button];
                return;
            }
            [strongSelf->_rootView.acrActionDelegate didFetchUserResponses:[strongSelf->_rootView card] action:acoElement];
        }];
    }
    [_rootView.acrActionDelegate didFetchUserResponses:[_rootView card] action:_actionElement];
}

- (void)doSelectAction
{
    [self toggleVisibilityOfShowCard];
}

- (void)hideShowCard
{
    _adcView.hidden = YES;
    _button.selected = NO;

    // Post accessibility notification so VoiceOver returns focus to the button
    // when the ShowCard is dismissed (fixes #165)
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _button);

    if ([_rootView.acrActionDelegate respondsToSelector:@selector(didChangeVisibility:isVisible:)]) {
        [_rootView.acrActionDelegate didChangeVisibility:_button isVisible:(!_adcView.hidden)];
    }
}

@end
