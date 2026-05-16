// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKShimmerView.m — replaces TelegramUtils StickerShimmerEffectNode (GPL v2)
//

#import "WKShimmerView.h"

@interface WKShimmerView ()
@property (nonatomic, strong) CAGradientLayer *shimmerLayer;
@property (nonatomic, strong) UIColor *fgColor;
@end

@implementation WKShimmerView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.clipsToBounds = YES;
        [self setupShimmerLayer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        [self setupShimmerLayer];
    }
    return self;
}

- (void)setupShimmerLayer {
    _shimmerLayer = [CAGradientLayer layer];
    _shimmerLayer.startPoint = CGPointMake(0.0, 0.5);
    _shimmerLayer.endPoint   = CGPointMake(1.0, 0.5);

    UIColor *base  = [UIColor colorWithWhite:0.85 alpha:0.5];
    UIColor *shine = [UIColor colorWithWhite:0.95 alpha:0.8];
    _shimmerLayer.colors = @[
        (id)base.CGColor, (id)shine.CGColor, (id)base.CGColor
    ];
    _shimmerLayer.locations = @[@(-1.0), @(-0.5), @(0.0)];
    [self.layer addSublayer:_shimmerLayer];
    [self startShimmerAnimation];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _shimmerLayer.frame = self.bounds;
}

- (void)startShimmerAnimation {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
    anim.fromValue = @[@(-1.0), @(-0.5), @(0.0)];
    anim.toValue   = @[@(1.0),  @(1.5),  @(2.0)];
    anim.duration  = 1.4;
    anim.repeatCount = HUGE_VALF;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_shimmerLayer addAnimation:anim forKey:@"shimmer"];
}

#pragma mark - StickerShimmerEffectNode compatibility

- (WKShimmerView *)view { return self; }

- (void)updateWithBackgroundColor:(nullable UIColor *)backgroundColor
                  foregroundColor:(UIColor *)foregroundColor
                  shimmeringColor:(UIColor *)shimmeringColor
                             data:(nullable NSData *)data
                             size:(CGSize)size
                        imageSize:(CGSize)imageSize
                         isDecode:(BOOL)isDecode {
    self.backgroundColor = backgroundColor ?: [UIColor clearColor];
    UIColor *base = [foregroundColor colorWithAlphaComponent:0.3];
    self.shimmerLayer.colors = @[
        (id)base.CGColor,
        (id)[shimmeringColor colorWithAlphaComponent:0.6].CGColor,
        (id)base.CGColor
    ];
    // SVG-shaped cutout is intentionally not implemented — plain shimmer suffices.
}

- (void)updateAbsoluteRect:(CGRect)rect within:(CGSize)size {
    // no-op: gradient fills the whole view.
}

- (void)removeFromSupernode { [self removeFromSuperview]; }

- (void)layer_animateAlphaFrom:(CGFloat)from
                            to:(CGFloat)to
                      duration:(double)duration
                         delay:(double)delay
                timingFunction:(NSString *)timingFunction
           mediaTimingFunction:(nullable id)mediaTimingFunction
            removeOnCompletion:(BOOL)removeOnCompletion
                    completion:(nullable void (^)(BOOL))completion {
    self.alpha = from;
    [UIView animateWithDuration:duration delay:delay options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.alpha = to;
    } completion:^(BOOL finished) {
        if (removeOnCompletion) [self removeFromSuperview];
        if (completion) completion(finished);
    }];
}

@end
