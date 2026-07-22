//
//  ACRCitationPresenter.m
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 25/03/26.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRCitationPresenter.h"
#import "ACRBottomSheetViewController.h"
#import "ACRBottomSheetConfiguration.h"
#import "ACRCitationReferenceView.h"
#import "ACRActionDelegate.h"
#import "ACRRenderer.h"
#import "ACRRenderResult.h"
#import "ACOHostConfig.h"
#import "ACOCitation.h"
#import "ACOReference.h"
#import "ACOAdaptiveCard.h"

static NSString *const referencesKey = @"References";

@interface ACRCitationPresenter () <ACRCitationReferenceViewDelegate>

@property (nonatomic, strong) ACOHostConfig *hostConfig;
@property (nonatomic, weak)   id<ACRActionDelegate> actionDelegate;

@property (nonatomic, weak) UIViewController *bottomSheetViewController;
@property (nonatomic, weak) UIViewController *activeViewController;

@end

@implementation ACRCitationPresenter

- (instancetype)initWithHostConfig:(ACOHostConfig *)hostConfig
                    actionDelegate:(id<ACRActionDelegate>)actionDelegate
{
    self = [super init];
    if (self) {
        _hostConfig       = hostConfig;
        _actionDelegate   = actionDelegate;
    }
    return self;
}

#pragma mark - ACICitationPresenter (optional — native card path)

- (void)handleCitationTap:(ACOCitation *)citation
            referenceData:(ACOReference * _Nullable)referenceData
{
    if (![self.actionDelegate respondsToSelector:@selector(activeViewController)]) {
        return;
    }
    UIViewController *host = [self.actionDelegate activeViewController];
    [self presentBottomSheetFrom:host didTapCitation:citation referenceData:referenceData];
}

#pragma mark - ACICitationPresenter (required — web-rendering path)

- (void)presentBottomSheetFrom:(UIViewController *)activeController
                didTapCitation:(ACOCitation *)citation
                 referenceData:(ACOReference * _Nullable)referenceData
{
    self.activeViewController = activeController;

    ACRCitationReferenceView *citationView = [[ACRCitationReferenceView alloc] initWithCitation:citation
                                                                                       reference:referenceData];
    citationView.delegate = self;

    ACOHostConfig *hostConfig = self.hostConfig ?: [[ACOHostConfig alloc] init];
    ACRBottomSheetConfiguration *config = [[ACRBottomSheetConfiguration alloc] initWithHostConfig:hostConfig];
    config.dismissButtonType = ACRBottomSheetDismissButtonTypeNone;
    config.contentPadding    = 8;
    config.headerText        = NSLocalizedString(referencesKey, nil);

    ACRBottomSheetViewController *sheet = [[ACRBottomSheetViewController alloc] initWithContent:citationView
                                                                                  configuration:config];
    self.bottomSheetViewController = sheet;
    [activeController presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - ACRCitationReferenceViewDelegate

- (void)citationReferenceView:(ACRCitationReferenceView *)citationReferenceView
     didTapMoreDetailsForCitation:(ACOCitation *)citation
                        reference:(ACOReference *)reference
{
    ACRBottomSheetConfiguration *config = [[ACRBottomSheetConfiguration alloc] initWithHostConfig:self.hostConfig];
    config.contentPadding      = 8;
    config.minHeight           = self.bottomSheetViewController.preferredContentSize.height;
    config.dismissButtonType   = ACRBottomSheetDismissButtonTypeBack;
    config.headerText          = NSLocalizedString(referencesKey, nil);
    config.referenceWindowSize = self.activeViewController.view.frame.size;

    ACOAdaptiveCard *acoCard = reference.content;
    acoCard.shouldNotRenderActions = YES;
    ACRRenderResult *renderResult = [ACRRenderer render:acoCard
                                                 config:self.hostConfig
                                        widthConstraint:config.referenceWindowSize.width - (2 * config.contentPadding)
                                               delegate:self.actionDelegate
                                                  theme:citation.theme];

    if (!renderResult.view) {
        return;
    }

    UIView *cardContentView = (UIView *)renderResult.view;
    ACRBottomSheetViewController *detailSheet = [[ACRBottomSheetViewController alloc] initWithContent:cardContentView
                                                                                        configuration:config];
    [self.bottomSheetViewController presentViewController:detailSheet animated:YES completion:nil];
}

@end
