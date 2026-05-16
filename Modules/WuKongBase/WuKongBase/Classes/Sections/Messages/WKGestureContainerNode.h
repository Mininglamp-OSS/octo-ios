// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKGestureContainerNode.h — replaces TelegramUtils ContextControllerSourceNode (GPL v2)
//
//  Provides the long-press gesture and container hierarchy previously handled
//  by Telegram's ContextControllerSourceNode (AsyncDisplayKit-based).

#import <AsyncDisplayKit/AsyncDisplayKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Drop-in ASDisplayNode replacement for ContextControllerSourceNode.
/// Owns a UILongPressGestureRecognizer and fires shouldBegin/activated blocks.
@interface WKGestureContainerNode : ASDisplayNode

/// When NO the gesture recognizer is disabled.
@property (nonatomic, assign) BOOL isGestureEnabled;

/// Pointer to the inner content node, used for target-tracking animations.
@property (nonatomic, strong, nullable) ASDisplayNode *targetNodeForActivationProgress;

/// Returns YES if the long-press gesture should begin at the given point.
@property (nonatomic, copy) BOOL (^shouldBeginBlock)(CGPoint point);

/// Called when the long-press activates. `gesture` is the UILongPressGestureRecognizer.
@property (nonatomic, copy) void (^activatedBlock)(UIGestureRecognizer * _Nullable gesture, CGPoint point);

/// Compatibility shim — no-op (Telegram used this to update highlight animation rect).
- (void)targetNodeForActivationProgressContentRectForOCWithRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
