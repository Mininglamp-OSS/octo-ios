//
//  ACRToggleVisibilityTarget
//  ACRToggleVisibilityTarget.mm
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRToggleVisibilityTarget.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACOVisibilityManager.h"
#import "ACRContentStackView.h"
#import "ACRRendererPrivate.h"
#import "ACRView.h"
#import "BaseActionElement.h"
#import "ToggleVisibilityTarget.h"
#import "ACRIFeatureFlagResolver.h"
#import "ACRRegistration.h"

@implementation ACRToggleVisibilityTarget {
    ACOHostConfig *_config;
    __weak ACRView *_rootView;
    ACOBaseActionElement *_actionElement;
}

- (instancetype)initWithActionElement:(ACOBaseActionElement *)actionElement
                               config:(ACOHostConfig *)config
                             rootView:(ACRView *)rootView
{
    self = [super init];
    if (self) {
        _config = config;
        _rootView = rootView;
        _actionElement = actionElement;
    }
    return self;
}

- (void)doSelectAction
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
        [self doSelectActionWithAction:_actionElement];
    }
    else
    {
        NSArray<ACOBaseActionElement *> *menuActions = [@[ _actionElement ] arrayByAddingObjectsFromArray:_actionElement.menuActions];
        __weak __typeof(self) weakSelf = self;
        [_rootView.acrActionDelegate showBottomSheetForSplitButton: menuActions completion:^(ACOBaseActionElement *acoElement) {
            __strong __typeof(self) strongSelf = weakSelf;
            if (acoElement.type == ACRToggleVisibility)
            {
                [strongSelf doSelectActionWithAction:acoElement];
            }
            [strongSelf->_rootView.acrActionDelegate didFetchUserResponses:[strongSelf->_rootView card] action:acoElement];
        }];
    }

    [_rootView.acrActionDelegate didFetchUserResponses:[_rootView card] action:_actionElement];
}

- (void) doSelectActionWithAction:(ACOBaseActionElement *)actionElement
{
    NSMutableSet<id<ACOIVisibilityManagerFacade>> *facades = [[NSMutableSet alloc] init];
    std::shared_ptr<BaseActionElement> elem = [actionElement element];
    std::shared_ptr<ToggleVisibilityAction> action = std::dynamic_pointer_cast<ToggleVisibilityAction>(elem);
    for (const auto &target : action->GetTargetElements()) {
        NSString *hashString = [NSString stringWithCString:target->GetElementId().c_str() encoding:NSUTF8StringEncoding];
        NSUInteger tag = hashString.hash;
        UIView *view = [_rootView viewWithTag:tag];
        BOOL bHide = NO;

        id<ACOIVisibilityManagerFacade> facade = [_rootView.context retrieveVisiblityManagerWithTag:view.tag];
        [facades addObject:facade];

        AdaptiveCards::IsVisible toggleEnum = target->GetIsVisible();
        if (toggleEnum == AdaptiveCards::IsVisibleToggle) {
            BOOL isHidden = view.isHidden;
            bHide = !isHidden;
        } else if (toggleEnum == AdaptiveCards::IsVisibleTrue) {
            bHide = NO;
        } else {
            bHide = YES;
        }

        if (facade) {
            if (bHide) {
                [facade hideView:view];
            } else {
                [facade unhideView:view];
            }
        }
    }

    for (id<ACOIVisibilityManagerFacade> viewToUpdateVisibility in facades) {
        [viewToUpdateVisibility updatePaddingVisibility];
    }

    // Repair stack layout for any host whose columns were just unhidden.
    //
    // Context: UIStackView retains stale internal UISV-spacing constraints when
    // a column is initially hidden and later unhidden via ToggleVisibility. The
    // fix is a full reset: remove all arranged subviews (with removeFromSuperview
    // to discard stale constraints), then re-add them in original order.
    //
    // This MUST run here in doSelectActionWithAction: (toggle-only context),
    // NOT in unhideView: which also fires during initial card rendering. At
    // initial render time views have zero frames, so the needsFix guard falsely
    // triggers and corrupts layout (e.g. WorkDay card buttons disappear).
    //
    // Safety notes:
    // - removeFromSuperview is safe: views are re-added synchronously in the
    //   same call, gesture recognizers survive (strong ref on view), and
    //   accessibility properties are stored on the view, not the parent.
    // - The operation is idempotent — repeated toggle cycles produce identical
    //   results.
    for (id<ACOIVisibilityManagerFacade> facade in facades) {
        if (![facade isKindOfClass:[ACRContentStackView class]]) {
            continue;
        }

        ACRContentStackView *hostView = (ACRContentStackView *)facade;
        if (hostView.frame.size.width < 1.0) {
            continue; // Host not yet laid out — skip to avoid false positives
        }

        NSArray<UIView *> *arranged = [hostView getArrangedSubviews];
        if (!arranged || arranged.count == 0) {
            continue;
        }

        // Check if any visible column has broken layout (zero width or off-screen)
        BOOL needsFix = NO;
        for (UIView *v in arranged) {
            if (!v.isHidden && (v.frame.size.width < 1.0 ||
                v.frame.origin.x >= hostView.frame.size.width)) {
                needsFix = YES;
                break;
            }
        }
        if (!needsFix) {
            continue;
        }

        // Full reset: remove all, then re-add in same order.
        NSArray<UIView *> *snapshot = [arranged copy];
        for (UIView *v in snapshot) {
            [hostView removeArrangedSubview:v];
            [v removeFromSuperview];
        }
        for (UIView *v in snapshot) {
            [hostView addArrangedSubview:v];
        }
        [hostView setNeedsLayout];
    }

    // Post accessibility notification so VoiceOver announces the layout change
    // and does not lose focus when elements are toggled (fixes #34)
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

@end
