// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKShimmerView.h — replaces TelegramUtils StickerShimmerEffectNode (GPL v2)
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Drop-in UIView replacement for `StickerShimmerEffectNode`.
/// Provides a sliding gradient shimmer as a loading placeholder for sticker images.
@interface WKShimmerView : UIView

/// Returns self — kept for call-site compatibility with the ASDisplayNode `.view` pattern.
@property (nonatomic, readonly) WKShimmerView *view;

- (void)updateWithBackgroundColor:(nullable UIColor *)backgroundColor
                  foregroundColor:(UIColor *)foregroundColor
                  shimmeringColor:(UIColor *)shimmeringColor
                             data:(nullable NSData *)data
                             size:(CGSize)size
                        imageSize:(CGSize)imageSize
                         isDecode:(BOOL)isDecode;

- (void)updateAbsoluteRect:(CGRect)rect within:(CGSize)size;

/// Compatibility alias for `removeFromSuperview`.
- (void)removeFromSupernode;

/// Fade out with the same signature as ASDisplayNode's animation helper.
- (void)layer_animateAlphaFrom:(CGFloat)from
                            to:(CGFloat)to
                      duration:(double)duration
                         delay:(double)delay
                timingFunction:(NSString *)timingFunction
           mediaTimingFunction:(nullable id)mediaTimingFunction
            removeOnCompletion:(BOOL)removeOnCompletion
                    completion:(nullable void (^)(BOOL))completion;

@end

NS_ASSUME_NONNULL_END
