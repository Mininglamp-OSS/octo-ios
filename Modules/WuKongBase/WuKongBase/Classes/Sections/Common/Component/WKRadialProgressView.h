// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRadialProgressView.h — replaces TelegramUtils RadialStatusNode (GPL v2)
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Drop-in UIView replacement for `RadialStatusNode`.
/// Renders a circular countdown progress ring for burn-after-reading messages.
@interface WKRadialProgressView : UIView

/// Returns self — kept for call-site compatibility with the ASDisplayNode `.view` pattern.
@property (nonatomic, readonly) WKRadialProgressView *view;

- (instancetype)initWithBackgroundNodeColor:(UIColor *)color enableBlur:(BOOL)enableBlur;

/// Start (or resume) the countdown animation.
- (void)transitionToStateWithIcon:(nullable UIImage *)icon
                        beginTime:(CFTimeInterval)beginTime
                          timeout:(CGFloat)timeout
                         animated:(BOOL)animated
                      synchronous:(BOOL)synchronous
                           sparks:(BOOL)sparks
                         finished:(nullable void (^)(void))finished;

/// Pause the countdown.
- (void)animatePaused;

@end

NS_ASSUME_NONNULL_END
