// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMultipleSelectToHereButton.m
//  WuKongBase
//

#import "WKMultipleSelectToHereButton.h"
#import "WuKongBase.h"

@interface WKMultipleSelectToHereButton ()

@property(nonatomic,assign) WKMultipleSelectToHerePosition position;
@property(nonatomic,strong) UIVisualEffectView *blurView;
@property(nonatomic,strong) UILabel *iconLabel;
@property(nonatomic,strong) UILabel *textLabel;
@property(nonatomic,assign) BOOL showing;

@end

static const CGFloat kButtonHeight = 32.0f;
static const CGFloat kCornerRadius = 16.0f;
static const CGFloat kHorizontalPadding = 14.0f;
static const CGFloat kIconTextSpacing = 4.0f;
static const CGFloat kEnterOffset = 8.0f;

@implementation WKMultipleSelectToHereButton

- (instancetype)initWithPosition:(WKMultipleSelectToHerePosition)position {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _position = position;
        [self setupViews];
        [self sizeToFitContent];
        self.alpha = 0.0f;
        self.hidden = YES;
        self.showing = NO;
    }
    return self;
}

- (void)setupViews {
    UIColor *themeColor = [WKApp shared].config.themeColor;

    // 阴影挂在外层，毛玻璃挂在内层（毛玻璃要剪裁，阴影不能剪裁）
    self.layer.shadowColor = themeColor.CGColor;
    self.layer.shadowOpacity = 0.12f;
    self.layer.shadowRadius = 10.0f;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.masksToBounds = NO;

    UIBlurEffect *effect;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialLight];
    } else {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    }
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    self.blurView.layer.cornerRadius = kCornerRadius;
    self.blurView.layer.borderWidth = 1.0f;
    self.blurView.layer.borderColor = themeColor.CGColor;
    self.blurView.layer.masksToBounds = YES;
    self.blurView.userInteractionEnabled = NO;
    [self addSubview:self.blurView];

    self.iconLabel = [[UILabel alloc] init];
    self.iconLabel.text = @"✓"; // ✓
    self.iconLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightBold];
    self.iconLabel.textColor = themeColor;
    self.iconLabel.textAlignment = NSTextAlignmentCenter;
    [self.blurView.contentView addSubview:self.iconLabel];

    self.textLabel = [[UILabel alloc] init];
    self.textLabel.text = LLang(@"选到这里");
    self.textLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightMedium];
    self.textLabel.textColor = themeColor;
    [self.blurView.contentView addSubview:self.textLabel];
}

- (void)sizeToFitContent {
    [self.iconLabel sizeToFit];
    [self.textLabel sizeToFit];
    CGFloat width = kHorizontalPadding + self.iconLabel.bounds.size.width + kIconTextSpacing + self.textLabel.bounds.size.width + kHorizontalPadding;
    self.bounds = CGRectMake(0, 0, ceil(width), kButtonHeight);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blurView.frame = self.bounds;

    CGFloat iconW = self.iconLabel.bounds.size.width;
    CGFloat textW = self.textLabel.bounds.size.width;
    CGFloat iconH = self.iconLabel.bounds.size.height;
    CGFloat textH = self.textLabel.bounds.size.height;

    self.iconLabel.frame = CGRectMake(kHorizontalPadding,
                                       (self.bounds.size.height - iconH) / 2.0f,
                                       iconW, iconH);
    self.textLabel.frame = CGRectMake(CGRectGetMaxX(self.iconLabel.frame) + kIconTextSpacing,
                                       (self.bounds.size.height - textH) / 2.0f,
                                       textW, textH);

    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:kCornerRadius].CGPath;
}

#pragma mark - touch feedback

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12f animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96f, 0.96f) : CGAffineTransformIdentity;
    }];
}

#pragma mark - show / hide

- (void)showAnimated:(BOOL)animated {
    if (self.showing) return;
    self.showing = YES;
    self.hidden = NO;

    CGFloat dy = (self.position == WKMultipleSelectToHerePositionTop) ? -kEnterOffset : kEnterOffset;
    if (animated) {
        self.transform = CGAffineTransformMakeTranslation(0, dy);
        self.alpha = 0.0f;
        [UIView animateWithDuration:0.18f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.transform = CGAffineTransformIdentity;
            self.alpha = 1.0f;
        } completion:nil];
    } else {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0f;
    }
}

- (void)hideAnimated:(BOOL)animated {
    if (!self.showing) {
        self.alpha = 0.0f;
        self.hidden = YES;
        return;
    }
    self.showing = NO;

    CGFloat dy = (self.position == WKMultipleSelectToHerePositionTop) ? -kEnterOffset : kEnterOffset;
    if (animated) {
        [UIView animateWithDuration:0.16f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.transform = CGAffineTransformMakeTranslation(0, dy);
            self.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if (!self.showing) {
                self.hidden = YES;
                self.transform = CGAffineTransformIdentity;
            }
        }];
    } else {
        self.alpha = 0.0f;
        self.hidden = YES;
    }
}

@end
