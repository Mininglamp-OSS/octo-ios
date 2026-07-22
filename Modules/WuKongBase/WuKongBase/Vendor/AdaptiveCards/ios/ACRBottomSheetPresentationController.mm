//
//  ACRBottomSheetPresentationController.mm
//  AdaptiveCards
//
//  Created by Jitisha Azad on 24/06/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRBottomSheetPresentationController.h"

@interface ACRBottomSheetPresentationController ()

@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic) CGFloat keyboardHeight;
@property (nonatomic) BOOL isAdjustingForKeyboard;

@end

@implementation ACRBottomSheetPresentationController

#pragma mark - Frame Calculation

- (CGRect) frameOfPresentedViewInContainerView
{
    CGFloat targetHeight = self.presentedViewController.preferredContentSize.height;
    CGFloat containerHeight = self.containerView.bounds.size.height;
    CGFloat visibleHeight = containerHeight - self.keyboardHeight;
    CGFloat y = visibleHeight - targetHeight;
    CGFloat safeY = self.presentingViewController.view.safeAreaInsets.top;
    y = y <= 0 ? safeY : y;
    return CGRectMake(0, y, self.containerView.bounds.size.width, visibleHeight - y);
}

#pragma mark - Layout

- (void) containerViewWillLayoutSubviews
{
    self.dimmingView.frame = self.containerView.bounds;

    if (!self.isAdjustingForKeyboard)
    {
        self.presentedView.frame = [self frameOfPresentedViewInContainerView];
    }

    self.presentedView.layer.cornerRadius = 10;
    self.presentedView.clipsToBounds = YES;
}

#pragma mark - Presentation

- (void) presentationTransitionWillBegin
{
    if (!self.dimmingView)
    {
        self.dimmingView = [[UIView alloc] initWithFrame:self.containerView.bounds];
    }
    self.dimmingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.dimmingView.alpha = 0.0;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDimmingViewTap:)];
    [self.dimmingView addGestureRecognizer:tapGesture];
    
    [self.containerView insertSubview:self.dimmingView atIndex:0];
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.dimmingView.alpha = 1.0;
    }];

    // Register keyboard observers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

#pragma mark - Dismissal

- (void) dismissalTransitionWillBegin
{
    __weak __typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.dimmingView.alpha = 0.0;
    }];
}

- (void) dismissalTransitionDidEnd:(BOOL)completed
{
    if (completed)
    {
        [self.dimmingView removeFromSuperview];
        self.dimmingView = nil;

        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

#pragma mark - Keyboard Handling

- (void) keyboardWillShow:(NSNotification *)notification
{
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.keyboardHeight = kbFrame.size.height;
    self.isAdjustingForKeyboard = YES;

    CGRect newFrame = [self frameOfPresentedViewInContainerView];
    NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:animationDuration animations:^{
        self.presentedView.frame = newFrame;
    } completion:^(BOOL finished) {
        self.isAdjustingForKeyboard = NO;
    }];
}

- (void) keyboardWillHide:(NSNotification *)notification
{
    self.keyboardHeight = 0;
    self.isAdjustingForKeyboard = YES;

    CGRect newFrame = [self frameOfPresentedViewInContainerView];
    NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:animationDuration animations:^{
        self.presentedView.frame = newFrame;
    } completion:^(BOOL finished) {
        self.isAdjustingForKeyboard = NO;
    }];
}

#pragma mark - Dimming Tap

- (void) handleDimmingViewTap:(UITapGestureRecognizer *)gesture
{
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
