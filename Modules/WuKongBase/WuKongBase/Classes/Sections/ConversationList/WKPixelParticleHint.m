//
//  WKPixelParticleHint.m
//  WuKongBase
//
//  Cyberpunk HUD — 复用单例 + RunLoop兼容

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
@property (nonatomic, strong) NSTimer *dismissTimer;
@property (nonatomic, copy) NSString *fullContentText;
@property (nonatomic, assign) NSInteger typewriterIndex;
@property (nonatomic, assign) BOOL hudBuilt;
@property (nonatomic, copy, nullable) void(^tapAction)(void);
@end

static WKPixelParticleHint *_sharedHint = nil;

@implementation WKPixelParticleHint

#pragma mark - Singleton & Show

+ (WKPixelParticleHint *)sharedHint {
    if (!_sharedHint) {
        _sharedHint = [[WKPixelParticleHint alloc] initWithFrame:CGRectMake(0, 0, kHintWidth, kHintHeight)];
    }
    return _sharedHint;
}

+ (void)showInView:(UIView *)parentView
         avatarURL:(nullable NSString *)avatarURL
              name:(NSString *)name
           content:(nullable NSString *)content
             onTap:(nullable void(^)(void))onTap {

    WKPixelParticleHint *hint = [self sharedHint];
    [hint cancelTimers];

    CGFloat tabBarH = 49.0f;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = parentView.safeAreaInsets.bottom;
    }
    CGFloat centerX = parentView.bounds.size.width / 2.0f;
    CGFloat targetY = parentView.bounds.size.height - safeBottom - tabBarH - kHintHeight + 16.0f;
    CGFloat startY = parentView.bounds.size.height;

    hint.tapAction = onTap;

    if (!hint.hudBuilt) {
        [hint buildHUD];
    }

    [hint updateContentWithAvatarURL:avatarURL name:name content:content];

    if (hint.superview != parentView) {
        [hint removeFromSuperview];
        hint.frame = CGRectMake(centerX - kHintWidth / 2.0f, startY, kHintWidth, kHintHeight);
        [parentView addSubview:hint];
        [hint animateSlideInToY:targetY];
    } else {
        // 已在同一父视图，直接更新位置并重新播放内容动画
        hint.alpha = 1.0;
        CGRect f = hint.frame;
        f.origin.y = targetY;
        hint.frame = f;
        [hint animateContentReveal];
    }
}

+ (void)dismissCurrent {
    WKPixelParticleHint *hint = _sharedHint;
    if (!hint || !hint.superview) return;
    [hint cancelTimers];
    [hint stopRepeatingAnimations];
    [hint removeFromSuperview];
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

- (void)cancelTimers {
    [_typewriterTimer invalidate];
    _typewriterTimer = nil;
    [_dismissTimer invalidate];
    _dismissTimer = nil;
}

- (void)stopRepeatingAnimations {
    [_scanLine.layer removeAllAnimations];
    [_borderGradient removeAllAnimations];
    [_cornerBrackets removeAllAnimations];
}

#pragma mark - Build HUD (once)

- (void)buildHUD {
    UIColor *cyan = [UIColor colorWithRed:0.0 green:1.0 blue:0.92 alpha:1.0];
    UIColor *magenta = [UIColor colorWithRed:1.0 green:0.0 blue:0.6 alpha:1.0];
    UIColor *theme = [WKApp shared].config.themeColor;
    UIColor *cyanDim = [cyan colorWithAlphaComponent:0.25];

    // 主卡片
    _hudCard = [[UIView alloc] initWithFrame:self.bounds];
    _hudCard.backgroundColor = [UIColor colorWithRed:0.02 green:0.04 blue:0.1 alpha:0.94];
    _hudCard.layer.cornerRadius = 4.0f;
    _hudCard.layer.masksToBounds = YES;
    [self addSubview:_hudCard];

    // 边框
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

    // 外发光 — 用 shadowPath 优化性能
    self.layer.shadowColor = cyan.CGColor;
    self.layer.shadowOpacity = 0.5;
    self.layer.shadowRadius = 15;
    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:4.0f].CGPath;

    // 四角方括号
    _cornerBrackets = [CAShapeLayer layer];
    UIBezierPath *brackets = [UIBezierPath bezierPath];
    CGFloat bLen = 10.0f, bInset = 2.0f;
    CGFloat W = kHintWidth, H = kHintHeight;
    [brackets moveToPoint:CGPointMake(bInset, bInset + bLen)];
    [brackets addLineToPoint:CGPointMake(bInset, bInset)];
    [brackets addLineToPoint:CGPointMake(bInset + bLen, bInset)];
    [brackets moveToPoint:CGPointMake(W - bInset - bLen, bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset, bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset, bInset + bLen)];
    [brackets moveToPoint:CGPointMake(W - bInset, H - bInset - bLen)];
    [brackets addLineToPoint:CGPointMake(W - bInset, H - bInset)];
    [brackets addLineToPoint:CGPointMake(W - bInset - bLen, H - bInset)];
    [brackets moveToPoint:CGPointMake(bInset + bLen, H - bInset)];
    [brackets addLineToPoint:CGPointMake(bInset, H - bInset)];
    [brackets addLineToPoint:CGPointMake(bInset, H - bInset - bLen)];
    _cornerBrackets.path = brackets.CGPath;
    _cornerBrackets.strokeColor = [cyan colorWithAlphaComponent:0.7].CGColor;
    _cornerBrackets.fillColor = [UIColor clearColor].CGColor;
    _cornerBrackets.lineWidth = 1.5f;
    _cornerBrackets.lineCap = kCALineCapSquare;
    [_hudCard.layer addSublayer:_cornerBrackets];

    // 扫描线
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

    // 网格线（静态，只创建一次）
    for (NSInteger i = 1; i <= 3; i++) {
        CGFloat y = kHintHeight * i / 4.0f;
        UIView *gridLine = [[UIView alloc] initWithFrame:CGRectMake(8, y, kHintWidth - 16, 0.5)];
        gridLine.backgroundColor = [cyan colorWithAlphaComponent:0.06];
        [_hudCard addSubview:gridLine];
    }

    // 左侧装饰条
    UIView *leftBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, kHintHeight)];
    CAGradientLayer *barGrad = [CAGradientLayer layer];
    barGrad.frame = leftBar.bounds;
    barGrad.colors = @[(id)magenta.CGColor, (id)theme.CGColor, (id)cyan.CGColor];
    barGrad.startPoint = CGPointMake(0.5, 0);
    barGrad.endPoint = CGPointMake(0.5, 1);
    [leftBar.layer addSublayer:barGrad];
    [_hudCard addSubview:leftBar];

    // 顶部标签
    _tagLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHintWidth - 80, 5, 70, 10)];
    _tagLabel.font = [UIFont fontWithName:@"Menlo" size:7] ?: [UIFont systemFontOfSize:7 weight:UIFontWeightMedium];
    _tagLabel.textColor = [magenta colorWithAlphaComponent:0.7];
    _tagLabel.textAlignment = NSTextAlignmentRight;
    _tagLabel.text = @"⚡ INCOMING";
    [_hudCard addSubview:_tagLabel];

    // 头像外框
    CGFloat avatarX = 14.0f;
    CGFloat avatarY = (kHintHeight - kAvatarSize) / 2.0f;

    UIView *avatarGlow = [[UIView alloc] initWithFrame:CGRectMake(avatarX - 2, avatarY - 2, kAvatarSize + 4, kAvatarSize + 4)];
    avatarGlow.layer.cornerRadius = 4.0f;
    avatarGlow.layer.borderWidth = 1.0f;
    avatarGlow.layer.borderColor = cyanDim.CGColor;
    [_hudCard addSubview:avatarGlow];

    // 头像
    _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(avatarX, avatarY, kAvatarSize, kAvatarSize)];
    _avatarView.layer.cornerRadius = 4.0f;
    _avatarView.layer.masksToBounds = YES;
    _avatarView.contentMode = UIViewContentModeScaleAspectFill;
    [_hudCard addSubview:_avatarView];

    // 首字备选
    _initialLabel = [[UILabel alloc] initWithFrame:_avatarView.frame];
    _initialLabel.textAlignment = NSTextAlignmentCenter;
    _initialLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:20] ?: [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _initialLabel.textColor = cyan;
    _initialLabel.backgroundColor = [UIColor colorWithRed:0.02 green:0.1 blue:0.15 alpha:1.0];
    _initialLabel.layer.cornerRadius = 4.0f;
    _initialLabel.layer.masksToBounds = YES;
    _initialLabel.hidden = YES;
    [_hudCard addSubview:_initialLabel];

    // 名称
    CGFloat textLeft = avatarX + kAvatarSize + 12.0f;
    CGFloat textWidth = kHintWidth - textLeft - 16.0f;

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 12.0f, textWidth, 16)];
    _nameLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11] ?: [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    _nameLabel.textColor = [UIColor whiteColor];
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_hudCard addSubview:_nameLabel];

    // 消息内容
    _contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 30.0f, textWidth, 16)];
    _contentLabel.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    _contentLabel.textColor = [cyan colorWithAlphaComponent:0.75];
    _contentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_hudCard addSubview:_contentLabel];

    // 右下角三角
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

    // 栅格化整个卡片提升渲染性能
    _hudCard.layer.shouldRasterize = YES;
    _hudCard.layer.rasterizationScale = [UIScreen mainScreen].scale;

    _hudBuilt = YES;
}

#pragma mark - Update Content (reuse)

- (void)updateContentWithAvatarURL:(nullable NSString *)avatarURL name:(NSString *)name content:(nullable NSString *)content {
    // 更新内容时临时关闭栅格化（内容在变）
    _hudCard.layer.shouldRasterize = NO;

    // 头像
    _avatarView.image = nil;
    _avatarView.hidden = NO;
    _initialLabel.hidden = YES;

    if (avatarURL && avatarURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        [_avatarView sd_setImageWithURL:[NSURL URLWithString:avatarURL]
                       placeholderImage:nil
                              completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            if (!image) {
                weakSelf.avatarView.hidden = YES;
                weakSelf.initialLabel.hidden = NO;
                weakSelf.initialLabel.text = name.length > 0 ? [name substringToIndex:1] : @"#";
            }
        }];
    } else {
        _avatarView.hidden = YES;
        _initialLabel.hidden = NO;
        _initialLabel.text = name.length > 0 ? [name substringToIndex:1] : @"#";
    }

    // 名称
    NSString *displayName = name.length > 14 ? [NSString stringWithFormat:@"%@…", [name substringToIndex:14]] : name;
    _nameLabel.text = [NSString stringWithFormat:@"▸ %@", displayName];
    _nameLabel.alpha = 0;

    // 消息内容
    _contentLabel.text = @"";
    if (content && content.length > 0) {
        _fullContentText = content.length > 22 ? [NSString stringWithFormat:@"%@…", [content substringToIndex:22]] : content;
    } else {
        _fullContentText = @"";
    }
    _typewriterIndex = 0;
}

#pragma mark - Animations

- (void)animateSlideInToY:(CGFloat)targetY {
    self.alpha = 0;

    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.75
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        CGRect f = self.frame;
        f.origin.y = targetY;
        self.frame = f;
        self.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self startRepeatingAnimations];
        [self animateContentReveal];
    }];
}

- (void)startRepeatingAnimations {
    // 扫描线 — 用 CADisplayLink 驱动的 CABasicAnimation 不受 RunLoop 模式影响
    _scanLine.frame = CGRectMake(0, -2, kHintWidth, 2);

    CABasicAnimation *scanAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    scanAnim.fromValue = @(-2);
    scanAnim.toValue = @(kHintHeight + 2);
    scanAnim.duration = 2.0;
    scanAnim.repeatCount = HUGE_VALF;
    [_scanLine.layer addAnimation:scanAnim forKey:@"scan"];

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

- (void)animateContentReveal {
    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.nameLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self startTypewriterEffect];
    }];
}

- (void)startTypewriterEffect {
    if (_fullContentText.length == 0) {
        [self scheduleDismiss];
        return;
    }
    _typewriterIndex = 0;
    _typewriterTimer = [NSTimer timerWithTimeInterval:0.04
                                              target:self
                                            selector:@selector(typewriterTick)
                                            userInfo:nil
                                             repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_typewriterTimer forMode:NSRunLoopCommonModes];
}

- (void)typewriterTick {
    if (_typewriterIndex >= (NSInteger)_fullContentText.length) {
        [_typewriterTimer invalidate];
        _typewriterTimer = nil;
        _contentLabel.text = [NSString stringWithFormat:@"%@▌", _fullContentText];

        // 用 CommonModes timer 代替 dispatch_after
        NSTimer *cursorTimer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(removeCursor) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:cursorTimer forMode:NSRunLoopCommonModes];

        [self scheduleDismiss];

        // 打字完成，重新启用栅格化
        _hudCard.layer.shouldRasterize = YES;
        return;
    }
    _typewriterIndex++;
    NSString *visible = [_fullContentText substringToIndex:_typewriterIndex];
    _contentLabel.text = [NSString stringWithFormat:@"%@▌", visible];
}

- (void)removeCursor {
    if (_fullContentText) {
        _contentLabel.text = _fullContentText;
    }
}

- (void)scheduleDismiss {
    [_dismissTimer invalidate];
    _dismissTimer = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(dismissTimerFired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_dismissTimer forMode:NSRunLoopCommonModes];
}

- (void)dismissTimerFired {
    _dismissTimer = nil;
    [self animateSlideOut];
}

- (void)animateSlideOut {
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        CGRect f = self.frame;
        f.origin.y += 60;
        self.frame = f;
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self stopRepeatingAnimations];
        [self removeFromSuperview];
    }];
}

#pragma mark - Tap

- (void)onTap {
    [self cancelTimers];
    if (self.tapAction) {
        self.tapAction();
    }
    [self stopRepeatingAnimations];
    [self removeFromSuperview];
}

- (void)dealloc {
    [_typewriterTimer invalidate];
    [_dismissTimer invalidate];
}

@end
