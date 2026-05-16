// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKClassyEffect.m
//  WuKongBase
//
//  [有品位] 特效（v11 · 手臂和点赞一体化）
//
//  v10 问题解决：
//    1. z-order：hole mask 从"整个 sourceRect"缩小成"图片 rect 估算"（sourceRect 小 inset
//       ~6pt）。手臂在气泡 padding 那圈（bubble 和 image 之间）可见，叠在气泡背景上，被图片
//       盖住；正好 `bubble_frame < arm < emoji_image` 的 z 序。
//    2. 手臂和点赞连成一体：点赞形状在底部加了**腕部 stem**（从 palm 底部往下收窄的短柱，
//       延伸到 handNode 边界）。`armEnd` 落在 stem 中心，arm 最后一小段直接钻进 stem 内部；
//       因为 arm 和 hand 用同一个金黄色 #FFD500 填充，两者无缝衔接，看起来就是一条连续的
//       "手臂长成手"。
//    3. arm 末端 tangent 改成近乎竖直（armControl2 调到 armEnd 正下方附近），hand 直立无
//       需旋转就能自然对齐。
//    4. 点赞轮廓按你给的图重绘：高挑拇指（顶端微前倾）+ palm 右侧 4 段 knuckle + 腕部 stem。
//

#import "WKClassyEffect.h"
#import "WKMessageEffectView.h"
#import "WuKongBase.h"

@implementation WKClassyEffect

#pragma mark - Entry

+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
          fromSelf:(BOOL)fromSelf {

    if (effectView.superview == nil || CGRectIsEmpty(sourceRect)) {
        [effectView scheduleRemovalAfterDelay:0.05];
        return;
    }

    // 单一金色（arm 和 hand 同色才能视觉连成一体）
    UIColor *yellowBase   = [UIColor colorWithRed:1.00 green:0.835 blue:0.00 alpha:1.0];  // #FFD500
    UIColor *yellowDark   = [UIColor colorWithRed:0.85 green:0.65 blue:0.00 alpha:1.0];
    UIColor *yellowShadow = [UIColor colorWithRed:0.55 green:0.38 blue:0.00 alpha:1.0];
    UIColor *yellowLight  = [UIColor colorWithRed:1.00 green:0.92 blue:0.45 alpha:1.0];

    CGFloat sign = fromSelf ? -1.0 : 1.0;

    CGFloat w = sourceRect.size.width;
    CGFloat h = sourceRect.size.height;
    CGFloat midX = CGRectGetMidX(sourceRect);
    CGFloat maxY = CGRectGetMaxY(sourceRect);
    CGFloat avgSize = (w + h) / 2.0;

    // 手臂几何：armControl2 放在 armEnd 正下方附近，让末端 tangent 接近竖直，好和 hand 对齐
    CGPoint armStart   = CGPointMake(midX + sign * w * 0.25, maxY - h * 0.28);
    CGPoint armControl1= CGPointMake(midX + sign * w * 0.85, maxY + h * 0.52);
    CGPoint armControl2= CGPointMake(midX + sign * w * 0.92, maxY + h * 0.05);
    CGPoint armEnd     = CGPointMake(midX + sign * w * 0.90, maxY - h * 0.30);

    CGFloat armWidth = MIN(avgSize * 0.09, 11.0);
    CGFloat handSize = MIN(avgSize * 0.62, 140.0);

    UIBezierPath *centerline = [UIBezierPath bezierPath];
    [centerline moveToPoint:armStart];
    [centerline addCurveToPoint:armEnd controlPoint1:armControl1 controlPoint2:armControl2];

    // ===== armContainer + hole mask：图片 rect 估算 =====
    //   sourceRect 是整个气泡；图片在气泡中占绝大部分（tag-only 文本的气泡 padding 很小）。
    //   取 inset ~6pt 的 rect 近似图片区域；这块挖空，arm 在其中被真实图片遮住；气泡边缘那
    //   一圈薄薄的 padding 区域 arm 可见，叠在气泡背景上——正好是 `bubble_frame < arm < image`。
    UIView *armContainer = [[UIView alloc] initWithFrame:effectView.bounds];
    armContainer.userInteractionEnabled = NO;

    CAShapeLayer *holeMask = [CAShapeLayer layer];
    UIBezierPath *holePath = [UIBezierPath bezierPathWithRect:effectView.bounds];
    CGFloat inset = MIN(6.0, MIN(w, h) * 0.08);
    CGRect imageRectEstimate = CGRectInset(sourceRect, inset, inset);
    [holePath appendPath:[UIBezierPath bezierPathWithRect:imageRectEstimate]];
    holePath.usesEvenOddFillRule = YES;
    holeMask.path = holePath.CGPath;
    holeMask.fillRule = kCAFillRuleEvenOdd;
    holeMask.fillColor = UIColor.blackColor.CGColor;
    armContainer.layer.mask = holeMask;
    [effectView addSubview:armContainer];

    // arm layers
    CGPathRef armFillPath = CGPathCreateCopyByStrokingPath(centerline.CGPath,
                                                           NULL,
                                                           armWidth,
                                                           kCGLineCapRound,
                                                           kCGLineJoinRound,
                                                           1.0);
    CAShapeLayer *armShape = [CAShapeLayer layer];
    armShape.path = armFillPath;
    armShape.fillColor = yellowBase.CGColor;
    [armContainer.layer addSublayer:armShape];

    CAShapeLayer *armEdge = [CAShapeLayer layer];
    armEdge.path = armFillPath;
    armEdge.fillColor = UIColor.clearColor.CGColor;
    armEdge.strokeColor = yellowShadow.CGColor;
    armEdge.lineWidth = 1.3;
    armEdge.opacity = 0.95;
    [armContainer.layer addSublayer:armEdge];
    CGPathRelease(armFillPath);

    CAShapeLayer *armHighlight = [CAShapeLayer layer];
    armHighlight.path = centerline.CGPath;
    armHighlight.fillColor = UIColor.clearColor.CGColor;
    armHighlight.strokeColor = yellowLight.CGColor;
    armHighlight.lineWidth = armWidth * 0.28;
    armHighlight.lineCap = kCALineCapRound;
    armHighlight.opacity = 0.55;
    [armContainer.layer addSublayer:armHighlight];

    CAShapeLayer * (^makeReveal)(void) = ^{
        CAShapeLayer *m = [CAShapeLayer layer];
        m.path = centerline.CGPath;
        m.fillColor = UIColor.clearColor.CGColor;
        m.strokeColor = UIColor.whiteColor.CGColor;
        m.lineWidth = armWidth * 1.5;
        m.lineCap = kCALineCapRound;
        m.strokeEnd = 0;
        return m;
    };
    CAShapeLayer *revealA = makeReveal();
    CAShapeLayer *revealB = makeReveal();
    CAShapeLayer *revealC = makeReveal();
    armShape.mask = revealA;
    armEdge.mask = revealB;
    armHighlight.mask = revealC;

    CAEmitterLayer *emitter = [self buildArmEmitter];
    emitter.frame = effectView.bounds;
    emitter.emitterPosition = armStart;
    [armContainer.layer addSublayer:emitter];

    // ======== 点赞手势（含 wrist stem）========
    //   stem 在 shape 底部 (0.38-0.62, 0.86-1.00) 这个小矩形区域。
    //   handRoot 定位：wrist stem 底部中点 (0.50, 1.00) 对齐 armEnd。
    //   armEnd 附近的 arm 线条（armWidth ~10pt，宽度明显小于 stem 宽度 0.24*handSize）
    //   被 stem 完全 "吞" 进去，视觉无缝。
    UIView *thumbView = [self createThumbsUpViewWithSize:handSize
                                               baseColor:yellowBase
                                               darkColor:yellowDark
                                              lightColor:yellowLight
                                             shadowColor:yellowShadow];

    // wrist 底部中点在本地 (0.50*S, 1.00*S)；handRoot 以此为定位基准
    //   对于无 mirror：handRoot.center.x = armEnd.x（wrist x 本地 0.5 = handRoot 中心 x）
    //                  handRoot.center.y = armEnd.y - 0.50*S（wrist y 本地 1.0 → 下边界）
    //   mirror 后：wrist x 本地 0.50 依然是中线，handRoot.center.x 不变
    CGPoint handCenter = CGPointMake(armEnd.x, armEnd.y - 0.50 * handSize);

    UIView *handRoot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, handSize, handSize)];
    handRoot.center = handCenter;
    if (fromSelf) handRoot.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    [effectView addSubview:handRoot];

    thumbView.frame = handRoot.bounds;
    thumbView.alpha = 0;
    thumbView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.25, 0.25),
                                                   CGAffineTransformMakeRotation(-15.0 * M_PI / 180.0));
    [handRoot addSubview:thumbView];

    // ============ Timeline ============
    NSTimeInterval armBegin = 0.05;
    NSTimeInterval armDur = 0.60;
    NSTimeInterval now = CACurrentMediaTime();

    // Phase A: arm 揭示 + 粒子
    CAKeyframeAnimation *emitterPos = [CAKeyframeAnimation animationWithKeyPath:@"emitterPosition"];
    emitterPos.path = centerline.CGPath;
    emitterPos.duration = armDur;
    emitterPos.beginTime = now + armBegin;
    emitterPos.calculationMode = kCAAnimationPaced;
    emitterPos.fillMode = kCAFillModeBoth;
    emitterPos.removedOnCompletion = NO;
    [emitter addAnimation:emitterPos forKey:@"classy-emitter-path"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(armBegin * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (CAEmitterCell *c in emitter.emitterCells) {
            if ([c.name isEqualToString:@"core"]) c.birthRate = 180;
            else if ([c.name isEqualToString:@"spark"]) c.birthRate = 70;
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((armBegin + armDur) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (CAEmitterCell *c in emitter.emitterCells) c.birthRate = 0;
    });

    CAMediaTimingFunction *armCurve = [CAMediaTimingFunction functionWithControlPoints:0.35 :0.0 :0.25 :1.0];
    for (CAShapeLayer *m in @[revealA, revealB, revealC]) {
        CABasicAnimation *reveal = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        reveal.fromValue = @(0);
        reveal.toValue = @(1);
        reveal.duration = armDur;
        reveal.beginTime = now + armBegin;
        reveal.fillMode = kCAFillModeForwards;
        reveal.removedOnCompletion = NO;
        reveal.timingFunction = armCurve;
        [m addAnimation:reveal forKey:@"arm-reveal"];
    }

    // Phase B: 点赞砸出来
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (effectView.superview == nil) return;

        [UIView animateWithDuration:0.48
                              delay:0
             usingSpringWithDamping:0.52
              initialSpringVelocity:1.1
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            thumbView.alpha = 1.0;
            thumbView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(1.55, 1.55),
                                                           CGAffineTransformMakeRotation(0));
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.22
                                  delay:0
                 usingSpringWithDamping:0.75
                  initialSpringVelocity:0.3
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                thumbView.transform = CGAffineTransformMakeScale(1.25, 1.25);
            } completion:^(BOOL finished2) {
                // 持续 subtle breathing
                CAKeyframeAnimation *breath = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
                breath.values = @[@(1.25), @(1.30), @(1.22), @(1.25)];
                breath.keyTimes = @[@(0), @(0.35), @(0.70), @(1.0)];
                breath.duration = 0.90;
                breath.repeatCount = HUGE_VALF;
                breath.autoreverses = NO;
                [thumbView.layer addAnimation:breath forKey:@"thumb-breath"];
            }];
        }];

        // 冲击波金环
        CGPoint ringCenter = [effectView convertPoint:CGPointMake(handSize * 0.5, handSize * 0.55) fromView:handRoot];
        [self emitImpactRingInView:effectView atCenter:ringCenter
                       startRadius:handSize * 0.20
                         endRadius:handSize * 1.10
                         ringColor:yellowBase
                          duration:0.55
                             delay:0.10];

        // 掌心金光 puff
        CGPoint puffCenter = [effectView convertPoint:CGPointMake(handSize * 0.5, handSize * 0.55) fromView:handRoot];
        [self emitGoldPuffInView:effectView atCenter:puffCenter radius:handSize * 0.40 intensity:260 duration:0.10];
    });

    // Phase C: 小星星
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (effectView.superview == nil) return;
        CGPoint thumbTipInHand = CGPointMake(0.40 * handSize, 0.07 * handSize);
        CGPoint thumbTipInEffect = [effectView convertPoint:thumbTipInHand fromView:handRoot];
        [self sprinkleStarsAround:thumbTipInEffect inView:effectView radius:handSize * 0.95 count:8
                         fillColor:yellowBase strokeColor:yellowShadow];
    });

    [effectView scheduleRemovalAfterDelay:2.10];
}

#pragma mark - Thumbs-up shape with wrist stem

/// 点赞形状：参照用户给的 PNG 轮廓 —— 高挑大拇指（顶端微前倾）、palm 右侧 4 段 knuckle 明显凸起、
/// 底部有 **腕部 stem**（从 palm 底部往下收窄的短柱，延伸到 handSize 下边界），方便和手臂
/// 无缝衔接 —— armEnd 落在 stem 底部中心处，arm 的圆头末端正好被 stem "吞" 进去。
+ (UIView *)createThumbsUpViewWithSize:(CGFloat)S
                             baseColor:(UIColor *)baseColor
                             darkColor:(UIColor *)darkColor
                            lightColor:(UIColor *)lightColor
                           shadowColor:(UIColor *)shadowColor {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, S, S)];
    v.backgroundColor = UIColor.clearColor;

    UIBezierPath *p = [UIBezierPath bezierPath];

    // ------ 拇指 ------
    [p moveToPoint:CGPointMake(0.28*S, 0.09*S)];
    [p addQuadCurveToPoint:CGPointMake(0.52*S, 0.08*S) controlPoint:CGPointMake(0.38*S, 0.00*S)];
    [p addCurveToPoint:CGPointMake(0.58*S, 0.42*S)
         controlPoint1:CGPointMake(0.53*S, 0.20*S)
         controlPoint2:CGPointMake(0.56*S, 0.32*S)];

    // ------ palm 顶部 → 右上角 ------
    [p addQuadCurveToPoint:CGPointMake(0.72*S, 0.42*S) controlPoint:CGPointMake(0.64*S, 0.48*S)];
    [p addQuadCurveToPoint:CGPointMake(0.90*S, 0.40*S) controlPoint:CGPointMake(0.82*S, 0.38*S)];
    [p addQuadCurveToPoint:CGPointMake(0.95*S, 0.48*S) controlPoint:CGPointMake(0.97*S, 0.42*S)];

    // ------ 右侧 4 段 knuckle ------
    [p addQuadCurveToPoint:CGPointMake(0.94*S, 0.57*S) controlPoint:CGPointMake(1.00*S, 0.52*S)];
    [p addQuadCurveToPoint:CGPointMake(0.94*S, 0.66*S) controlPoint:CGPointMake(1.00*S, 0.62*S)];
    [p addQuadCurveToPoint:CGPointMake(0.93*S, 0.75*S) controlPoint:CGPointMake(0.99*S, 0.70*S)];
    [p addQuadCurveToPoint:CGPointMake(0.83*S, 0.82*S) controlPoint:CGPointMake(0.98*S, 0.80*S)];

    // ------ palm 底部过渡到 wrist stem（右侧收窄）------
    [p addQuadCurveToPoint:CGPointMake(0.64*S, 0.86*S) controlPoint:CGPointMake(0.74*S, 0.86*S)];

    // ------ wrist stem 右下 → 底部 → 左下 ------
    //   stem 宽度 = 0.28*S，和 arm 的 ~0.09*S 相比足够宽，完全盖住 arm 的圆头
    [p addLineToPoint:CGPointMake(0.63*S, 1.00*S)];           // stem 右下
    [p addQuadCurveToPoint:CGPointMake(0.37*S, 1.00*S)
              controlPoint:CGPointMake(0.50*S, 1.03*S)];       // 底部圆弧
    [p addLineToPoint:CGPointMake(0.36*S, 0.86*S)];           // stem 左上

    // ------ wrist stem 过渡回 palm 底部左侧 ------
    [p addQuadCurveToPoint:CGPointMake(0.17*S, 0.84*S) controlPoint:CGPointMake(0.26*S, 0.88*S)];

    // ------ palm 左侧（拇指下方）→ 拇指底 ------
    [p addLineToPoint:CGPointMake(0.10*S, 0.65*S)];
    [p addQuadCurveToPoint:CGPointMake(0.18*S, 0.53*S) controlPoint:CGPointMake(0.10*S, 0.58*S)];

    // ------ 拇指左侧回到起点 ------
    [p addCurveToPoint:CGPointMake(0.28*S, 0.09*S)
         controlPoint1:CGPointMake(0.20*S, 0.38*S)
         controlPoint2:CGPointMake(0.24*S, 0.20*S)];
    [p closePath];

    // 主 fill 层
    CAShapeLayer *main = [CAShapeLayer layer];
    main.path = p.CGPath;
    main.fillColor = baseColor.CGColor;
    main.strokeColor = shadowColor.CGColor;
    main.lineWidth = 2.0;
    main.lineJoin = kCALineJoinRound;
    main.shadowColor = shadowColor.CGColor;
    main.shadowOffset = CGSizeMake(0.8, 2.8);
    main.shadowOpacity = 0.30;
    main.shadowRadius = 3.0;
    [v.layer addSublayer:main];

    // 下半部分深金渐变（体积感）
    CAGradientLayer *bottomShade = [CAGradientLayer layer];
    bottomShade.frame = v.bounds;
    bottomShade.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[darkColor colorWithAlphaComponent:0.0].CGColor,
        (id)[darkColor colorWithAlphaComponent:0.22].CGColor,
    ];
    bottomShade.locations = @[@0.0, @0.55, @1.0];
    bottomShade.startPoint = CGPointMake(0.5, 0.0);
    bottomShade.endPoint = CGPointMake(0.5, 1.0);
    CAShapeLayer *shadeMask = [CAShapeLayer layer];
    shadeMask.path = p.CGPath;
    shadeMask.fillColor = UIColor.blackColor.CGColor;
    bottomShade.mask = shadeMask;
    [v.layer addSublayer:bottomShade];

    // 拇指上段柔和亮色
    CGRect highlightRect = CGRectMake(0.28*S, 0.10*S, 0.22*S, 0.28*S);
    UIView *highlight = [[UIView alloc] initWithFrame:highlightRect];
    highlight.backgroundColor = [lightColor colorWithAlphaComponent:0.45];
    highlight.layer.cornerRadius = 0.11*S;
    [v addSubview:highlight];

    return v;
}

#pragma mark - Impact ring

+ (void)emitImpactRingInView:(UIView *)host
                     atCenter:(CGPoint)center
                  startRadius:(CGFloat)r0
                    endRadius:(CGFloat)r1
                    ringColor:(UIColor *)color
                     duration:(NSTimeInterval)duration
                        delay:(NSTimeInterval)delay {
    CAShapeLayer *ring = [CAShapeLayer layer];
    ring.fillColor = UIColor.clearColor.CGColor;
    ring.strokeColor = color.CGColor;
    ring.lineWidth = 4.0;
    ring.path = [UIBezierPath bezierPathWithArcCenter:center radius:r0
                                           startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    ring.opacity = 0;
    [host.layer addSublayer:ring];

    NSTimeInterval begin = CACurrentMediaTime() + delay;

    CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"path"];
    grow.fromValue = (id)[UIBezierPath bezierPathWithArcCenter:center radius:r0
                                                    startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    grow.toValue = (id)[UIBezierPath bezierPathWithArcCenter:center radius:r1
                                                  startAngle:0 endAngle:2*M_PI clockwise:YES].CGPath;
    grow.duration = duration;
    grow.beginTime = begin;
    grow.fillMode = kCAFillModeBoth;
    grow.removedOnCompletion = NO;
    grow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [ring addAnimation:grow forKey:@"ring-grow"];

    CAKeyframeAnimation *opacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacity.values = @[@0.0, @0.85, @0.0];
    opacity.keyTimes = @[@0.0, @0.25, @1.0];
    opacity.duration = duration;
    opacity.beginTime = begin;
    opacity.fillMode = kCAFillModeBoth;
    opacity.removedOnCompletion = NO;
    [ring addAnimation:opacity forKey:@"ring-opacity"];

    CABasicAnimation *width = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
    width.fromValue = @6.0;
    width.toValue = @1.0;
    width.duration = duration;
    width.beginTime = begin;
    width.fillMode = kCAFillModeBoth;
    width.removedOnCompletion = NO;
    [ring addAnimation:width forKey:@"ring-width"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay + duration + 0.1) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [ring removeFromSuperlayer];
    });
}

#pragma mark - Geometry helper

+ (CGPoint)cubicBezierPoint:(CGFloat)t p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2 p3:(CGPoint)p3 {
    CGFloat u = 1.0 - t;
    return CGPointMake(u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
                       u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y);
}

#pragma mark - Stars

+ (void)sprinkleStarsAround:(CGPoint)center
                     inView:(UIView *)host
                     radius:(CGFloat)radius
                      count:(NSInteger)count
                  fillColor:(UIColor *)fill
                strokeColor:(UIColor *)stroke {
    for (NSInteger i = 0; i < count; i++) {
        CGFloat angle = (2 * M_PI / count) * i + ((CGFloat)arc4random_uniform(200) - 100) / 1000.0;
        CGFloat r = radius * (0.55 + (CGFloat)arc4random_uniform(80) / 200.0);
        CGPoint pos = CGPointMake(center.x + cos(angle) * r,
                                  center.y + sin(angle) * r - radius * 0.10);
        CGFloat size = 4.0 + (CGFloat)arc4random_uniform(35) / 10.0;

        CAShapeLayer *star = [CAShapeLayer layer];
        star.path = [self starPathWithOuterRadius:size innerRadius:size * 0.42].CGPath;
        star.fillColor = fill.CGColor;
        star.strokeColor = stroke.CGColor;
        star.lineWidth = 1.0;
        star.lineJoin = kCALineJoinRound;
        star.position = pos;
        star.opacity = 0;
        star.transform = CATransform3DMakeScale(0.6, 0.6, 1);
        [host.layer addSublayer:star];

        NSTimeInterval delay = 0.02 + i * 0.03 + (NSTimeInterval)arc4random_uniform(40) / 1000.0;

        CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeIn.fromValue = @(0);
        fadeIn.toValue = @(1.0);
        fadeIn.duration = 0.14;
        fadeIn.beginTime = CACurrentMediaTime() + delay;
        fadeIn.fillMode = kCAFillModeForwards;
        fadeIn.removedOnCompletion = NO;
        [star addAnimation:fadeIn forKey:@"star-in"];

        CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeOut.fromValue = @(1.0);
        fadeOut.toValue = @(0);
        fadeOut.duration = 0.32;
        fadeOut.beginTime = CACurrentMediaTime() + delay + 0.25;
        fadeOut.fillMode = kCAFillModeForwards;
        fadeOut.removedOnCompletion = NO;
        [star addAnimation:fadeOut forKey:@"star-out"];

        CAKeyframeAnimation *pulse = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pulse.values = @[@(0.6), @(1.15), @(0.95), @(1.05), @(0.8)];
        pulse.keyTimes = @[@(0), @(0.25), @(0.55), @(0.80), @(1.0)];
        pulse.duration = 0.55;
        pulse.beginTime = CACurrentMediaTime() + delay;
        pulse.fillMode = kCAFillModeForwards;
        pulse.removedOnCompletion = NO;
        [star addAnimation:pulse forKey:@"star-pulse"];

        CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spin.fromValue = @(-0.15);
        spin.toValue = @(0.15);
        spin.duration = 0.55;
        spin.beginTime = CACurrentMediaTime() + delay;
        spin.fillMode = kCAFillModeForwards;
        spin.removedOnCompletion = NO;
        [star addAnimation:spin forKey:@"star-spin"];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay + 0.65) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [star removeFromSuperlayer];
        });
    }
}

+ (UIBezierPath *)starPathWithOuterRadius:(CGFloat)outer innerRadius:(CGFloat)inner {
    UIBezierPath *p = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < 10; i++) {
        CGFloat a = -M_PI_2 + i * (M_PI / 5.0);
        CGFloat r = (i % 2 == 0) ? outer : inner;
        CGPoint pt = CGPointMake(cos(a) * r, sin(a) * r);
        if (i == 0) [p moveToPoint:pt];
        else [p addLineToPoint:pt];
    }
    [p closePath];
    return p;
}

#pragma mark - Emitter

+ (CAEmitterLayer *)buildArmEmitter {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterShape = kCAEmitterLayerPoint;
    emitter.emitterMode = kCAEmitterLayerPoints;
    emitter.renderMode = kCAEmitterLayerAdditive;
    emitter.emitterSize = CGSizeZero;

    UIImage *puff = [self particlePuffImage];

    CAEmitterCell *core = [CAEmitterCell emitterCell];
    core.name = @"core";
    core.contents = (id)puff.CGImage;
    core.birthRate = 0;
    core.lifetime = 0.38;
    core.lifetimeRange = 0.10;
    core.scale = 0.22;
    core.scaleRange = 0.10;
    core.scaleSpeed = -0.5;
    core.alphaRange = 0.2;
    core.alphaSpeed = -2.4;
    core.velocity = 14;
    core.velocityRange = 8;
    core.emissionRange = 2 * M_PI;
    core.color = [UIColor colorWithRed:1.0 green:0.835 blue:0.376 alpha:1.0].CGColor;

    CAEmitterCell *spark = [CAEmitterCell emitterCell];
    spark.name = @"spark";
    spark.contents = (id)puff.CGImage;
    spark.birthRate = 0;
    spark.lifetime = 0.26;
    spark.lifetimeRange = 0.08;
    spark.scale = 0.14;
    spark.scaleRange = 0.06;
    spark.scaleSpeed = -0.4;
    spark.alphaSpeed = -3.2;
    spark.velocity = 22;
    spark.velocityRange = 14;
    spark.emissionRange = 2 * M_PI;
    spark.color = [UIColor colorWithRed:0.259 green:0.780 blue:1.0 alpha:1.0].CGColor;
    spark.redRange = 0.2;
    spark.greenRange = 0.2;
    spark.blueRange = 0.1;

    emitter.emitterCells = @[core, spark];
    return emitter;
}

+ (UIImage *)particlePuffImage {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGFloat size = 24.0;
        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
        img = [r imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
            CGContextRef cg = ctx.CGContext;
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            NSArray *colors = @[
                (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor,
                (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            ];
            CGFloat locs[] = {0.0, 0.45, 1.0};
            CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)colors, locs);
            CGContextDrawRadialGradient(cg, g,
                                        CGPointMake(size/2, size/2), 0,
                                        CGPointMake(size/2, size/2), size/2, 0);
            CGGradientRelease(g);
            CGColorSpaceRelease(cs);
        }];
    });
    return img;
}

#pragma mark - Gold puff

+ (void)emitGoldPuffInView:(UIView *)host
                  atCenter:(CGPoint)center
                    radius:(CGFloat)radius
                 intensity:(CGFloat)birthRate
                  duration:(NSTimeInterval)burstDur {
    CAEmitterLayer *puffEmitter = [CAEmitterLayer layer];
    puffEmitter.emitterShape = kCAEmitterLayerPoint;
    puffEmitter.emitterMode = kCAEmitterLayerPoints;
    puffEmitter.renderMode = kCAEmitterLayerAdditive;
    puffEmitter.emitterPosition = center;
    puffEmitter.frame = host.bounds;

    CAEmitterCell *c = [CAEmitterCell emitterCell];
    c.contents = (id)[self particlePuffImage].CGImage;
    c.birthRate = birthRate;
    c.lifetime = 0.50;
    c.lifetimeRange = 0.10;
    c.scale = 0.26;
    c.scaleRange = 0.12;
    c.scaleSpeed = -0.4;
    c.alphaSpeed = -2.2;
    c.velocity = radius * 4.2;
    c.velocityRange = radius * 1.4;
    c.emissionRange = 2 * M_PI;
    c.color = [UIColor colorWithRed:1.0 green:0.90 blue:0.45 alpha:1.0].CGColor;
    puffEmitter.emitterCells = @[c];
    [host.layer addSublayer:puffEmitter];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(burstDur * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (CAEmitterCell *cell in puffEmitter.emitterCells) cell.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((burstDur + 0.70) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [puffEmitter removeFromSuperlayer];
    });
}

@end
