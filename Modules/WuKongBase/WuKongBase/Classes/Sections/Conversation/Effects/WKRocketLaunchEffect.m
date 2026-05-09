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

static const CGFloat kRocketWidth  = 55.0;
static const CGFloat kRocketHeight = 120.0;

// 颜色（SpaceX 风格：白机身 + 红点缀 + 深石板蓝灰文字）
static UIColor *kBodyLightColor(void)   { return [UIColor whiteColor]; }
static UIColor *kBodyShadeColor(void)   { return [UIColor colorWithWhite:0.82 alpha:1.0]; }
static UIColor *kAccentRedColor(void)   { return [UIColor colorWithRed:0xE7/255.0 green:0x4C/255.0 blue:0x3C/255.0 alpha:1.0]; }
static UIColor *kAccentDarkRedColor(void) { return [UIColor colorWithRed:0xC0/255.0 green:0x39/255.0 blue:0x2B/255.0 alpha:1.0]; }
static UIColor *kGlassColor(void)       { return [UIColor colorWithRed:0x9A/255.0 green:0xEC/255.0 blue:0xDB/255.0 alpha:1.0]; }
static UIColor *kGlassDeepColor(void)   { return [UIColor colorWithRed:0x7A/255.0 green:0xDD/255.0 blue:0xC0/255.0 alpha:1.0]; }
static UIColor *kTextColor(void)        { return [UIColor colorWithRed:0x2C/255.0 green:0x3E/255.0 blue:0x50/255.0 alpha:1.0]; }
static UIColor *kNozzleColor(void)      { return [UIColor colorWithRed:0x34/255.0 green:0x49/255.0 blue:0x5E/255.0 alpha:1.0]; }

#pragma mark - 主入口

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
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
    UIView *rocketView = [self buildRocketViewWithSize:CGSizeMake(kRocketWidth, kRocketHeight)];
    rocketView.center = origin;
    rocketView.transform = CGAffineTransformMakeScale(0.001, 0.001);
    [effectView addSubview:rocketView];

    // 机身子容器（shake 只作用于此，避免传递给火焰导致"歪"）
    UIView *bodyContainer = [rocketView viewWithTag:1001];

    // 水滴形火焰（实体 CAShapeLayer）：尖端朝下，始终贴在火箭尾部垂直向下
    // 通过 scale.x / scale.y 的阶段动画实现蓄势→发射的形态变化：
    //   - 蓄势：X 放大 Y 压缩 → 宽胖短（待机火球）
    //   - 升空：X 中等 Y 拉长 → 中等细长
    //   - 发射：X 收窄 Y 最长 → 窄长喷射
    CALayer *coreFlame = [self coreFlameLayer];
    coreFlame.position = CGPointMake(kRocketWidth / 2.0, kRocketHeight);
    coreFlame.opacity = 0;
    [rocketView.layer addSublayer:coreFlame];

    // 烟雾云（**不跟随火箭**）：覆盖屏幕全宽，强化视觉冲击
    // 用 SpriteKit + SKFieldNode（湍流场 + 噪声场）产生真实的烟雾翻滚效果。
    // 火箭升空后停止喷射，已有粒子继续受场力翻滚并自然淡出。
    CGFloat cloudW = viewW;                          // 全屏宽
    CGFloat cloudH = kRocketHeight * 2.2;            // 扩散区高度
    CGRect cloudFrame = CGRectMake(0,
                                   origin.y + kRocketHeight / 2.0 - cloudH * 0.5,
                                   cloudW, cloudH);
    WKRocketSmokeCloud *smokeCloud = [[WKRocketSmokeCloud alloc] initWithFrame:cloudFrame];
    [effectView insertSubview:smokeCloud belowSubview:rocketView];

    // 喷口位置转换到 smokeCloud 局部坐标
    CGPoint nozzleInCloud = [effectView convertPoint:CGPointMake(origin.x, origin.y + kRocketHeight / 2.0 - 4.0)
                                              toView:smokeCloud];
    [smokeCloud startEmittingAtNozzlePoint:nozzleInCloud spread:kRocketWidth * 0.45];

    // === 动画编排 ===
    // 时间轴：0.0 入场 → 0.3 引擎点火蓄势 → 1.1 缓缓升空 → 1.9 加速发射 → 3.4 停喷 → 4.2 清理
    // 喷射流的 scale / velocity 在各阶段用 CABasicAnimation 平滑过渡（符合空气动力学渐变）。

    // 阶段 1：入场（0.0~0.3s）spring 弹出
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        rocketView.transform = CGAffineTransformIdentity;
    } completion:nil];

    // 阶段 2：引擎点火蓄势（0.25s 点火 → 持续到 1.1s）
    // 蓄势阶段：火焰宽、胖、短（待机火球感）；烟雾温和涌出。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 火焰点亮 + 形态：宽（X 1.35）短（Y 围绕 0.65 跳动） → 胖矮火球
        coreFlame.opacity = 1.0;
        [self setCoreFlameScaleX:coreFlame toValue:1.35 duration:0.25];
        [self startFlickerOnLayer:coreFlame baseScale:0.65];

        // 烟雾：蓄势强度 1.0（明显一点）
        [smokeCloud setIntensity:1.0];

        // 机身震动（只作用于 bodyContainer，不影响火焰）
        [self applyEngineShakeToView:bodyContainer duration:0.85];

        UIImpactFeedbackGenerator *light = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [light prepare];
        [light impactOccurred];
    });

    // 阶段 3：缓缓升空（1.1~1.9s）Y -80
    // 火焰过渡：宽短 → 中等细长
    __block CGPoint liftEndCenter = CGPointZero;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        liftEndCenter = CGPointMake(origin.x, origin.y - 80.0);
        [UIView animateWithDuration:0.8
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            rocketView.center = liftEndCenter;
        } completion:nil];

        // 火焰：X 收窄到 0.95，Y 拉长到 1.25
        [self setCoreFlameScaleX:coreFlame toValue:0.95 duration:0.5];
        [coreFlame removeAnimationForKey:@"flame-flicker"];
        [self startFlickerOnLayer:coreFlame baseScale:1.25];

        // 烟雾：起飞瞬间峰值扰动
        [smokeCloud setIntensity:1.7];
    });

    // 阶段 4：加速发射（1.9~3.4s）飞出屏幕顶部
    // 火焰：最窄最长的喷射束
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CAMediaTimingFunction *power4 = [CAMediaTimingFunction functionWithControlPoints:0.5 :0.0 :1.0 :0.2];
        [CATransaction begin];
        [CATransaction setAnimationTimingFunction:power4];
        [UIView animateWithDuration:1.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            // 飞出终点 Y 必须足够远 → 机身 + 拉长的火焰 + shadow 都要在屏幕外
            // coreFlame 拉长到 baseScale 1.75 后约 106pt；预留更大空间避免残留
            rocketView.center = CGPointMake(liftEndCenter.x, -(kRocketHeight * 3) - 200);
        } completion:^(BOOL finished) {
            // 兜底：动画结束后主动隐藏 rocketView（及所有子 layer）
            // 防止系统动画提前结束或 timing 曲线导致的视觉残留
            rocketView.hidden = YES;
        }];
        [CATransaction commit];

        // 火焰：X 最窄 0.75，Y 最长 1.75
        [self setCoreFlameScaleX:coreFlame toValue:0.75 duration:0.35];
        [coreFlame removeAnimationForKey:@"flame-flicker"];
        [self startFlickerOnLayer:coreFlame baseScale:1.75];

        // 烟雾：强度衰减（火箭远离发射台）
        [smokeCloud setIntensity:0.55];

        UIImpactFeedbackGenerator *medium = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [medium prepare];
        [medium impactOccurred];
    });

    // 阶段 5：发射路径上留下 4 颗星星（3.0s 时播撒在升空路径上）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scatterSparkleStarsAlongPathFrom:origin to:liftEndCenter inView:effectView];
    });

    // 阶段 6：烟雾完全停止生成（2.8s 后已有粒子在场力下继续翻滚自然消散）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [smokeCloud stopEmitting];
    });

    // 阶段 7：清理（smokeCloud 自身负责清理粒子和 removeFromSuperview，不随 effectView 一起销毁也无碍）
    [effectView scheduleRemovalAfterDelay:4.2];
}

#pragma mark - 火箭视图组装

+ (UIView *)buildRocketViewWithSize:(CGSize)size {
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
    CGFloat noseH   = 32.0;                         // 鼻锥高度
    CGFloat nozzleH = 6.0;                          // 喷口高度
    CGFloat bodyTop = noseH;                        // 机身顶
    CGFloat bodyBottom = H - nozzleH;               // 机身底
    CGRect bodyRect = CGRectMake(0, bodyTop, W, bodyBottom - bodyTop);

    // 1. 机身（白→浅灰水平渐变模拟光照）
    CALayer *body = [self bodyLayerInRect:bodyRect];
    [bodyContainer.layer addSublayer:body];

    // 2. 鼻锥（红→深红垂直渐变）
    CALayer *nose = [self noseConeLayerInRect:CGRectMake(0, 0, W, noseH)];
    [bodyContainer.layer addSublayer:nose];

    // 3. 舷窗（机身上部，径向玻璃渐变 + 红描边 + 高光）
    CGFloat windowRadius = 10.0;
    CGPoint windowCenter = CGPointMake(W / 2.0, bodyTop + 16.0);
    CALayer *windowLayer = [self windowLayerAtCenter:windowCenter radius:windowRadius];
    [bodyContainer.layer addSublayer:windowLayer];

    // 4. "Octo" 文字（舷窗下方）
    CATextLayer *octo = [self octoLabelCenteredAt:CGPointMake(W / 2.0, bodyTop + 40.0)];
    [bodyContainer.layer addSublayer:octo];

    // 5. 红色装饰条带（机身下 1/3 处）
    CAShapeLayer *stripe = [CAShapeLayer layer];
    stripe.path = [UIBezierPath bezierPathWithRect:CGRectMake(3.5, bodyBottom - 22.0, W - 7.0, 3.0)].CGPath;
    stripe.fillColor = kAccentRedColor().CGColor;
    [bodyContainer.layer addSublayer:stripe];

    // 6. 左右尾翼（从机身底部向外斜下）
    CAShapeLayer *finL = [self finLayerLeft:YES bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finL];
    CAShapeLayer *finR = [self finLayerLeft:NO bodyRect:bodyRect];
    [bodyContainer.layer addSublayer:finR];

    // 7. 喷口（倒梯形）
    CAShapeLayer *nozzle = [self nozzleLayerInRect:CGRectMake(0, bodyBottom, W, nozzleH)];
    [bodyContainer.layer addSublayer:nozzle];

    return container;
}

#pragma mark - 机身 (Body)

+ (CALayer *)bodyLayerInRect:(CGRect)rect {
    // 机身外形：圆角胶囊形（上下都圆角，左右直边）
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:
                          CGRectMake(rect.origin.x + 1, rect.origin.y, rect.size.width - 2, rect.size.height)
                          cornerRadius:rect.size.width * 0.18];

    // 渐变层（左白→右浅灰，模拟光照）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kBodyLightColor().CGColor,
        (id)kBodyLightColor().CGColor,
        (id)kBodyShadeColor().CGColor,
    ];
    gradient.locations = @[@(0.0), @(0.5), @(1.0)];
    gradient.startPoint = CGPointMake(0.0, 0.5);
    gradient.endPoint = CGPointMake(1.0, 0.5);

    // 用形状做 mask
    CAShapeLayer *mask = [CAShapeLayer layer];
    // mask 的坐标系是相对 gradient.bounds，需要把 path 平移到原点
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:
                              CGRectMake(1, 0, rect.size.width - 2, rect.size.height)
                              cornerRadius:rect.size.width * 0.18];
    mask.path = maskPath.CGPath;
    gradient.mask = mask;

    // 在外层包一个 wrapper，这样可以叠加一个细边描边（金属感）
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + rect.size.width, rect.origin.y + rect.size.height);
    [wrapper addSublayer:gradient];

    // 边缘描边
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.path = path.CGPath;
    stroke.fillColor = [UIColor clearColor].CGColor;
    stroke.strokeColor = [UIColor colorWithWhite:0.7 alpha:0.4].CGColor;
    stroke.lineWidth = 0.5;
    [wrapper addSublayer:stroke];

    return wrapper;
}

#pragma mark - 鼻锥 (Nose Cone)

+ (CALayer *)noseConeLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    CGFloat H = rect.size.height;

    // 鼻锥轮廓：上尖下宽，贝塞尔二次曲线形成圆润尖顶
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(rect.origin.x + 1, rect.origin.y + H)];
    // 左侧弧线 → 顶点
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W / 2.0, rect.origin.y + 1)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.12, rect.origin.y + H * 0.25)];
    // 顶点 → 右侧
    [path addQuadCurveToPoint:CGPointMake(rect.origin.x + W - 1, rect.origin.y + H)
                 controlPoint:CGPointMake(rect.origin.x + W * 0.88, rect.origin.y + H * 0.25)];
    [path closePath];

    // 渐变（红→深红，垂直）
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = @[
        (id)kAccentRedColor().CGColor,
        (id)kAccentDarkRedColor().CGColor,
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);

    CAShapeLayer *mask = [CAShapeLayer layer];
    // 把 path 转到以 rect.origin 为零点的坐标系
    CGAffineTransform t = CGAffineTransformMakeTranslation(-rect.origin.x, -rect.origin.y);
    mask.path = CGPathCreateCopyByTransformingPath(path.CGPath, &t);
    gradient.mask = mask;

    // 外层 wrapper 额外叠加顶部高光三角
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(0, 0, rect.origin.x * 2 + W, rect.origin.y + H);
    [wrapper addSublayer:gradient];

    // 顶部高光（左上薄弧，白色 20% alpha）
    CAShapeLayer *highlight = [CAShapeLayer layer];
    UIBezierPath *hlPath = [UIBezierPath bezierPath];
    [hlPath moveToPoint:CGPointMake(rect.origin.x + W * 0.42, rect.origin.y + H * 0.35)];
    [hlPath addQuadCurveToPoint:CGPointMake(rect.origin.x + W * 0.50, rect.origin.y + 3)
                   controlPoint:CGPointMake(rect.origin.x + W * 0.44, rect.origin.y + H * 0.15)];
    highlight.path = hlPath.CGPath;
    highlight.fillColor = [UIColor clearColor].CGColor;
    highlight.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.5].CGColor;
    highlight.lineWidth = 1.0;
    highlight.lineCap = kCALineCapRound;
    [wrapper addSublayer:highlight];

    return wrapper;
}

#pragma mark - 舷窗 (Window)

+ (CALayer *)windowLayerAtCenter:(CGPoint)center radius:(CGFloat)r {
    CALayer *wrapper = [CALayer layer];
    wrapper.frame = CGRectMake(center.x - r - 2, center.y - r - 2, (r + 2) * 2, (r + 2) * 2);

    // 玻璃（径向渐变）
    CAShapeLayer *glass = [CAShapeLayer layer];
    glass.path = [UIBezierPath bezierPathWithOvalInRect:
                  CGRectMake(2, 2, r * 2, r * 2)].CGPath;
    glass.fillColor = kGlassColor().CGColor;
    glass.strokeColor = kAccentRedColor().CGColor;
    glass.lineWidth = 2.0;
    [wrapper addSublayer:glass];

    // 内圈深色（模拟玻璃厚度）
    CAShapeLayer *inner = [CAShapeLayer layer];
    inner.path = [UIBezierPath bezierPathWithOvalInRect:
                  CGRectMake(5, 5, (r - 1.5) * 2, (r - 1.5) * 2)].CGPath;
    inner.fillColor = kGlassDeepColor().CGColor;
    [wrapper addSublayer:inner];

    // 左上角白色高光
    CAShapeLayer *shine = [CAShapeLayer layer];
    CGFloat sr = r * 0.35;
    shine.path = [UIBezierPath bezierPathWithOvalInRect:
                  CGRectMake(r * 0.35, r * 0.35, sr * 2, sr * 2)].CGPath;
    shine.fillColor = [[UIColor whiteColor] colorWithAlphaComponent:0.55].CGColor;
    [wrapper addSublayer:shine];

    return wrapper;
}

#pragma mark - Octo 文字

+ (CATextLayer *)octoLabelCenteredAt:(CGPoint)center {
    CATextLayer *tl = [CATextLayer layer];
    tl.contentsScale = [UIScreen mainScreen].scale;
    tl.alignmentMode = kCAAlignmentCenter;
    tl.truncationMode = kCATruncationNone;

    CGFloat fontSize = 10.5;
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightHeavy];
    tl.font = (__bridge CFTypeRef)(font.fontName);
    tl.fontSize = fontSize;
    tl.foregroundColor = kTextColor().CGColor;

    NSAttributedString *attr = [[NSAttributedString alloc] initWithString:@"Octo" attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: kTextColor(),
        NSKernAttributeName: @(0.8),
    }];
    tl.string = attr;

    CGSize size = CGSizeMake(40, fontSize + 2);
    tl.frame = CGRectMake(center.x - size.width / 2.0, center.y - size.height / 2.0,
                          size.width, size.height);
    return tl;
}

#pragma mark - 尾翼 (Fins)

+ (CAShapeLayer *)finLayerLeft:(BOOL)isLeft bodyRect:(CGRect)bodyRect {
    CGFloat bodyBottom = bodyRect.origin.y + bodyRect.size.height;
    CGFloat finHeight = 22.0;
    CGFloat finWidth  = 18.0;

    UIBezierPath *p = [UIBezierPath bezierPath];
    if (isLeft) {
        // 左翼：从机身左下角 → 向左下方延伸 → 回到机身左上
        CGFloat baseX = bodyRect.origin.x + 2.0;
        CGFloat topY  = bodyBottom - finHeight;
        [p moveToPoint:CGPointMake(baseX, topY)];
        [p addQuadCurveToPoint:CGPointMake(baseX - finWidth, bodyBottom + 1.0)
                  controlPoint:CGPointMake(baseX - finWidth * 0.4, topY + finHeight * 0.5)];
        [p addLineToPoint:CGPointMake(baseX, bodyBottom)];
        [p closePath];
    } else {
        CGFloat baseX = bodyRect.origin.x + bodyRect.size.width - 2.0;
        CGFloat topY  = bodyBottom - finHeight;
        [p moveToPoint:CGPointMake(baseX, topY)];
        [p addQuadCurveToPoint:CGPointMake(baseX + finWidth, bodyBottom + 1.0)
                  controlPoint:CGPointMake(baseX + finWidth * 0.4, topY + finHeight * 0.5)];
        [p addLineToPoint:CGPointMake(baseX, bodyBottom)];
        [p closePath];
    }

    CAShapeLayer *fin = [CAShapeLayer layer];
    fin.path = p.CGPath;
    fin.fillColor = kAccentRedColor().CGColor;
    // 背光侧（右翼）加阴影，立体感
    if (!isLeft) {
        fin.fillColor = kAccentDarkRedColor().CGColor;
    }
    return fin;
}

#pragma mark - 喷口 (Nozzle)

+ (CAShapeLayer *)nozzleLayerInRect:(CGRect)rect {
    CGFloat W = rect.size.width;
    // 倒梯形：顶窄(机身宽 0.55) 底宽(0.7)
    CGFloat topInset    = W * (1 - 0.55) / 2.0;
    CGFloat bottomInset = W * (1 - 0.70) / 2.0;

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(rect.origin.x + topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - topInset, rect.origin.y)];
    [p addLineToPoint:CGPointMake(rect.origin.x + W - bottomInset, rect.origin.y + rect.size.height)];
    [p addLineToPoint:CGPointMake(rect.origin.x + bottomInset, rect.origin.y + rect.size.height)];
    [p closePath];

    CAShapeLayer *nozzle = [CAShapeLayer layer];
    nozzle.path = p.CGPath;
    nozzle.fillColor = kNozzleColor().CGColor;
    nozzle.strokeColor = [UIColor colorWithWhite:0.0 alpha:0.3].CGColor;
    nozzle.lineWidth = 0.5;
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
    shape.fillColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0].CGColor;
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
    inner.fillColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.25 alpha:0.98].CGColor;
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

    // 外光晕
    shape.shadowColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.1 alpha:1.0].CGColor;
    shape.shadowOffset = CGSizeMake(0, 3);
    shape.shadowRadius = 7.0;
    shape.shadowOpacity = 0.95;

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

@end
