//
//  WKPixelParticleHint.m
//  WuKongBase
//
//  Cyberpunk HUD — 未来极客风消息提醒

#import "WKPixelParticleHint.h"
#import "WKApp.h"
#import <SDWebImage/UIImageView+WebCache.h>

static const CGFloat kHintWidth = 240.0f;
static const CGFloat kHintHeight = 58.0f;
static const CGFloat kAvatarSize = 34.0f;

@interface WKPixelParticleHint ()
@property (nonatomic, strong) UIView *hudCard;
@property (nonatomic, strong) UIView *scanLine;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *initialLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UILabel *tagLabel;
@property (nonatomic, strong) CAGradientLayer *borderGradient;
@property (nonatomic, strong) CAShapeLayer *cornerBrackets;
@property (nonatomic, strong) NSTimer *typewriterTimer;
@property (nonatomic, copy) NSString *fullContentText;
@property (nonatomic, assign) NSInteger typewriterIndex;
@property (nonatomic, copy, nullable) void(^tapAction)(void);
@end

static WKPixelParticleHint *_currentHint = nil;

@implementation WKPixelParticleHint

+ (void)showInView:(UIView *)parentView
         avatarURL:(nullable NSString *)avatarURL
              name:(NSString *)name
           content:(nullable NSString *)content
             onTap:(nullable void(^)(void))onTap {
    [self dismissCurrent];

    CGFloat tabBarH = 49.0f;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = parentView.safeAreaInsets.bottom;
    }
    CGFloat centerX = parentView.bounds.size.width / 2.0f;
    CGFloat targetY = parentView.bounds.size.height - safeBottom - tabBarH - kHintHeight + 16.0f;
    CGFloat startY = parentView.bounds.size.height;

    WKPixelParticleHint *hint = [[WKPixelParticleHint alloc] initWithFrame:
        CGRectMake(centerX - kHintWidth / 2.0f, startY, kHintWidth, kHintHeight)];
    hint.tapAction = onTap;
    [parentView addSubview:hint];
    _currentHint = hint;

    [hint buildHUDWithAvatarURL:avatarURL name:name content:content];
    [hint animateSlideInToY:targetY];
}

+ (void)dismissCurrent {
    if (_currentHint) {
        [_currentHint.typewriterTimer invalidate];
        _currentHint.typewriterTimer = nil;
        [_currentHint.layer removeAllAnimations];
        for (CALayer *sub in _currentHint.hudCard.layer.sublayers.copy) {
            [sub removeAllAnimations];
        }
        [_currentHint removeFromSuperview];
        _currentHint = nil;
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

#pragma mark - Build HUD

- (void)buildHUDWithAvatarURL:(nullable NSString *)avatarURL name:(NSString *)name content:(nullable NSString *)content {
    UIColor *cyan = [UIColor colorWithRed:0.0 green:1.0 blue:0.92 alpha:1.0];
    UIColor *magenta = [UIColor colorWithRed:1.0 green:0.0 blue:0.6 alpha:1.0];
    UIColor *theme = [WKApp shared].config.themeColor;
    UIColor *cyanDim = [cyan colorWithAlphaComponent:0.25];

    // ========= 主卡片 =========
    _hudCard = [[UIView alloc] initWithFrame:self.bounds];
    _hudCard.backgroundColor = [UIColor colorWithRed:0.02 green:0.04 blue:0.1 alpha:0.94];
    _hudCard.layer.cornerRadius = 4.0f;
    _hudCard.layer.masksToBounds = YES;
    [self addSubview:_hudCard];

    // ========= 边框 — 青+紫渐变流动 =========
    CAShapeLayer *borderMask = [CAShapeLayer layer];
    borderMask.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:4.0f].CGPath;
    borderMask.fillColor = [UIColor clearColor].CGColor;
    borderMask.strokeColor = [UIColor whiteColor].CGColor;
    borderMask.lineWidth = 1.5f;

    _borderGradient = [CAGradientLayer layer];
    _borderGradient.frame = self.bounds;
    _borderGradient.colors = @[
        (id)[cyan colorWithAlphaComponent:0.9].CGColor,
        (id)[theme colorWithAlphaComponent:0.6].CGColor,
        (id)[magenta colorWithAlphaComponent:0.4].CGColor,
        (id)[cyan colorWithAlphaComponent:0.7].CGColor,
    ];
    _borderGradient.locations = @[@0, @0.4, @0.7, @1.0];
    _borderGradient.startPoint = CGPointMake(0, 0);
    _borderGradient.endPoint = CGPointMake(1, 1);
    _borderGradient.mask = borderMask;
    [_hudCard.layer addSublayer:_borderGradient];

    // ========= 外发光 — 双层 =========
    self.layer.shadowColor = cyan.CGColor;
    self.layer.shadowOpacity = 0.5;
    self.layer.shadowRadius = 15;
    self.layer.shadowOffset = CGSizeZero;

    // ========= 四角方括号装饰 =========
    _cornerBrackets = [CAShapeLayer layer];
    UIBezierPath *brackets = [UIBezierPath bezierPath];
    CGFloat bLen = 10.0f;
    CGFloat bInset = 2.0f;
    CGFloat W = kHintWidth, H = kHintHeight;
    // 左上
    [brackets moveToPoint:CGPointMake(bInset, bInset + bLen)];
    [brackets addLineToPoint:CGPointMake(bInset, bInset)];
    [brackets addLineToPoint:CGPointMake(bInset + bLen, bInset)];
    // 右上
    [brackets moveToPoint:CGPointMake(W - bInset - bLen, bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset, bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset, bInset + bLen)];
    // 右下
    [brackets moveToPoint:CGPointMake(W - bInset, H - bInset - bLen)];
    [brackets addLineToPoint:CGPointMake(W - bInset, H - bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset - bLen, H - bInset)];
    // 左下
    [brackets moveToPoint:CGPointMake(bInset + bLen, H - bInset)];
    [brackets addLineToPoint:CGPointMake(bInset, H - bInset)];
    [brackets addLineToPoint:CGPointMake(bInset, H - bInset - bLen)];

    _cornerBrackets.path = brackets.CGPath;
    _cornerBrackets.strokeColor = [cyan colorWithAlphaComponent:0.7].CGColor;
    _cornerBrackets.fillColor = [UIColor clearColor].CGColor;
    _cornerBrackets.lineWidth = 1.5f;
    _cornerBrackets.lineCap = kCALineCapSquare;
    [_hudCard.layer addSublayer:_cornerBrackets];

    // ========= 扫描线 =========
    _scanLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kHintWidth, 2)];
    CAGradientLayer *scanGrad = [CAGradientLayer layer];
    scanGrad.frame = _scanLine.bounds;
    scanGrad.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[cyan colorWithAlphaComponent:0.4].CGColor,
        (id)[cyan colorWithAlphaComponent:0.6].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    scanGrad.startPoint = CGPointMake(0, 0.5);
    scanGrad.endPoint = CGPointMake(1, 0.5);
    [_scanLine.layer addSublayer:scanGrad];
    [_hudCard addSubview:_scanLine];

    // ========= 横向细网格线（科幻感） =========
    for (NSInteger i = 1; i <= 3; i++) {
        CGFloat y = kHintHeight * i / 4.0f;
        UIView *gridLine = [[UIView alloc] initWithFrame:CGRectMake(8, y, kHintWidth - 16, 0.5)];
        gridLine.backgroundColor = [cyan colorWithAlphaComponent:0.06];
        [_hudCard addSubview:gridLine];
    }

    // ========= 左侧装饰条 — 紫→青 =========
    UIView *leftBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, kHintHeight)];
    CAGradientLayer *barGrad = [CAGradientLayer layer];
    barGrad.frame = leftBar.bounds;
    barGrad.colors = @[(id)magenta.CGColor, (id)theme.CGColor, (id)cyan.CGColor];
    barGrad.startPoint = CGPointMake(0.5, 0);
    barGrad.endPoint = CGPointMake(0.5, 1);
    [leftBar.layer addSublayer:barGrad];
    [_hudCard addSubview:leftBar];

    // ========= 顶部标签 "INCOMING" =========
    _tagLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHintWidth - 80, 5, 70, 10)];
    _tagLabel.font = [UIFont fontWithName:@"Menlo" size:7] ?: [UIFont systemFontOfSize:7 weight:UIFontWeightMedium];
    _tagLabel.textColor = [magenta colorWithAlphaComponent:0.7];
    _tagLabel.textAlignment = NSTextAlignmentRight;
    _tagLabel.text = @"⚡ INCOMING";
    [_hudCard addSubview:_tagLabel];

    // ========= 头像 =========
    CGFloat avatarX = 14.0f;
    CGFloat avatarY = (kHintHeight - kAvatarSize) / 2.0f;

    // 头像外框发光
    UIView *avatarGlow = [[UIView alloc] initWithFrame:CGRectMake(avatarX - 2, avatarY - 2, kAvatarSize + 4, kAvatarSize + 4)];
    avatarGlow.layer.cornerRadius = 4.0f;
    avatarGlow.layer.borderWidth = 1.0f;
    avatarGlow.layer.borderColor = cyanDim.CGColor;
    avatarGlow.backgroundColor = [UIColor clearColor];
    [_hudCard addSubview:avatarGlow];

    _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(avatarX, avatarY, kAvatarSize, kAvatarSize)];
    _avatarView.layer.cornerRadius = 4.0f;
    _avatarView.layer.masksToBounds = YES;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    [_hudCard addSubview:_avatarView];

    _initialLabel = [[UILabel alloc] initWithFrame:_avatarView.frame];
    _initialLabel.textAlignment = NSTextAlignmentCenter;
    _initialLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:20] ?: [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _initialLabel.textColor = cyan;
    _initialLabel.backgroundColor = [UIColor colorWithRed:0.02 green:0.1 blue:0.15 alpha:1.0];
    _initialLabel.layer.cornerRadius = 4.0f;
    _initialLabel.layer.masksToBounds = YES;
    _initialLabel.hidden = YES;
    [_hudCard addSubview:_initialLabel];

    if (avatarURL && avatarURL.length > 0) {
        [_avatarView sd_setImageWithURL:[NSURL URLWithString:avatarURL]
                       placeholderImage:nil
                              completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            if (!image) {
                self.avatarView.hidden = YES;
                self.initialLabel.hidden = NO;
                self.initialLabel.text = name.length > 0 ? [name substringToIndex:1] : @"#";
            }
        }];
    } else {
        _avatarView.hidden = YES;
        _initialLabel.hidden = NO;
        _initialLabel.text = name.length > 0 ? [name substringToIndex:1] : @"#";
    }

    // ========= 文字 =========
    CGFloat textLeft = avatarX + kAvatarSize + 12.0f;
    CGFloat textWidth = kHintWidth - textLeft - 16.0f;

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 12.0f, textWidth, 16)];
    _nameLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    _nameLabel.textColor = [UIColor whiteColor];
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    NSString *displayName = name.length > 14 ? [NSString stringWithFormat:@"%@…", [name substringToIndex:14]] : name;
    _nameLabel.text = [NSString stringWithFormat:@"▸ %@", displayName];
    _nameLabel.alpha = 0;
    [_hudCard addSubview:_nameLabel];

    _contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 30.0f, textWidth, 16)];
    _contentLabel.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    _contentLabel.textColor = [cyan colorWithAlphaComponent:0.75];
    _contentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _contentLabel.text = @"";
    [_hudCard addSubview:_contentLabel];

    if (content && content.length > 0) {
        NSString *truncated = content.length > 22 ? [NSString stringWithFormat:@"%@…", [content substringToIndex:22]] : content;
        _fullContentText = truncated;
    } else {
        _fullContentText = @"";
    }
    _typewriterIndex = 0;

    // ========= 右下角三角 — 品红 =========
    UIView *cornerMark = [[UIView alloc] initWithFrame:CGRectMake(kHintWidth - 18, kHintHeight - 18, 14, 14)];
    CAShapeLayer *tri = [CAShapeLayer layer];
    UIBezierPath *triPath = [UIBezierPath bezierPath];
    [triPath moveToPoint:CGPointMake(14, 0)];
    [triPath addLineToPoint:CGPointMake(14, 14)];
    [triPath addLineToPoint:CGPointMake(0, 14)];
    [triPath closePath];
    tri.path = triPath.CGPath;
    tri.fillColor = [magenta colorWithAlphaComponent:0.25].CGColor;
    [cornerMark.layer addSublayer:tri];
    [_hudCard addSubview:cornerMark];

}

#pragma mark - Animations

- (void)animateSlideInToY:(CGFloat)targetY {
    self.alpha = 0;

    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        CGRect f = self.frame;
        f.origin.y = targetY;
        self.frame = f;
        self.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self startScanLineAnimation];
        [self animateNameReveal];
    }];
}

- (void)startScanLineAnimation {
    _scanLine.frame = CGRectMake(0, -2, kHintWidth, 2);
    [UIView animateWithDuration:2.0 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveLinear animations:^{
        self.scanLine.frame = CGRectMake(0, kHintHeight + 2, kHintWidth, 2);
    } completion:nil];

    // 边框渐变流动
    UIColor *cyan = [UIColor colorWithRed:0.0 green:1.0 blue:0.92 alpha:1.0];
    UIColor *magenta = [UIColor colorWithRed:1.0 green:0.0 blue:0.6 alpha:1.0];
    UIColor *theme = [WKApp shared].config.themeColor;
    CABasicAnimation *gradAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
    gradAnim.toValue = @[
        (id)[magenta colorWithAlphaComponent:0.5].CGColor,
        (id)[cyan colorWithAlphaComponent:0.8].CGColor,
        (id)[theme colorWithAlphaComponent:0.7].CGColor,
        (id)[magenta colorWithAlphaComponent:0.3].CGColor,
    ];
    gradAnim.duration = 3.0;
    gradAnim.autoreverses = YES;
    gradAnim.repeatCount = HUGE_VALF;
    [_borderGradient addAnimation:gradAnim forKey:@"borderFlow"];

    // 四角方括号呼吸
    CABasicAnimation *bracketPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    bracketPulse.fromValue = @(0.7);
    bracketPulse.toValue = @(1.0);
    bracketPulse.duration = 1.5;
    bracketPulse.autoreverses = YES;
    bracketPulse.repeatCount = HUGE_VALF;
    [_cornerBrackets addAnimation:bracketPulse forKey:@"pulse"];
}

- (void)animateNameReveal {
    [UIView animateWithDuration:0.15 animations:^{
        self.nameLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self startTypewriterEffect];
    }];
}

- (void)startTypewriterEffect {
    if (_fullContentText.length == 0) {
        [self scheduleSlideOut];
        return;
    }
    _typewriterIndex = 0;
    _typewriterTimer = [NSTimer scheduledTimerWithTimeInterval:0.04
                                                       target:self
                                                     selector:@selector(typewriterTick)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)typewriterTick {
    if (_typewriterIndex >= (NSInteger)_fullContentText.length) {
        [_typewriterTimer invalidate];
        _typewriterTimer = nil;
        _contentLabel.text = [NSString stringWithFormat:@"%@▌", _fullContentText];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.contentLabel.text = self.fullContentText;
        });
        [self scheduleSlideOut];
        return;
    }
    _typewriterIndex++;
    NSString *visible = [_fullContentText substringToIndex:_typewriterIndex];
    _contentLabel.text = [NSString stringWithFormat:@"%@▌", visible];
}

- (void)scheduleSlideOut {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_currentHint != self) return;
        [self animateSlideOut];
    });
}

- (void)animateSlideOut {
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        CGRect f = self.frame;
        f.origin.y += 60;
        self.frame = f;
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (_currentHint == self) _currentHint = nil;
    }];
}

#pragma mark - Tap

- (void)onTap {
    if (self.tapAction) {
        self.tapAction();
    }
    [WKPixelParticleHint dismissCurrent];
}

- (void)dealloc {
    [_typewriterTimer invalidate];
}

@end
