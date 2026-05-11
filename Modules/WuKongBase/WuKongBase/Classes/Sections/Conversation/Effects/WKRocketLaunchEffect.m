//
//  WKRocketLaunchEffect.m
//  WuKongBase
//
//  火箭用 CAShapeLayer + CAGradientLayer + CAEmitterLayer 原生绘制。
//  结构参考 CodePen chingy/OJMLodv：鼻锥 / 机身 / 舷窗 / Octo 文字 / 红条带 / 尾翼 / 喷口 / 火焰 / 烟雾。
//
//  动画时间轴（总 ~4.2s）：
//    0.0~0.3s  入场（spring scale 0→1）+ 火焰点燃
//    0.3~1.1s  引擎启动（机身 X 轴震动 + 烟雾喷射）
//    1.1~1.9s  缓缓升空（Y -80pt，easeOut）
//    1.9~3.4s  加速发射（power4 曲线飞出屏幕 + 火焰/烟雾放大）
//    3.4~4.0s  拖尾星星粒子消散
//    4.2s      effectView 清理

#import "WKRocketLaunchEffect.h"
#import "WKMessageEffectView.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKRocketLaunchEffect

#pragma mark - 常量

static const CGFloat kRocketWidth  = 64.0;
static const CGFloat kRocketHeight = 138.0;

// 霓虹全息风配色（参照表情包火箭图）：
//   机身：青蓝 → 银白 → 紫粉 三色水平渐变（全息感）
//   鼻锥：青蓝 → 紫 渐变 + 亮白顶端
//   舷窗：深紫外框 + 蓝色玻璃 + 白色高光
//   尾翼：紫色主体 + 橙黄描边（卡通感）
//   喷口：橙色
//   文字："Octo" 用深紫（与机身紫粉调性呼应）
static UIColor *kBodyCyanColor(void)     { return [UIColor colorWithRed:0x5C/255.0 green:0xD0/255.0 blue:0xFA/255.0 alpha:1.0]; } // 亮青 #5CD0FA
static UIColor *kBodySilverColor(void)   { return [UIColor colorWithRed:0xEE/255.0 green:0xF4/255.0 blue:0xFA/255.0 alpha:1.0]; } // 银白 #EEF4FA
static UIColor *kBodyMidColor(void)      { return [UIColor colorWithRed:0xD3/255.0 green:0xDD/255.0 blue:0xEB/255.0 alpha:1.0]; } // 中银 #D3DDEB
static UIColor *kBodyPurpleColor(void)   { return [UIColor colorWithRed:0xBE/255.0 green:0x8A/255.0 blue:0xE8/255.0 alpha:1.0]; } // 紫粉 #BE8AE8
static UIColor *kAccentPurpleColor(void) { return [UIColor colorWithRed:0x8A/255.0 green:0x5C/255.0 blue:0xD6/255.0 alpha:1.0]; } // 深紫 #8A5CD6
static UIColor *kAccentCyanColor(void)   { return [UIColor colorWithRed:0x49/255.0 green:0xBF/255.0 blue:0xEB/255.0 alpha:1.0]; } // 深青 #49BFEB
static UIColor *kOrangeAccentColor(void) { return [UIColor colorWithRed:0xFF/255.0 green:0x9A/255.0 blue:0x3B/255.0 alpha:1.0]; } // 橙黄 #FF9A3B
static UIColor *kWindowBlueColor(void)   { return [UIColor colorWithRed:0x4A/255.0 green:0xA5/255.0 blue:0xFF/255.0 alpha:1.0]; } // 舷窗亮蓝 #4AA5FF
static UIColor *kWindowDeepColor(void)   { return [UIColor colorWithRed:0x1E/255.0 green:0x5F/255.0 blue:0xC4/255.0 alpha:1.0]; } // 舷窗深蓝 #1E5FC4
static UIColor *kTextColor(void)         { return [UIColor colorWithRed:0x5B/255.0 green:0x3E/255.0 blue:0x8E/255.0 alpha:1.0]; } // 深紫 #5B3E8E
static UIColor *kNozzleColor(void)       { return [UIColor colorWithRed:0xE8/255.0 green:0x74/255.0 blue:0x29/255.0 alpha:1.0]; } // 暖橙 #E87429
// 鼻锥红色系（红帽子 — 有层次的暖红）
static UIColor *kNoseRedBrightColor(void){ return [UIColor colorWithRed:0xFF/255.0 green:0x7A/255.0 blue:0x6C/255.0 alpha:1.0]; } // 亮红橙 #FF7A6C
static UIColor *kNoseRedColor(void)      { return [UIColor colorWithRed:0xE7/255.0 green:0x4C/255.0 blue:0x3C/255.0 alpha:1.0]; } // 经典红 #E74C3C
static UIColor *kNoseRedDarkColor(void)  { return [UIColor colorWithRed:0xA8/255.0 green:0x32/255.0 blue:0x34/255.0 alpha:1.0]; } // 深红 #A83234
static UIColor *kNoseSeamColor(void)     { return [UIColor colorWithRed:0x75/255.0 green:0x24/255.0 blue:0x2F/255.0 alpha:1.0]; } // 暗红接缝 #75242F
static UIColor *kRivetColor(void)        { return [UIColor colorWithRed:0x7D/255.0 green:0x8B/255.0 blue:0xA3/255.0 alpha:1.0]; } // 铆钉深灰蓝 #7D8BA3

#pragma mark - 主入口

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    [self playInView:effectView sourceRect:sourceRect avatarImage:nil];
}

+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
       avatarImage:(nullable UIImage *)avatarImage {
    if (!effectView) return;

    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;

    // 发射起点：气泡中心（若无则屏幕中下部）
    CGPoint origin;
    if (!CGRectIsEmpty(sourceRect)) {
        origin = CGPointMake(CGRectGetMidX(sourceRect), CGRectGetMidY(sourceRect));
    } else {
        origin = CGPointMake(viewW * 0.5, viewH * 0.75);
    }

    // 火箭容器视图（包含机身 bodyContainer + 喷射火焰）
    UIView *rocketView = [self buildRocketViewWithSize:CGSizeMake(kRocketWidth, kRocketHeight)
                                           avatarImage:avatarImage];
    rocketView.center = origin;
    rocketView.transform = CGAffineTransformMakeScale(0.001, 0.001);
    [effectView addSubview:rocketView];

    // 机身子容器（shake 只作用于此，避免传递给火焰导致"歪"）
    UIView *bodyContainer = [rocketView viewWithTag:1001];

    // 水滴形火焰（实体 CAShapeLayer）：尖端朝下，始终贴在火箭尾部垂直向下
    // 通过 scale.x / scale.y 的阶段动画实现蓄势→发射的形态变化：
    //   - 蓄势：X 放大 Y 压缩 → 宽胖短（待机火球）
    //   - 发射：X 收窄 Y 最长 → 窄长喷射
    CALayer *coreFlame = [self coreFlameLayer];
    coreFlame.position = CGPointMake(kRocketWidth / 2.0, kRocketHeight);
    coreFlame.opacity = 0;
    [rocketView.layer addSublayer:coreFlame];

    // 烟雾云（**不跟随火箭**）：覆盖屏幕全宽，强化视觉冲击
    // 烟雾云覆盖整个屏幕 → 烟雾有充足空间向上翻卷、向四周扩散
    // SKScene 的湍流场/涡流场作用范围 = 云框尺寸；全屏尺寸让烟雾可以飘得足够远
    CGFloat cloudW = viewW;
    CGFloat cloudH = viewH;
    CGRect cloudFrame = CGRectMake(0, 0, cloudW, cloudH);
    WKRocketSmokeCloud *smokeCloud = [[WKRocketSmokeCloud alloc] initWithFrame:cloudFrame];
    [effectView insertSubview:smokeCloud belowSubview:rocketView];

    CGPoint nozzleInCloud = [effectView convertPoint:CGPointMake(origin.x, origin.y + kRocketHeight / 2.0 - 4.0)
                                              toView:smokeCloud];
    [smokeCloud startEmittingAtNozzlePoint:nozzleInCloud spread:kRocketWidth * 0.45];

    // 舷窗扫光动画（两次）—— 放在此处（addSubview 之后）而非 buildRocketViewWithSize 里，
    // 因为 CAAnimation.beginTime 依赖 layer 的本地时间坐标系，
    // 而 layer 只有在加入 view 层级后才有本地时间 → 之前在层级外设置会错位。
    CALayer *shimmerLayer = [self findLayerWithName:@"window-shimmer" inLayer:rocketView.layer];
    if (shimmerLayer) {
        // 第 1 次：蓄势中 0.5s 触发
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CABasicAnimation *sweep1 = [CABasicAnimation animationWithKeyPath:@"locations"];
            sweep1.fromValue = @[@(-0.3), @(-0.2), @(-0.1), @(0.0), @(0.1)];
            sweep1.toValue = @[@(0.9), @(1.0), @(1.1), @(1.2), @(1.3)];
            sweep1.duration = 0.55;
            sweep1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            sweep1.fillMode = kCAFillModeBoth;
            [shimmerLayer addAnimation:sweep1 forKey:@"glass-shimmer-1"];
        });
        // 第 2 次：起飞后 1.4s 触发
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CABasicAnimation *sweep2 = [CABasicAnimation animationWithKeyPath:@"locations"];
            sweep2.fromValue = @[@(-0.3), @(-0.2), @(-0.1), @(0.0), @(0.1)];
            sweep2.toValue = @[@(0.9), @(1.0), @(1.1), @(1.2), @(1.3)];
            sweep2.duration = 0.55;
            sweep2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            sweep2.fillMode = kCAFillModeBoth;
            [shimmerLayer addAnimation:sweep2 forKey:@"glass-shimmer-2"];
        });
    }

    // === 动画编排（两阶段：蓄势 → 发射）===
    // 0.0 ~ 0.3s  入场 spring
    // 0.25 ~ 1.0s 蓄势（机身震动、烟雾涌出、火焰待机胖短）
    // 1.0 ~ 2.4s  发射（直接从蓄势过渡到加速飞出，不做中间"缓缓升空"）
    // 2.0s         播撒星星
    // 1.9s         烟雾停止
    // 3.0s         清理

    // 阶段 1：入场（0.0~0.3s）
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        rocketView.transform = CGAffineTransformIdentity;
    } completion:nil];

    // 阶段 2：引擎蓄势（0.25 ~ 1.0s）火焰待机 + 大量白烟涌出 + 机身震动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        coreFlame.opacity = 1.0;
        [self setCoreFlameScaleX:coreFlame toValue:1.35 duration:0.25];
        [self startFlickerOnLayer:coreFlame baseScale:0.65];

        // 蓄势烟雾：快速涌到大量白烟（1.5 = 浓密白烟，颜色仍在 0.93 左右 → 白为主）
        [smokeCloud animateIntensityTo:1.5 duration:0.55];

        [self applyEngineShakeToView:bodyContainer duration:0.75];

        UIImpactFeedbackGenerator *light = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [light prepare];
        [light impactOccurred];
    });

    // 阶段 3：直接加速发射（1.0 ~ 2.4s）从原地直接飞出屏幕顶部
    __block CGPoint liftStart = origin;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CAMediaTimingFunction *power4 = [CAMediaTimingFunction functionWithControlPoints:0.4 :0.0 :1.0 :0.25];
        [CATransaction begin];
        [CATransaction setAnimationTimingFunction:power4];
        [UIView animateWithDuration:1.4
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            rocketView.center = CGPointMake(origin.x, -(kRocketHeight * 3) - 200);
        } completion:^(BOOL finished) {
            rocketView.hidden = YES;
        }];
        [CATransaction commit];

        // 火焰：X 最窄 0.75，Y 最长 1.75（一束狭长喷射）
        [self setCoreFlameScaleX:coreFlame toValue:0.75 duration:0.35];
        [coreFlame removeAnimationForKey:@"flame-flicker"];
        [self startFlickerOnLayer:coreFlame baseScale:1.75];

        // 烟雾：发射推力冲击 → intensity 升到 1.9 (烟量最大且最浓)
        [smokeCloud animateIntensityTo:1.9 duration:0.5];

        // 火焰炙烤粒子（红色染色）：
        //   1. 先切换到"起飞形态"：粒子拉长、顺左右喷射方向 → 橙色烟条
        //   2. 0.45s 内 heatLevel 从 1.0 → 0，新红粒子在 1.45s 停产
        //   3. 已生成粒子按 lifetime 0.4~0.55s 自然淡出 → **2.0s 画面中完全无红色**
        [smokeCloud configureHeatForLaunch];
        [smokeCloud fadeHeatLevelTo:0 duration:0.45];

        // 爆发冲击：径向推力场把蓄势阶段累积的白烟"吹散"翻滚 → 真实感
        CGPoint nozzleWorld = CGPointMake(origin.x, origin.y + kRocketHeight / 2.0 - 4.0);
        CGPoint nozzleInCloudLocal = [effectView convertPoint:nozzleWorld toView:smokeCloud];
        [smokeCloud applyBlastAtNozzlePoint:nozzleInCloudLocal duration:0.9];

        UIImpactFeedbackGenerator *medium = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [medium prepare];
        [medium impactOccurred];
    });

    // 烟雾衰减链（快速多段下降）
    //   1.9 (峰值 @1.0s) → 1.3 (@2.2s) → 0.55 (@2.7s) → 0.10 (@3.2s) → stopEmitting (@3.3s)
    // 火箭于 2.4s 飞出屏幕，尾段在其后 ~2s 内完全淡出（配合 emitter 较短 lifetime + 快 alphaSpeed）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:1.30 duration:0.5];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:0.55 duration:0.5];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud animateIntensityTo:0.10 duration:0.5];
    });

    // 阶段 4：发射路径上留下 4 颗星星
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGPoint liftEndCenter = CGPointMake(liftStart.x, liftStart.y - 80.0);
        [self scatterSparkleStarsAlongPathFrom:liftStart to:liftEndCenter inView:effectView];
    });

    // 阶段 5：烟雾停止生成（intensity 已降到 0.10）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud stopEmitting];
    });

    // 阶段 6：清理（stopEmitting 后 ~1.6s，已生成粒子按 alphaSpeed 全部淡出）
    // 总计：火箭 2.4s 飞出屏幕 → 4.9s 烟雾彻底清除 = 尾段 ~2.5s
    [effectView scheduleRemovalAfterDelay:4.9];
}

#pragma mark - 火箭视图组装

+ (UIView *)buildRocketViewWithSize:(CGSize)size avatarImage:(nullable UIImage *)avatarImage {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    container.userInteractionEnabled = NO;
    container.backgroundColor = [UIColor clearColor];

    // 机身子容器（所有机身 layer 加到这里）。shake 只应用到这个子视图，
    // 不会传递给火焰粒子，避免火焰看起来"歪"。
    UIView *bodyContainer = [[UIView alloc] initWithFrame:container.bounds];
    bodyContainer.tag = 1001;
    bodyContainer.userInteractionEnabled = NO;
    bodyContainer.backgroundColor = [UIColor clearColor];
    [container addSubview:bodyContainer];

    // 部件几何（相对 bodyContainer 坐标，原点 top-left）
    CGFloat W = size.width;
    CGFloat H = size.height;
    CGFloat noseH   = H * 0.26;                     // 鼻锥高度（按比例随火箭尺寸变化）
    CGFloat nozzleH = 7.0;
    CGFloat bodyTop = noseH;
    CGFloat bodyBottom = H - nozzleH;
    CGRect bodyRect = CGRectMake(0, bodyTop, W, bodyBottom - bodyTop);

    // 1. 机身（白→浅灰水平渐变模拟光照）
    CALayer *body = [self bodyLayerInRect:bodyRect];
    [bodyContainer.layer addSublayer:body];

    // 2. 鼻锥（红→深红垂直渐变）
    CALayer *nose = [self noseConeLayerInRect:CGRectMake(0, 0, W, noseH)];
    [bodyContainer.layer addSublayer:nose];

    // 3. 舷窗（机身上部）— 舷窗内嵌发送者头像，像是发送者坐在火箭里
    CGFloat windowRadius = W * 0.19;               // 舷窗直径约 W*0.38，随火箭放大
    CGPoint windowCenter = CGPointMake(W / 2.0, bodyTop + windowRadius + 4.0);
    CALayer *windowLayer = [self windowLayerAtCenter:windowCenter radius:windowRadius avatarImage:avatarImage];
    [bodyContainer.layer addSublayer:windowLayer];

    // 4. "Octo" 文字（舷窗下方）
    CALayer *octo = [self octoLabelCenteredAt:CGPointMake(W / 2.0, windowCenter.y + windowRadius + 14.0)];
    [bodyContainer.layer addSublayer:octo];

    // 5. 机身分段线（机身中下部一道细接缝 → 替代突兀的橙色装饰条）
    //    模拟机身分段构造：上半段和下半段的接缝处有一条深色细线 + 两个小铆钉
    CGFloat seamY = bodyBottom - 26.0;
    CAShapeLayer *seamLine = [CAShapeLayer layer];
    UIBezierPath *seamPath = [UIBezierPath bezierPath];
    [seamPath moveToPoint:CGPointMake(4.0, seamY)];
    [seamPath addLineToPoint:CGPointMake(W - 4.0, seamY)];
    seamLine.path = seamPath.CGPath;
    seamLine.strokeColor = [kAccentPurpleColor() colorWithAlphaComponent:0.38].CGColor;
    seamLine.lineWidth = 0.7;
    [bodyContainer.layer addSublayer:seamLine];

    // 接缝处左右两颗小铆钉（加固感）
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat rx = (i == 0) ? W * 0.16 : W * 0.84;
        CAShapeLayer *rivet = [CAShapeLayer layer];
        rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(rx - 1.1, seamY - 1.1, 2.2, 2.2)].CGPath;
        rivet.fillColor = [kRivetColor() colorWithAlphaComponent:0.7].CGColor;
        [bodyContainer.layer addSublayer:rivet];
    }

    // 6. 左右尾翼（从机身底部向外斜下，顶边嵌入机身内侧平滑衔接）
    CAShapeLayer *finL = [self finLayerLeft:YES bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finL];
    CAShapeLayer *finR = [self finLayerLeft:NO bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finR];

    // 7. 喷口（倒梯形）
    CGRect nozzleRect = CGRectMake(0, bodyBottom, W, nozzleH);
    CAShapeLayer *nozzle = [self nozzleLayerInRect:nozzleRect];
    [bodyContainer.layer addSublayer:nozzle];

    // 8. 中尾翼（机身底部中央，倒三角形指向喷口方向 → 呼应参考图第三片尾翼）
    //    放在喷口之上避免视觉冲突（中翼覆盖喷口中段）
    CALayer *centerFin = [self centerFinLayerInBodyRect:bodyRect nozzleRect:nozzleRect];
    [bodyContainer.layer addSublayer:centerFin];

    return container;
}

#pragma mark - 机身 (Body)

+ (CALayer *)bodyLayerInRect:(CGRect)rect {
    // 机身外形：圆角胶囊形
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
                          CGRectMake(rect.origin.x + 1, rect.origin.y, rect.size.width - 2, rect.size.height)
                          cornerRadius:rect.size.width * 0.18];

    // 霓虹全息水平渐变：青蓝 → 银白 → 中银 → 紫粉
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kBodyCyanColor().CGColor,    // 0.0  左侧亮青
        (id)kBodySilverColor().CGColor,  // 0.35 银白高光
        (id)kBodyMidColor().CGColor,     // 0.65 中银过渡
        (id)kBodyPurpleColor().CGColor,  // 1.0  右侧紫粉
    ];
    gradient.locations = @[@(0.0), @(0.35), @(0.65), @(1.0)];
    gradient.startPoint = CGPointMake(0.0, 0.5);
    gradient.endPoint = CGPointMake(1.0, 0.5);

    // 用形状做 mask
    CAShapeLayer *mask = [CAShapeLayer layer];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:
                              CGRectMake(1, 0, rect.size.width - 2, rect.size.height)
                              cornerRadius:rect.size.width * 0.18];
    mask.path = maskPath.CGPath;
    gradient.mask = mask;

    // 在外层包一个 wrapper，叠加橙色描边（卡通勾边感）
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + rect.size.width, rect.origin.y + rect.size.height);
    [wrapper addSublayer:gradient];

    // === 光泽质感增强（多层叠加）===

    // 光泽 1：顶部弧形高光（机身顶部一道弧 → 模拟曲面的反射光带）
    CAGradientLayer *topGloss = [CAGradientLayer layer];
    topGloss.frame = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height * 0.35);
    topGloss.colors = @[
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.12].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    topGloss.locations = @[@(0.0), @(0.6), @(1.0)];
    topGloss.startPoint = CGPointMake(0.5, 0.0);
    topGloss.endPoint = CGPointMake(0.5, 1.0);
    // mask 到机身轮廓（避免溢出圆角外）
    CAShapeLayer *topGlossMask = [CAShapeLayer layer];
    UIBezierPath *topGlossMaskPath = [UIBezierPath bezierPathWithRoundedRect:
                                      CGRectMake(1, 0, rect.size.width - 2, topGloss.frame.size.height)
                                      cornerRadius:rect.size.width * 0.18];
    topGlossMask.path = topGlossMaskPath.CGPath;
    topGloss.mask = topGlossMask;
    [wrapper addSublayer:topGloss];

    // 光泽 2：底部阴影渐变（下部微暗 → 3D 圆柱立体感）
    CAGradientLayer *bottomShade = [CAGradientLayer layer];
    CGFloat shadeH = rect.size.height * 0.30;
    bottomShade.frame = CGRectMake(rect.origin.x, rect.origin.y + rect.size.height - shadeH,
                                   rect.size.width, shadeH);
    bottomShade.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[[UIColor blackColor] colorWithAlphaComponent:0.10].CGColor,
        (id)[[UIColor blackColor] colorWithAlphaComponent:0.20].CGColor,
    ];
    bottomShade.locations = @[@(0.0), @(0.6), @(1.0)];
    bottomShade.startPoint = CGPointMake(0.5, 0.0);
    bottomShade.endPoint = CGPointMake(0.5, 1.0);
    CAShapeLayer *bottomShadeMask = [CAShapeLayer layer];
    UIBezierPath *bottomShadeMaskPath = [UIBezierPath bezierPathWithRoundedRect:
                                         CGRectMake(1, 0, rect.size.width - 2, shadeH)
                                         cornerRadius:rect.size.width * 0.18];
    bottomShadeMask.path = bottomShadeMaskPath.CGPath;
    bottomShade.mask = bottomShadeMask;
    [wrapper addSublayer:bottomShade];

    // 橙色卡通描边
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = [kOrangeAccentColor() colorWithAlphaComponent:0.75].CGColor;
    stroke.lineWidth = 0.8;
    [wrapper addSublayer:stroke];

    // 光泽 3：主竖向高光（左 22% 位置，明显白光 → 金属圆柱反光核心）
    CAShapeLayer *verticalShine = [CAShapeLayer layer];
    UIBezierPath *vsPath = [UIBezierPath bezierPath];
    CGFloat vsX = rect.origin.x + rect.size.width * 0.22;
    [vsPath moveToPoint:CGPointMake(vsX, rect.origin.y + 6)];
    [vsPath addLineToPoint:CGPointMake(vsX, rect.origin.y + rect.size.height - 10)];
    verticalShine.path = vsPath.CGPath;
    verticalShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55].CGColor;
    verticalShine.lineWidth = 2.5;
    verticalShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:verticalShine];

    // 光泽 4：次级竖向反光（左 33% 位置，更淡更细 → 多层反光层次）
    CAShapeLayer *secondShine = [CAShapeLayer layer];
    UIBezierPath *ssPath = [UIBezierPath bezierPath];
    CGFloat ssX = rect.origin.x + rect.size.width * 0.35;
    [ssPath moveToPoint:CGPointMake(ssX, rect.origin.y + 10)];
    [ssPath addLineToPoint:CGPointMake(ssX, rect.origin.y + rect.size.height - 14)];
    secondShine.path = ssPath.CGPath;
    secondShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.22].CGColor;
    secondShine.lineWidth = 1.0;
    secondShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:secondShine];

    // 光泽 5：右侧暗边反光（紫色侧的边缘阴影 → 圆柱背光感）
    CAShapeLayer *darkEdge = [CAShapeLayer layer];
    UIBezierPath *dePath = [UIBezierPath bezierPath];
    CGFloat deX = rect.origin.x + rect.size.width * 0.88;
    [dePath moveToPoint:CGPointMake(deX, rect.origin.y + 8)];
    [dePath addLineToPoint:CGPointMake(deX, rect.origin.y + rect.size.height - 12)];
    darkEdge.path = dePath.CGPath;
    darkEdge.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.14].CGColor;
    darkEdge.lineWidth = 1.5;
    darkEdge.lineCap = kCALineCapRound;
    [wrapper addSublayer:darkEdge];

    // 机身两列铆钉（左右对称各 3 颗，小深色圆点 → 机体拼装感）
    CGFloat rivetLeftX = rect.origin.x + rect.size.width * 0.14;
    CGFloat rivetRightX = rect.origin.x + rect.size.width * 0.86;
    CGFloat rivetTopY = rect.origin.y + rect.size.height * 0.32;
    CGFloat rivetStep = rect.size.height * 0.18;
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat y = rivetTopY + i * rivetStep;
        for (NSInteger side = 0; side < 2; side++) {
            CGFloat x = (side == 0) ? rivetLeftX : rivetRightX;
            CAShapeLayer *rivet = [CAShapeLayer layer];
            rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                          CGRectMake(x - 1.0, y - 1.0, 2.0, 2.0)].CGPath;
            rivet.fillColor = [kRivetColor() colorWithAlphaComponent:0.55].CGColor;
            [wrapper addSublayer:rivet];
        }
    }

    return wrapper;
}

#pragma mark - 鼻锥 (Nose Cone)

+ (CALayer *)noseConeLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;

    // 鼻锥轮廓：上尖下宽圆润尖顶
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(rect.origin.x + 1, rect.origin.y + H)];
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W / 2.0, rect.origin.y + 1)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.12, rect.origin.y + H * 0.25)];
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W - 1, rect.origin.y + H)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.88, rect.origin.y + H * 0.25)];
    [path closePath];

    // 红色渐变：左亮红 → 中橙红高光 → 右深红（立体感）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kNoseRedBrightColor().CGColor,  // 0.05 亮红橙
        (id)kNoseRedColor().CGColor,        // 0.45 经典红
        (id)kNoseRedDarkColor().CGColor,    // 0.95 深红
    ];
    gradient.locations = @[@(0.05), @(0.45), @(0.95)];
    gradient.startPoint = CGPointMake(0.0, 0.2);
    gradient.endPoint = CGPointMake(1.0, 0.8);  // 斜向（左上亮，右下暗）

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-rect.origin.x, -rect.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(path.CGPath, &t);
    gradient.mask = mask;

    // 外层 wrapper
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + W, rect.origin.y + H);
    [wrapper addSublayer:gradient];

    // 细节 1：顶部白色高光（长弧，强调顶端反光）
    CAShapeLayer *topShine = [CAShapeLayer layer];
    UIBezierPath *tsPath = [UIBezierPath bezierPath];
    [tsPath moveToPoint:CGPointMake(rect.origin.x + W * 0.38, rect.origin.y + H * 0.35)];
    [tsPath addQuadCurveToPoint:CGPointMake(rect.origin.x + W * 0.50, rect.origin.y + 2)
                   controlPoint:CGPointMake(rect.origin.x + W * 0.40, rect.origin.y + H * 0.12)];
    topShine.path = tsPath.CGPath;
    topShine.fillColor = [UIColor clearColor].CGColor;
    topShine.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.82].CGColor;
    topShine.lineWidth = 1.6;
    topShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:topShine];

    // 细节 2：侧边小高光（右侧一道小白线，金属反光）
    CAShapeLayer *sideShine = [CAShapeLayer layer];
    UIBezierPath *ssPath = [UIBezierPath bezierPath];
    [ssPath moveToPoint:CGPointMake(rect.origin.x + W * 0.66, rect.origin.y + H * 0.55)];
    [ssPath addLineToPoint:CGPointMake(rect.origin.x + W * 0.68, rect.origin.y + H * 0.78)];
    sideShine.path = ssPath.CGPath;
    sideShine.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
    sideShine.lineWidth = 1.0;
    sideShine.lineCap = kCALineCapRound;
    [wrapper addSublayer:sideShine];

    // 细节 3：底部分界线（锥盖接缝 → 机身和鼻锥的"衔接环"）
    CAShapeLayer *seam = [CAShapeLayer layer];
    UIBezierPath *seamPath = [UIBezierPath bezierPath];
    [seamPath moveToPoint:CGPointMake(rect.origin.x + 3, rect.origin.y + H - 1.5)];
    [seamPath addLineToPoint:CGPointMake(rect.origin.x + W - 3, rect.origin.y + H - 1.5)];
    seam.path = seamPath.CGPath;
    seam.strokeColor = kNoseSeamColor().CGColor;
    seam.lineWidth = 1.8;
    seam.lineCap = kCALineCapRound;
    [wrapper addSublayer:seam];

    // 细节 4：接缝铆钉（左右两个小圆点）
    CGFloat rivetY = rect.origin.y + H - 1.5;
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat rivetX = rect.origin.x + (i == 0 ? W * 0.22 : W * 0.78);
        CAShapeLayer *rivet = [CAShapeLayer layer];
        rivet.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(rivetX - 1.2, rivetY - 1.2, 2.4, 2.4)].CGPath;
        rivet.fillColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
        [wrapper addSublayer:rivet];
    }

    // 细节 5：鼻锥外描边（深红勾边 → 卡通质感）
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = [kNoseRedDarkColor() colorWithAlphaComponent:0.9].CGColor;
    stroke.lineWidth = 1.0;
    [wrapper addSublayer:stroke];

    return wrapper;
}

#pragma mark - 舷窗 (Window)

/// 舷窗层级（由外向内）：
///   外层：紫色描边的蓝色玻璃圆
///   头像层（如有）：圆形裁剪的发送者头像，alpha 0.78（玻璃后透出的感觉）
///   玻璃覆膜：蓝色半透明覆盖（玻璃质感）
///   高光：左上角白色小圆（玻璃反光）
+ (CALayer *)windowLayerAtCenter:(CGPoint)center radius:(CGFloat)r avatarImage:(nullable UIImage *)avatarImage {
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(center.x - r - 2, center.y - r - 2, (r + 2) * 2, (r + 2) * 2);

    // 外层：蓝色玻璃圆 + 紫色描边
    CAShapeLayer *glass = [CAShapeLayer layer];
    glass.path = [UIBezierPath bezierPathWithOvalInRect:
                  CGRectMake(2, 2, r * 2, r * 2)].CGPath;
    glass.fillColor = kWindowBlueColor().CGColor;
    glass.strokeColor = kAccentPurpleColor().CGColor;
    glass.lineWidth = 2.5;
    [wrapper addSublayer:glass];

    if (avatarImage) {
        CALayer *avatar = [CALayer layer];
        CGFloat avatarDiameter = (r - 1.0) * 2;
        avatar.frame = CGRectMake(3.0, 3.0, avatarDiameter, avatarDiameter);
        avatar.contents = (__bridge id)avatarImage.CGImage;
        avatar.contentsGravity = kCAGravityResizeAspectFill;
        avatar.masksToBounds = YES;
        avatar.cornerRadius = avatarDiameter / 2.0;
        avatar.opacity = 0.78;
        [wrapper addSublayer:avatar];

        // 玻璃覆膜：蓝色半透 → 头像像在蓝色玻璃后面
        CAShapeLayer *tint = [CAShapeLayer layer];
        tint.path = [UIBezierPath bezierPathWithOvalInRect:
                     CGRectMake(3.0, 3.0, avatarDiameter, avatarDiameter)].CGPath;
        tint.fillColor = [kWindowBlueColor() colorWithAlphaComponent:0.38].CGColor;
        [wrapper addSublayer:tint];
    } else {
        // 无头像：深蓝内圈（普通舷窗）
        CAShapeLayer *inner = [CAShapeLayer layer];
        inner.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(5, 5, (r - 1.5) * 2, (r - 1.5) * 2)].CGPath;
        inner.fillColor = kWindowDeepColor().CGColor;
        [wrapper addSublayer:inner];
    }

    // 玻璃光泽扫过动画（蓄势阶段触发，模拟光线划过玻璃表面）
    CAShapeLayer *shimmerMask = [CAShapeLayer layer];
    shimmerMask.path = [UIBezierPath bezierPathWithOvalInRect:
                        CGRectMake(2, 2, r * 2, r * 2)].CGPath;

    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.frame = wrapper.bounds;
    shimmer.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.85].CGColor,
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor clearColor].CGColor,
    ];
    shimmer.locations = @[@(-0.3), @(-0.2), @(-0.1), @(0.0), @(0.1)];
    shimmer.startPoint = CGPointMake(0.05, 0.05);
    shimmer.endPoint = CGPointMake(0.95, 0.95);
    shimmer.mask = shimmerMask;
    shimmer.name = @"window-shimmer";   // 供 playInView 后续查找并挂载扫光动画
    [wrapper addSublayer:shimmer];

    // ⚠️ 扫光动画不在这里挂 —— 本方法在 rocketView 还未加入 view 层级时调用，
    // 此时 layer 尚无本地时间坐标系，CACurrentMediaTime() + delay 会与 layer attach
    // 后的本地时间错位，导致 sweep1（短延迟）可能直接被跳过。
    // 真正的挂载在 playInView: 里 addSubview 之后用 dispatch_after 触发。

    // 左上角白色静态高光（玻璃反光） — 仅无头像时显示
    // 有头像时这个点会遮住头像左上角区域，且 shimmer 扫光已足够表现玻璃质感
    if (!avatarImage) {
        CAShapeLayer *shine = [CAShapeLayer layer];
        CGFloat sr = r * 0.30;
        shine.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(r * 0.30, r * 0.30, sr * 2, sr * 2)].CGPath;
        shine.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75].CGColor;
        [wrapper addSublayer:shine];
    }

    // 舷窗外圈 4 颗小螺丝（斜向位置 + 轻微随机偏移 → 自然不呆板）
    // 舷窗几何中心 = (r+2, r+2)（wrapper 坐标系），螺丝分布在 r+0.5 半径圆上
    CGFloat screwRadius = 1.1;
    CGFloat ringR = r + 0.5;
    CGFloat cx = r + 2.0;
    CGFloat cy = r + 2.0;
    // 四个斜方向 + 每个方向略微不对称偏移（打破完美对称）
    CGFloat angles[4] = {
        -3.0 * M_PI_4 + 0.08,   // 左上（略偏上）
        -M_PI_4 - 0.10,         // 右上（略偏右）
        3.0 * M_PI_4 - 0.06,    // 左下（略偏下）
        M_PI_4 + 0.12           // 右下（略偏下）
    };
    for (NSInteger i = 0; i < 4; i++) {
        CGFloat sx = cx + ringR * cos(angles[i]);
        CGFloat sy = cy + ringR * sin(angles[i]);
        CAShapeLayer *screw = [CAShapeLayer layer];
        screw.path = [UIBezierPath bezierPathWithOvalInRect:
                      CGRectMake(sx - screwRadius, sy - screwRadius,
                                 screwRadius * 2, screwRadius * 2)].CGPath;
        screw.fillColor = [kAccentPurpleColor() colorWithAlphaComponent:0.9].CGColor;
        screw.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7].CGColor;
        screw.lineWidth = 0.4;
        [wrapper addSublayer:screw];
    }

    return wrapper;
}

/// 兼容旧调用（无头像 → 普通舷窗外观）
+ (CALayer *)windowLayerAtCenter:(CGPoint)center radius:(CGFloat)r {
    return [self windowLayerAtCenter:center radius:r avatarImage:nil];
}

#pragma mark - Octo 文字（金属质感）

/// Octo 文字：三层叠加 → 金属刻字质感
///   底层：黑色阴影文字（下偏 0.8pt → 压印感）
///   主层：紫色渐变 mask 填充的文字（顶亮底暗 → 3D 立体）
///   顶层：白色高光（clip 到上半部分 → 反光）
+ (CALayer *)octoLabelCenteredAt:(CGPoint)center {
    CGFloat fontSize = 11.0;
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightHeavy];
    CGSize size = CGSizeMake(44, fontSize + 4);
    CGRect frame = CGRectMake(center.x - size.width / 2.0, center.y - size.height / 2.0,
                              size.width, size.height);

    CALayer *container = [CALayer layer];
    container.frame = frame;
    container.contentsScale = [UIScreen mainScreen].scale;

    // --- 1. 底层阴影文字（深色，下偏 0.8pt 形成压印）---
    CATextLayer *shadow = [CATextLayer layer];
    shadow.contentsScale = [UIScreen mainScreen].scale;
    shadow.alignmentMode = kCAAlignmentCenter;
    shadow.font = (__bridge CFTypeRef)(font.fontName);
    shadow.fontSize = fontSize;
    shadow.foregroundColor = [UIColor colorWithRed:0.04 green:0.02 blue:0.12 alpha:0.55].CGColor;
    shadow.string = [[NSAttributedString alloc] initWithString:@"Octo" attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.04 green:0.02 blue:0.12 alpha:0.55],
        NSKernAttributeName: @(0.8),
    }];
    shadow.frame = CGRectMake(0, 1.0, size.width, size.height);
    [container addSublayer:shadow];

    // --- 2. 主层：渐变填充的文字（用文字作为 mask，gradient 透过文字显示）---
    //     顶部浅紫 → 中部主紫 → 底部深紫  → 金属文字立体感
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 0, size.width, size.height);
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.58 green:0.52 blue:0.85 alpha:1.0].CGColor,  // 顶：浅靛紫 (#948AD9)
        (id)[UIColor colorWithRed:0.35 green:0.25 blue:0.68 alpha:1.0].CGColor,  // 中：皇家靛 (#5940AD)
        (id)[UIColor colorWithRed:0.15 green:0.08 blue:0.38 alpha:1.0].CGColor,  // 底：深靛蓝 (#261461)
    ];
    gradient.locations = @[@(0.0), @(0.5), @(1.0)];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    // mask 层：白色文字 → 渐变在文字形状内显示
    CATextLayer *maskText = [CATextLayer layer];
    maskText.contentsScale = [UIScreen mainScreen].scale;
    maskText.alignmentMode = kCAAlignmentCenter;
    maskText.font = (__bridge CFTypeRef)(font.fontName);
    maskText.fontSize = fontSize;
    maskText.foregroundColor = [UIColor whiteColor].CGColor;  // mask 只看 alpha
    maskText.string = [[NSAttributedString alloc] initWithString:@"Octo" attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSKernAttributeName: @(0.8),
    }];
    maskText.frame = gradient.bounds;
    gradient.mask = maskText;
    [container addSublayer:gradient];

    // --- 3. 顶层高光：白色文字 + 顶部 50% clip mask（上半部更亮的金属反光）---
    CATextLayer *shine = [CATextLayer layer];
    shine.contentsScale = [UIScreen mainScreen].scale;
    shine.alignmentMode = kCAAlignmentCenter;
    shine.font = (__bridge CFTypeRef)(font.fontName);
    shine.fontSize = fontSize;
    shine.foregroundColor = [UIColor colorWithRed:0.92 green:0.90 blue:1.0 alpha:0.55].CGColor;
    shine.string = [[NSAttributedString alloc] initWithString:@"Octo" attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor colorWithRed:0.92 green:0.90 blue:1.0 alpha:0.55],
        NSKernAttributeName: @(0.8),
    }];
    shine.frame = CGRectMake(0, 0, size.width, size.height);

    // Clip 上半部分（用一个半高的黑色矩形 layer 作为 mask）
    CALayer *shineClip = [CALayer layer];
    shineClip.frame = CGRectMake(0, 0, size.width, size.height * 0.45);
    shineClip.backgroundColor = [UIColor whiteColor].CGColor;
    shine.mask = shineClip;
    [container addSublayer:shine];

    return container;
}

#pragma mark - 尾翼 (Fins)

/// 左右尾翼：月牙形（狼牙状）— 外沿大弧突出，内沿微凹贴合机身，上下端收尖。
/// 渐变填色 + 外沿白色高光弧 → 3D 月牙感，不是简笔画。
+ (CALayer *)finLayerLeft:(BOOL)isLeft bodyRect:(CGRect)bodyRect {
    CGFloat bodyBottom = bodyRect.origin.y + bodyRect.size.height;
    CGFloat finH = 32.0;                                // 尾翼总高度（上下端收尖距离）
    CGFloat finW = bodyRect.size.width * 0.48;          // 外沿外扩量
    CGFloat topYTuck = 8.0;                             // 顶端嵌入机身深度

    UIBezierPath *p = [UIBezierPath bezierPath];
    if (isLeft) {
        // 左翼月牙：顶端贴机身上 → 外弧下凸 → 底端贴机身下 → 内弧回上（微凹）
        CGFloat topX    = bodyRect.origin.x + 5.0;              // 顶端贴机身
        CGFloat topY    = bodyBottom - finH + topYTuck;
        CGFloat bottomX = bodyRect.origin.x + 2.0;              // 底端贴机身
        CGFloat bottomY = bodyBottom - 1.0;
        CGFloat outerTipX = bodyRect.origin.x - finW + 3.0;     // 翼尖最外侧
        CGFloat outerTipY = bodyBottom - 2.0;

        [p moveToPoint:CGPointMake(topX, topY)];
        // 外弧 1：顶端 → 翼尖（大弧，明显向外下凸）
        [p addQuadCurveToPoint:CGPointMake(outerTipX, outerTipY)
                  controlPoint:CGPointMake(topX - finW * 0.95, topY + finH * 0.35)];
        // 外弧 2：翼尖 → 底端（圆润收回到机身）
        [p addQuadCurveToPoint:CGPointMake(bottomX, bottomY)
                  controlPoint:CGPointMake(outerTipX + finW * 0.25, bottomY + 2.0)];
        // 内弧：底端 → 顶端（贴机身一侧，微凹向机身内）
        [p addQuadCurveToPoint:CGPointMake(topX, topY)
                  controlPoint:CGPointMake(topX + 3.0, (topY + bottomY) / 2.0 + 2.0)];
    } else {
        CGFloat topX    = bodyRect.origin.x + bodyRect.size.width - 5.0;
        CGFloat topY    = bodyBottom - finH + topYTuck;
        CGFloat bottomX = bodyRect.origin.x + bodyRect.size.width - 2.0;
        CGFloat bottomY = bodyBottom - 1.0;
        CGFloat outerTipX = bodyRect.origin.x + bodyRect.size.width + finW - 3.0;
        CGFloat outerTipY = bodyBottom - 2.0;

        [p moveToPoint:CGPointMake(topX, topY)];
        [p addQuadCurveToPoint:CGPointMake(outerTipX, outerTipY)
                  controlPoint:CGPointMake(topX + finW * 0.95, topY + finH * 0.35)];
        [p addQuadCurveToPoint:CGPointMake(bottomX, bottomY)
                  controlPoint:CGPointMake(outerTipX - finW * 0.25, bottomY + 2.0)];
        [p addQuadCurveToPoint:CGPointMake(topX, topY)
                  controlPoint:CGPointMake(topX - 3.0, (topY + bottomY) / 2.0 + 2.0)];
    }

    // 用渐变 mask 填色：顶端亮紫 → 底端深紫（月牙内侧明暗过渡，立体感）
    CGRect finBounds = CGPathGetBoundingBox(p.CGPath);
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = finBounds;
    gradient.colors = @[
        (id)kBodyPurpleColor().CGColor,    // 顶：紫粉（亮）
        (id)kAccentPurpleColor().CGColor,  // 中：深紫
        (id)kNoseRedDarkColor().CGColor,   // 底：暗红（火焰照亮）
    ];
    gradient.locations = @[@(0.0), @(0.55), @(1.0)];
    // 左翼亮面朝右上（机身方向），右翼亮面朝左上（镜像）
    gradient.startPoint = isLeft ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
    gradient.endPoint   = isLeft ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-finBounds.origin.x, -finBounds.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(p.CGPath, &t);
    gradient.mask = mask;

    // Wrapper 叠加所有装饰层
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, finBounds.origin.x + finBounds.size.width,
                               finBounds.origin.y + finBounds.size.height);
    [wrapper addSublayer:gradient];

    // 细节 1：外沿橙色勾边（卡通感 + 参照图片橙色描边）
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = p.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = kOrangeAccentColor().CGColor;
    stroke.lineWidth = 1.1;
    stroke.lineJoin = kCALineJoinRound;
    [wrapper addSublayer:stroke];

    // 细节 2：沿外沿的高光弧（月牙顶部亮线 → 3D 弧面感）
    CAShapeLayer *highlight = [CAShapeLayer layer];
    UIBezierPath *hlPath = [UIBezierPath bezierPath];
    if (isLeft) {
        CGFloat hlTopX = bodyRect.origin.x + 3.0;
        CGFloat hlTopY = bodyBottom - finH + topYTuck + 2.0;
        CGFloat hlTipX = bodyRect.origin.x - finW * 0.85;
        CGFloat hlTipY = bodyBottom - 4.0;
        [hlPath moveToPoint:CGPointMake(hlTopX, hlTopY)];
        [hlPath addQuadCurveToPoint:CGPointMake(hlTipX, hlTipY)
                       controlPoint:CGPointMake(hlTopX - finW * 0.8, hlTopY + finH * 0.25)];
    } else {
        CGFloat hlTopX = bodyRect.origin.x + bodyRect.size.width - 3.0;
        CGFloat hlTopY = bodyBottom - finH + topYTuck + 2.0;
        CGFloat hlTipX = bodyRect.origin.x + bodyRect.size.width + finW * 0.85;
        CGFloat hlTipY = bodyBottom - 4.0;
        [hlPath moveToPoint:CGPointMake(hlTopX, hlTopY)];
        [hlPath addQuadCurveToPoint:CGPointMake(hlTipX, hlTipY)
                       controlPoint:CGPointMake(hlTopX + finW * 0.8, hlTopY + finH * 0.25)];
    }
    highlight.path = hlPath.CGPath;
    highlight.fillColor = [UIColor clearColor].CGColor;
    highlight.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;
    highlight.lineWidth = 1.2;
    highlight.lineCap = kCALineCapRound;
    [wrapper addSublayer:highlight];

    // 用 CAShapeLayer 包装返回（兼容原签名）
    CAShapeLayer *holder = [CAShapeLayer layer];
    [holder addSublayer:wrapper];
    return holder;
}

/// 中尾翼：机身底部中央的小三角形稳定翼（呼应图片里的第三个尾翼）
+ (CAShapeLayer *)centerFinLayerInBodyRect:(CGRect)bodyRect nozzleRect:(CGRect)nozzleRect {
    CGFloat bodyBottom = bodyRect.origin.y + bodyRect.size.height;
    CGFloat centerX = bodyRect.origin.x + bodyRect.size.width / 2.0;
    CGFloat finWidth = bodyRect.size.width * 0.28;   // 比左右翼窄
    CGFloat finHeight = 20.0;                         // 向下延伸（延伸到喷口范围）
    CGFloat topY = bodyBottom - 8.0;                  // 顶部略嵌入机身内
    CGFloat tipY = nozzleRect.origin.y + nozzleRect.size.height - 2.0; // 尖端到喷口底部

    UIBezierPath *p = [UIBezierPath bezierPath];
    // 倒三角：机身底部两侧 → 尖端向下
    [p moveToPoint:CGPointMake(centerX - finWidth / 2.0, topY)];
    [p addQuadCurveToPoint:CGPointMake(centerX, tipY)
              controlPoint:CGPointMake(centerX - finWidth * 0.25, topY + finHeight * 0.6)];
    [p addQuadCurveToPoint:CGPointMake(centerX + finWidth / 2.0, topY)
              controlPoint:CGPointMake(centerX + finWidth * 0.25, topY + finHeight * 0.6)];
    // 顶缘圆润（贴机身底部弧度）
    [p addQuadCurveToPoint:CGPointMake(centerX - finWidth / 2.0, topY)
              controlPoint:CGPointMake(centerX, topY - 1.0)];
    [p closePath];

    // 用 gradient mask 做青→紫的垂直渐变（呼应图里的中翼颜色）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    CGRect finBounds = CGPathGetBoundingBox(p.CGPath);
    gradient.frame = finBounds;
    gradient.colors = @[
        (id)kAccentCyanColor().CGColor,   // 顶：青
        (id)kAccentPurpleColor().CGColor, // 底：紫
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    CAShapeLayer *mask = [CAShapeLayer layer];
    CGAffineTransform t = CGAffineTransformMakeTranslation(-finBounds.origin.x, -finBounds.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(p.CGPath, &t);
    gradient.mask = mask;

    // 外层 wrapper：在 gradient 之上加橙色描边（卡通勾边）
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, finBounds.origin.x + finBounds.size.width,
                               finBounds.origin.y + finBounds.size.height);
    [wrapper addSublayer:gradient];

    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = p.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = kOrangeAccentColor().CGColor;
    stroke.lineWidth = 1.0;
    stroke.lineJoin = kCALineJoinRound;
    [wrapper addSublayer:stroke];

    // 包一层 CAShapeLayer 便于统一返回（虽然内容是 wrapper 的 sublayer）
    CAShapeLayer *holder = [CAShapeLayer layer];
    [holder addSublayer:wrapper];
    return holder;
}

#pragma mark - 喷口 (Nozzle)

+ (CAShapeLayer *)nozzleLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;
    CGFloat topInset    = W * (1 - 0.55) / 2.0;
    CGFloat bottomInset = W * (1 - 0.70) / 2.0;

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(rect.origin.x + topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - bottomInset, rect.origin.y + H)];
    [p addLineToPoint:CGPointMake(rect.origin.x + bottomInset, rect.origin.y + H)];
    [p closePath];

    CAShapeLayer *nozzle = [CAShapeLayer layer];
    nozzle.path = p.CGPath;
    nozzle.fillColor = kNozzleColor().CGColor;
    nozzle.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.35].CGColor;
    nozzle.lineWidth = 0.6;

    // 细节 1：顶部接缝线（喷口和机身的金属接合处）
    CAShapeLayer *topSeam = [CAShapeLayer layer];
    UIBezierPath *tsPath = [UIBezierPath bezierPath];
    [tsPath moveToPoint:CGPointMake(rect.origin.x + topInset + 1, rect.origin.y + 0.8)];
    [tsPath addLineToPoint:CGPointMake(rect.origin.x + W - topInset - 1, rect.origin.y + 0.8)];
    topSeam.path = tsPath.CGPath;
    topSeam.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
    topSeam.lineWidth = 1.0;
    [nozzle addSublayer:topSeam];

    // 细节 2：喷口内暗环（模拟喷口内部烧黑）— 底部接近尾焰处的深色带
    CAShapeLayer *innerDark = [CAShapeLayer layer];
    UIBezierPath *idPath = [UIBezierPath bezierPath];
    [idPath moveToPoint:CGPointMake(rect.origin.x + bottomInset + 1, rect.origin.y + H - 1)];
    [idPath addLineToPoint:CGPointMake(rect.origin.x + W - bottomInset - 1, rect.origin.y + H - 1)];
    innerDark.path = idPath.CGPath;
    innerDark.strokeColor = [[UIColor blackColor] colorWithAlphaComponent:0.55].CGColor;
    innerDark.lineWidth = 1.4;
    [nozzle addSublayer:innerDark];

    return nozzle;
}

#pragma mark - 水滴形火焰（实体 CAShapeLayer，始终垂直向下）

/// 细长水滴形：尖端朝下，橙→黄→白热三层色。anchorPoint 在顶部中心
/// → scale.y 拉伸时从喷口向下延伸（上端不动，下端变长/短）。
+ (CALayer *)coreFlameLayer {
    CGFloat W = kRocketWidth * 0.36;   // 基础宽度（阶段过渡用 scale.x 调整）
    CGFloat H = kRocketWidth * 1.10;   // 基础长度（阶段过渡用 scale.y 调整）

    // 外层：橙色水滴
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(0, 0)];
    [path addQuadCurveToPoint:CGPointMake(W * 0.5, H)
                 controlPoint:CGPointMake(W * 0.08, H * 0.6)];
    [path addQuadCurveToPoint:CGPointMake(W, 0)
                 controlPoint:CGPointMake(W * 0.92, H * 0.6)];
    [path closePath];

    CAShapeLayer *shape = [CAShapeLayer layer];
    shape.path = path.CGPath;
    shape.fillColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0].CGColor;  // 外层橙
    shape.bounds = CGRectMake(0, 0, W, H);
    shape.anchorPoint = CGPointMake(0.5, 0.0); // 顶部中点 = 锚点

    // 中层：黄色内焰
    CGFloat innerW = W * 0.55;
    CGFloat innerH = H * 0.80;
    UIBezierPath *innerPath = [UIBezierPath bezierPath];
    CGFloat ox = (W - innerW) / 2.0;
    CGFloat oy = H * 0.04;
    [innerPath moveToPoint:CGPointMake(ox, oy)];
    [innerPath addQuadCurveToPoint:CGPointMake(ox + innerW / 2.0, oy + innerH)
                      controlPoint:CGPointMake(ox + innerW * 0.08, oy + innerH * 0.6)];
    [innerPath addQuadCurveToPoint:CGPointMake(ox + innerW, oy)
                      controlPoint:CGPointMake(ox + innerW * 0.92, oy + innerH * 0.6)];
    [innerPath closePath];

    CAShapeLayer *inner = [CAShapeLayer layer];
    inner.path = innerPath.CGPath;
    inner.fillColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.25 alpha:0.98].CGColor;  // 黄
    [shape addSublayer:inner];

    // 最内：白热高光
    CGFloat hotW = innerW * 0.55;
    CGFloat hotH = innerH * 0.45;
    CAShapeLayer *hot = [CAShapeLayer layer];
    hot.path = [UIBezierPath bezierPathWithRoundedRect:
                CGRectMake((W - hotW) / 2.0, H * 0.05, hotW, hotH)
                cornerRadius:hotW * 0.5].CGPath;
    hot.fillColor = [[UIColor colorWithWhite:1.0 alpha:0.85] CGColor];
    [shape addSublayer:hot];

    // 外光晕：紫蓝色 halo（呼应图片里火焰外的蓝紫拖尾）
    shape.shadowColor = [UIColor colorWithRed:0.55 green:0.45 blue:1.0 alpha:1.0].CGColor;
    shape.shadowOffset = CGSizeMake(0, 3);
    shape.shadowRadius = 9.0;
    shape.shadowOpacity = 0.85;

    return shape;
}

/// Y 方向 flicker 跳动（火焰闪烁）。values 围绕 base 波动 → 可动态调整基础长度。
+ (void)startFlickerOnLayer:(CALayer *)layer baseScale:(CGFloat)base {
    CAKeyframeAnimation *flicker = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];
    flicker.values = @[@(base * 1.0), @(base * 1.15), @(base * 0.92), @(base * 1.10), @(base * 0.96), @(base * 1.07), @(base * 1.0)];
    flicker.keyTimes = @[@0.0, @0.18, @0.32, @0.52, @0.68, @0.84, @1.0];
    flicker.duration = 0.22;
    flicker.repeatCount = HUGE_VALF;
    [layer addAnimation:flicker forKey:@"flame-flicker"];
}

/// X 方向宽度过渡（阶段切换时平滑改变横向宽度 — 不与 flicker.scale.y 冲突）。
+ (void)setCoreFlameScaleX:(CALayer *)layer toValue:(CGFloat)value duration:(NSTimeInterval)duration {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
    anim.fromValue = [layer.presentationLayer valueForKeyPath:@"transform.scale.x"] ?: @(1.0);
    anim.toValue = @(value);
    anim.duration = duration;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.fillMode = kCAFillModeForwards;
    anim.removedOnCompletion = NO;
    [layer addAnimation:anim forKey:@"flame-scale-x"];
}

#pragma mark - 拖尾星星纹理

+ (UIImage *)starParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 22;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        // 四角星形：两条对角线 + 十字
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.95 blue:0.6 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGFloat c = size / 2.0;
        CGFloat r = size / 2.0 - 1.0;
        CGContextMoveToPoint(ctx, c - r, c);
        CGContextAddLineToPoint(ctx, c + r, c);
        CGContextMoveToPoint(ctx, c, c - r);
        CGContextAddLineToPoint(ctx, c, c + r);
        CGContextStrokePath(ctx);
        // 中心亮点
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(c - 2, c - 2, 4, 4));

        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

#pragma mark - 工具动画

+ (void)applyEngineShakeToView:(UIView *)view duration:(NSTimeInterval)duration {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@(-2), @(2), @(-1.5), @(1.5), @(-1), @(1), @(0)];
    shake.duration = duration / 6.0;
    shake.repeatCount = 6;
    shake.additive = YES;
    [view.layer addAnimation:shake forKey:@"engine-shake"];
}



#pragma mark - 拖尾星星粒子

+ (void)scatterSparkleStarsAlongPathFrom:(CGPoint)start to:(CGPoint)midEnd inView:(UIView *)host {
    // 沿升空方向向上平均分布 4 颗星星（从 midEnd 开始继续向上）
    UIImage *starImg = [self starParticleImage];
    CGFloat pathLength = 140.0;
    NSInteger count = 4;

    for (NSInteger i = 0; i < count; i++) {
        CGFloat t = (CGFloat)(i + 1) / (CGFloat)count;
        CGFloat x = midEnd.x + ((CGFloat)arc4random_uniform(40) - 20);
        CGFloat y = midEnd.y - pathLength * t;

        UIImageView *star = [[UIImageView alloc] initWithImage:starImg];
        star.center = CGPointMake(x, y);
        star.alpha = 0;
        star.transform = CGAffineTransformMakeScale(0.3, 0.3);
        [host addSubview:star];

        NSTimeInterval delay = i * 0.08;
        [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveEaseOut animations:^{
            star.alpha = 1.0;
            star.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.4 delay:0.1 options:UIViewAnimationOptionCurveEaseIn animations:^{
                star.alpha = 0;
                star.transform = CGAffineTransformMakeScale(0.1, 0.1);
            } completion:^(BOOL f) {
                [star removeFromSuperview];
            }];
        }];
    }
}

#pragma mark - Helpers

+ (nullable CALayer *)findLayerWithName:(NSString *)name inLayer:(CALayer *)root {
    if (!name || !root) return nil;
    if ([root.name isEqualToString:name]) return root;
    for (CALayer *sub in root.sublayers) {
        CALayer *found = [self findLayerWithName:name inLayer:sub];
        if (found) return found;
    }
    return nil;
}

@end
