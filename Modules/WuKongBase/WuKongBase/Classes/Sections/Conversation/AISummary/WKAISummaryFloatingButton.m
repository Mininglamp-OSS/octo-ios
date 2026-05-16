//
//  WKAISummaryFloatingButton.m
//  WuKongBase
//
//  AI 一键总结按钮 — Data Vortex 设计。
//
//  视觉构成：
//    - 52pt 圆形玻璃底
//    - 2pt 锥形渐变环（purple→cyan→magenta→purple）旋转 8s
//    - 中心白色 4 角星 ✦
//    - 紫色 halo（呼吸 2s）
//
//  注意：装饰粒子已下线 —— 真正"涌入按钮"的视觉由 WKAITextIngestor 通过抓取
//  群里可见消息片段、从 cell 飞向按钮中心来呈现，那是"信息汇聚 = 总结"的真隐喻。
//

#import "WKAISummaryFloatingButton.h"

static const CGFloat kButtonSize       = 44.0;
static const CGFloat kRimWidth         = 1.8;
static const CGFloat kHaloRadius       = 12.0;
static const CGFloat kSparkleR1        = 8.2;
static const CGFloat kSparkleR2        = 2.5;

#pragma mark - Color helpers

static UIColor *Hex(uint32_t hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8)  & 0xFF) / 255.0
                            blue:( hex        & 0xFF) / 255.0
                           alpha:alpha];
}
static UIColor *Lerp(UIColor *a, UIColor *b, CGFloat t) {
    CGFloat ar,ag,ab,aa, br,bg,bb,ba;
    [a getRed:&ar green:&ag blue:&ab alpha:&aa];
    [b getRed:&br green:&bg blue:&bb alpha:&ba];
    return [UIColor colorWithRed:ar+(br-ar)*t green:ag+(bg-ag)*t blue:ab+(bb-ab)*t alpha:aa+(ba-aa)*t];
}
static UIColor *Purple(void)  { return Hex(0x9D5CFF, 1.0); }
static UIColor *Cyan(void)    { return Hex(0x00E0FF, 1.0); }
static UIColor *Magenta(void) { return Hex(0xFF4DA1, 1.0); }
static UIColor *Glass(void)   { return Hex(0x1A1F3A, 0.95); }

#pragma mark -

@interface WKAISummaryFloatingButton ()
@property(nonatomic, strong) CALayer        *fillLayer;
@property(nonatomic, strong) CALayer        *rimLayer;       // 锥形渐变环（旋转）
@property(nonatomic, strong) CAShapeLayer   *sparkleLayer;
@end

@implementation WKAISummaryFloatingButton

#pragma mark - Init

- (instancetype)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, kButtonSize, kButtonSize);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        [self buildLayers];
        [self startIdleAnimations];
        // 进入前台时重启 idle 动画 —— 避免 iOS 在 backgrounding 时移除 inf 动画
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidBecomeActive {
    if (self.window) [self startIdleAnimations];
}

// push 转场后回来 / 重新挂回 hierarchy 都会走这里，是 idle 动画"复活"最稳的钩子
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self startIdleAnimations];
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview && self.window) [self startIdleAnimations];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(kButtonSize, kButtonSize);
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    self.fillLayer.frame      = self.bounds;
    self.rimLayer.frame       = self.bounds;
    self.sparkleLayer.frame   = self.bounds;
    if ([self.rimLayer.mask isKindOfClass:CAShapeLayer.class]) {
        ((CAShapeLayer *)self.rimLayer.mask).frame = self.bounds;
    }
    self.fillLayer.cornerRadius = self.bounds.size.width / 2.0;
    self.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;
}

#pragma mark - Build

- (void)buildLayers {
    self.layer.shadowColor   = Purple().CGColor;
    self.layer.shadowOffset  = CGSizeZero;
    self.layer.shadowRadius  = kHaloRadius;
    self.layer.shadowOpacity = 0.65;
    self.layer.masksToBounds = NO;

    self.fillLayer = [CALayer layer];
    self.fillLayer.backgroundColor = Glass().CGColor;
    [self.layer addSublayer:self.fillLayer];

    self.rimLayer = [CALayer layer];
    self.rimLayer.contents = (__bridge id)[self conicGradientImage].CGImage;
    self.rimLayer.contentsGravity = kCAGravityResizeAspectFill;
    self.rimLayer.mask = [self ringMaskLayer];
    [self.layer addSublayer:self.rimLayer];

    self.sparkleLayer = [CAShapeLayer layer];
    self.sparkleLayer.path = [self sparklePathForSize:CGSizeMake(kButtonSize, kButtonSize)].CGPath;
    self.sparkleLayer.fillColor = UIColor.whiteColor.CGColor;
    self.sparkleLayer.shadowColor = UIColor.whiteColor.CGColor;
    self.sparkleLayer.shadowRadius = 4;
    self.sparkleLayer.shadowOpacity = 0.6;
    self.sparkleLayer.shadowOffset = CGSizeZero;
    [self.layer addSublayer:self.sparkleLayer];
}

- (UIImage *)conicGradientImage {
    CGSize size = CGSizeMake(kButtonSize * 2, kButtonSize * 2);
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGPoint center = CGPointMake(size.width/2, size.height/2);
    CGFloat radius = size.width/2;
    NSInteger sectors = 360;
    UIColor *purple = Purple(), *cyan = Cyan(), *mag = Magenta();
    for (NSInteger i = 0; i < sectors; i++) {
        CGFloat startA = (i - 0.5) * (2 * M_PI / sectors) - M_PI_2;
        CGFloat endA   = (i + 0.5) * (2 * M_PI / sectors) - M_PI_2;
        CGFloat t = i / (CGFloat)sectors;
        UIColor *c;
        if      (t < 1.0/3.0) c = Lerp(purple, cyan,   t / (1.0/3.0));
        else if (t < 2.0/3.0) c = Lerp(cyan,   mag,    (t - 1.0/3.0) / (1.0/3.0));
        else                  c = Lerp(mag,    purple, (t - 2.0/3.0) / (1.0/3.0));
        CGContextSetFillColorWithColor(ctx, c.CGColor);
        CGContextMoveToPoint(ctx, center.x, center.y);
        CGContextAddArc(ctx, center.x, center.y, radius, startA, endA, NO);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (CAShapeLayer *)ringMaskLayer {
    CAShapeLayer *m = [CAShapeLayer layer];
    UIBezierPath *outer = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,kButtonSize,kButtonSize)];
    UIBezierPath *inner = [UIBezierPath bezierPathWithOvalInRect:
                           CGRectInset(CGRectMake(0,0,kButtonSize,kButtonSize), kRimWidth, kRimWidth)];
    [outer appendPath:inner];
    m.path = outer.CGPath;
    m.fillRule = kCAFillRuleEvenOdd;
    m.fillColor = UIColor.blackColor.CGColor;
    return m;
}

- (UIBezierPath *)sparklePathForSize:(CGSize)size {
    CGFloat cx = size.width / 2.0, cy = size.height / 2.0;
    UIBezierPath *p = [UIBezierPath bezierPath];
    NSInteger spikes = 4, points = spikes * 2;
    for (NSInteger i = 0; i < points; i++) {
        CGFloat angle = -M_PI_2 + i * (M_PI / spikes);
        CGFloat r = (i % 2 == 0) ? kSparkleR1 : kSparkleR2;
        CGPoint pt = CGPointMake(cx + r * cos(angle), cy + r * sin(angle));
        if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
    }
    [p closePath];
    return p;
}

#pragma mark - Idle 动画

- (void)startIdleAnimations {
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    // 锥形渐变环：5s 一圈（idle）/ 2.5s（active）
    [self.rimLayer removeAnimationForKey:@"rotate"];
    CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rot.fromValue = @(0.0);
    rot.toValue   = @(2 * M_PI);
    rot.duration  = self.active ? 2.5 : 5.0;
    rot.repeatCount = HUGE_VALF;
    rot.removedOnCompletion = NO;
    [self.rimLayer addAnimation:rot forKey:@"rotate"];

    // halo 呼吸
    [self.layer removeAnimationForKey:@"halo"];
    CABasicAnimation *halo = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    halo.fromValue = @(0.45);
    halo.toValue   = @(0.85);
    halo.duration  = self.active ? 1.0 : 2.0;
    halo.autoreverses = YES;
    halo.repeatCount  = HUGE_VALF;
    halo.removedOnCompletion = NO;
    halo.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.layer addAnimation:halo forKey:@"halo"];

    // 中心 ✦ 呼吸：scale + shadow 同步律动；幅度加大让"心跳"明显
    [self.sparkleLayer removeAnimationForKey:@"sparkleScale"];
    CABasicAnimation *spScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    spScale.fromValue = @(0.78);
    spScale.toValue   = @(1.32);
    spScale.duration  = self.active ? 0.7 : 1.4;
    spScale.autoreverses = YES;
    spScale.repeatCount  = HUGE_VALF;
    spScale.removedOnCompletion = NO;
    spScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.sparkleLayer addAnimation:spScale forKey:@"sparkleScale"];

    [self.sparkleLayer removeAnimationForKey:@"sparkleGlow"];
    CABasicAnimation *spGlow = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    spGlow.fromValue = @(2.5);
    spGlow.toValue   = @(9.0);
    spGlow.duration  = self.active ? 0.7 : 1.4;
    spGlow.autoreverses = YES;
    spGlow.repeatCount  = HUGE_VALF;
    spGlow.removedOnCompletion = NO;
    spGlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.sparkleLayer addAnimation:spGlow forKey:@"sparkleGlow"];
}

- (void)setActive:(BOOL)active {
    if (_active == active) return;
    _active = active;
    [self startIdleAnimations];
}

#pragma mark - 入场

- (void)playEntranceAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.alpha = 1.0;
        return;
    }
    self.alpha = 0;
    self.transform = CGAffineTransformMakeTranslation(self.bounds.size.width, 0);
    [UIView animateWithDuration:0.40
                          delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    CABasicAnimation *flash = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    flash.fromValue = @(1.0);
    flash.toValue = @(0.65);
    flash.duration = 0.35;
    [self.layer addAnimation:flash forKey:@"flash"];
}

#pragma mark - 点击反馈

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.10 animations:^{
        self.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }];
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.08 animations:^{
        self.transform = CGAffineTransformMakeScale(1.04, 1.04);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.06 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
    [self playGlitchOnce];
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.10 animations:^{ self.transform = CGAffineTransformIdentity; }];
    [super cancelTrackingWithEvent:event];
}

#pragma mark - 点击反馈（轻量 — 仅 sparkle 微闪）

- (void)playGlitchOnce {
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    // sparkle 闪一下：白色阴影瞬间放大
    CAKeyframeAnimation *flash = [CAKeyframeAnimation animationWithKeyPath:@"shadowRadius"];
    flash.values = @[@2.5, @9.0, @2.5];
    flash.keyTimes = @[@0, @0.3, @1.0];
    flash.duration = 0.35;
    [self.sparkleLayer addAnimation:flash forKey:@"sparkleFlash"];
}

#pragma mark - 充能（点击主反馈）

- (void)playChargeUp {
    if (UIAccessibilityIsReduceMotionEnabled()) return;

    NSTimeInterval D = 0.85;

    // 中心 ✦ 大幅膨胀（先狠冲到 2.6 倍，再回落） — 配合外部气泡吸入营造"充能"感
    CAKeyframeAnimation *spScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    spScale.values   = @[@1.0, @1.6, @2.6, @0.9, @1.0];
    spScale.keyTimes = @[@0.0, @0.45, @0.65, @0.85, @1.0];
    spScale.duration = D;
    spScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.sparkleLayer addAnimation:spScale forKey:@"chargeScale"];

    CAKeyframeAnimation *spGlow = [CAKeyframeAnimation animationWithKeyPath:@"shadowRadius"];
    spGlow.values   = @[@4, @12, @22, @8, @4];
    spGlow.keyTimes = @[@0.0, @0.45, @0.65, @0.85, @1.0];
    spGlow.duration = D;
    [self.sparkleLayer addAnimation:spGlow forKey:@"chargeGlow"];

    // halo 爆光（透明度 + 半径同步放大）
    CAKeyframeAnimation *haloOp = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
    haloOp.values   = @[@0.65, @1.0, @1.0, @0.65];
    haloOp.keyTimes = @[@0.0, @0.5, @0.7, @1.0];
    haloOp.duration = D;
    [self.layer addAnimation:haloOp forKey:@"chargeHaloOp"];

    CAKeyframeAnimation *haloR = [CAKeyframeAnimation animationWithKeyPath:@"shadowRadius"];
    haloR.values   = @[@(kHaloRadius), @(kHaloRadius + 12), @(kHaloRadius)];
    haloR.keyTimes = @[@0.0, @0.55, @1.0];
    haloR.duration = D;
    [self.layer addAnimation:haloR forKey:@"chargeHaloR"];

    // 充能末段做一次轻微"震荡"反馈（haptic）
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen prepare];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(D * 0.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [gen impactOccurred];
    });

    // 充能结束后 idle 动画自然接管（没主动 remove，原 idle 动画在底层继续重复）
}

@end
