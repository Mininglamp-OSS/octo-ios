//
//  ACRPopoverTarget.mm
//  AdaptiveCards
//
//  Created by Jitisha Azad on 01/07/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRPopoverTarget.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACRBottomSheetViewController.h"
#import "ACRBottomSheetConfiguration.h"
#import "ACRContentStackView.h"
#import "ACRRegistration.h"
#import "ACRBaseCardElementRenderer.h"  
#import "PopoverAction.h"
#import <AdaptiveCards/ACRRegistration.h>
#import <AdaptiveCards/ACOBaseCardElement.h>
#import <AdaptiveCards/ACRIBaseCardElementRenderer.h>
#import "ACRIBaseInputHandler.h"
#import "ACRView.h"
#import <UIKit/UIKit.h>
#import "ACRInputLabelView.h"
#import "ACROverflowTarget.h"
#import "UtiliOS.h"

@interface ACRPopoverTarget()

@property ACRBottomSheetViewController *currentBottomSheet;
@property ACOBaseActionElement *actionElement;
@property (nonatomic, weak) ACRView *rootView;
@property (nonatomic, strong) ACRContentStackView *cachedContentView;

@end

@implementation ACRPopoverTarget

- (instancetype)initWithActionElement:(ACOBaseActionElement *)actionElement rootView:(ACRView *)rootView
{
    self = [super init];
    if (self)
    {
        self.actionElement = actionElement;
        self.rootView = rootView;
        self.currentBottomSheet = nil;
        self.cachedContentView = nil;
    }
    return self;
}

- (IBAction)send:(UIButton *)sender
{
    [self doSelectAction];
}

- (void)doSelectAction
{
    [self presentPopover];
}

- (void)presentPopover
{
    if (!self.actionElement || self.actionElement.type != ACRPopover)
    {
        return;
    }
    
    id<ACRActionDelegate> actionDelegate = self.rootView.acrActionDelegate;
    if (![actionDelegate respondsToSelector:@selector(activeViewController)])
    {
        return;
    }
    
    UIViewController *host = [actionDelegate activeViewController];
    if (!host)
    {
        return;
    }
    
    // Create or reuse cached content view for input retention
    if (!self.cachedContentView)
    {
        [self createCachedContentView];
    }
    
    if (!self.cachedContentView)
    {
        return;
    }
    [self attachBottomSheetInputsToMainCard];
    
    ACRBottomSheetConfiguration *config = [[ACRBottomSheetConfiguration alloc] initWithHostConfig:self.rootView.hostConfig];
    
    self.currentBottomSheet = [[ACRBottomSheetViewController alloc] initWithContent:self.cachedContentView configuration:config];
    [self markActionTargetsAsFromBottomSheet:self.cachedContentView];
    
    __weak ACRPopoverTarget *weakSelf = self;
    self.currentBottomSheet.onDismissBlock = ^{
        if (weakSelf)
        {
            [weakSelf detachBottomSheetInputsFromMainCard];
        }
    };
    [host presentViewController:self.currentBottomSheet animated:YES completion:nil];
}

- (void)bottomSheetCloseTapped
{
    [self detachBottomSheetInputsFromMainCard];
}

- (void)createCachedContentView
{
    // Get the popover content from the action
    std::shared_ptr<BaseActionElement> base = [self.actionElement element];
    auto popoverAction = std::dynamic_pointer_cast<AdaptiveCards::PopoverAction>(base);
    std::shared_ptr<AdaptiveCards::BaseCardElement> content = popoverAction ? popoverAction->GetContent() : nullptr;
    
    if (!content)
    {
        return;
    }
    
    ACOBaseCardElement *acoElement = [[ACOBaseCardElement alloc] initWithBaseCardElement:content];
    
    ACRCardElementType elementType = (ACRCardElementType)content->GetElementType();
    NSNumber *key = @(elementType);
    ACRBaseCardElementRenderer *renderer = [[ACRRegistration getInstance] getRenderer:key];
    if (!renderer)
    {
        return;
    }
    
    // Prepare shared inputs (shared with main card for state consistency)
    NSArray *sharedInputs = [[self.rootView card] getInputs];
    if (!sharedInputs)
    {
        [[self.rootView card] setInputs:[NSArray array]];
    }
    self.cachedContentView = [[ACRContentStackView alloc] initWithStyle:ACRDefault
                                                        parentStyle:ACRDefault
                                                         hostConfig:self.rootView.hostConfig
                                                          superview:self.rootView];
    self.rootView.isRenderingInsideBottomSheet = YES;
    @try {
        // Render the content into the cached container
        [renderer render:self.cachedContentView
                rootView:self.rootView
                  inputs:[sharedInputs mutableCopy]
         baseCardElement:acoElement
              hostConfig:self.rootView.hostConfig];
    } @catch (ACOFallbackException *e) {
        NSLog(@"ACRPopoverTarget: Fallback exception caught during popover content rendering: %@", e);
    }
}

- (void)markActionTargetsAsFromBottomSheet:(UIView *)containerView
{
    // Traverse all subviews to find and mark action targets
    for (UIView *subview in containerView.subviews)
    {
        for (UIGestureRecognizer *recognizer in subview.gestureRecognizers)
        {
            if ([recognizer.delegate isKindOfClass:[ACRBaseTarget class]])
            {
                ACRBaseTarget *target = (ACRBaseTarget *)recognizer.delegate;
                target.presentedViewController = self.currentBottomSheet;
                [self filterActionTarget:target forView:subview];
            }
        }
        
        // Check if this view has any target-action connections with ACRBaseTarget
        if ([subview isKindOfClass:[UIControl class]])
        {
            UIControl *control = (UIControl *)subview;
            NSSet *targets = [control allTargets];
            for (id target in targets)
            {
                if ([target isKindOfClass:[ACRBaseTarget class]])
                {
                    ACRBaseTarget *baseTarget = (ACRBaseTarget *)target;
                    baseTarget.presentedViewController = self.currentBottomSheet;
                    [self filterActionTarget:baseTarget forView:subview];
                    if ([baseTarget isKindOfClass:[ACROverflowTarget class]])
                    {
                        [self propagatePopoverContextToOverflowMenuItems:(ACROverflowTarget *)baseTarget];
                    }
                }
            }
        }
        [self markActionTargetsAsFromBottomSheet:subview];
    }
}

- (void)propagatePopoverContextToOverflowMenuItems:(ACROverflowTarget *)overflowTarget
{
    NSArray<ACROverflowMenuItem *> *menuItems = overflowTarget.menuItems;
    for (ACROverflowMenuItem *menuItem in menuItems)
    {
        NSObject<ACRSelectActionDelegate> *itemTarget = menuItem.target;
        if ([itemTarget isKindOfClass:[ACRBaseTarget class]])
        {
            ACRBaseTarget *baseTarget = (ACRBaseTarget *)itemTarget;
            baseTarget.presentedViewController = self.currentBottomSheet;
        }
    }
}

- (void)filterActionTarget:(ACRBaseTarget *)target forView:(UIView *)view
{
    if ([target respondsToSelector:@selector(actionElement)])
    {
        ACOBaseActionElement *actionElement = [target performSelector:@selector(actionElement)];
        if (actionElement)
        {
            ACRActionType actionType = actionElement.type;
            
            // Filter elements in bottom sheet
            if (actionType == ACRToggleVisibility ||
                actionType == ACRShowCard ||
                actionType == ACRPopover)
            {
                [view removeFromSuperview];
            }
            
            if ((actionType == ACRSubmit || actionType == ACRExecute) &&
                actionElement.menuActions.count > 0)
            {
                actionElement.isActionFromSplitButtonBottomSheet = YES;
            }
        }
    }
}

- (void)dismissBottomSheet
{
    if (self.currentBottomSheet && self.currentBottomSheet.presentingViewController)
    {
        [self.currentBottomSheet dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)attachBottomSheetInputsToMainCard
{
    if (!self.cachedContentView || !self.rootView)
    {
        return;
    }
    
    NSArray<ACRIBaseInputHandler> *bottomSheetInputs = [self findInputHandlersInView:self.cachedContentView];
    [self.rootView.inputHandlers addObjectsFromArray:bottomSheetInputs];
}

- (NSArray<ACRIBaseInputHandler> *)findInputHandlersInView:(UIView *)view
{
    NSMutableArray<id<ACRIBaseInputHandler>> *collectedInputs = [NSMutableArray array];
    [self collectInputHandlersInView:view intoArray:collectedInputs];
    return [collectedInputs copy];
}

- (void)collectInputHandlersInView:(UIView *)view intoArray:(NSMutableArray<id<ACRIBaseInputHandler>> *)inputHandlers
{
    if ([view conformsToProtocol:@protocol(ACRIBaseInputHandler)]) {
        id<ACRIBaseInputHandler> inputHandler = (id<ACRIBaseInputHandler>)view;
        [inputHandlers addObject:inputHandler];
        
        if ([view isKindOfClass:[ACRInputLabelView class]]) {
            ACRInputLabelView *labelView = (ACRInputLabelView *)view;
            NSObject<ACRIBaseInputHandler> *underlyingHandler = [labelView getInputHandler];
            if (underlyingHandler && underlyingHandler != labelView) {
                underlyingHandler.isRequired = NO;
            }
        }
    }
    
    for (UIView *subview in view.subviews) {
        [self collectInputHandlersInView:subview intoArray:inputHandlers];
    }
}

- (void)detachBottomSheetInputsFromMainCard
{
    if (!self.cachedContentView || !self.rootView)
    {
        return;
    }
    
    NSArray<ACRIBaseInputHandler> *bottomSheetInputs = [self findInputHandlersInView:self.cachedContentView];
    for (id<ACRIBaseInputHandler> input in bottomSheetInputs)
    {
        [self.rootView.inputHandlers removeObject:input];
    }
}

@end
