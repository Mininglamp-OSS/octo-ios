//
//  WKRocketEffect.m → 「炸弹」— 参考游戏引擎多层粒子爆炸
//
//  视觉流水线（模仿真实爆炸物理）：
//    1. 💣 到位后轻微 shake 0.1s（引信即将引爆感）
//    2. 💥 放大淡出（爆裂主视觉）
//    3. 白光闪（0.5s 快速淡出）
//    4. 三层火球：
//        a) 亮白核心：瞬间、最亮、最快消
//        b) 橙色火球：中等速度、受自身发光
//        c) 红色余烬：飞远、带重力下落
//    5. 冲击波：一道深色环（气压波）快速扩散
//    6. 两阶段烟：
//        a) 爆心四周喷发（0.2s，全方位）
//        b) 向上飘升的烟柱（1.5s，缓慢扩散）
//    7. 气泡物理（保留：推力/旋转/互撞/弹簧 全随机）
//    8. 屏幕抖动

#import "WKRocketEffect.h"
#import "WKMessageEffectView.h"
#import "WKMessageEffectManager.h"
#import "WuKongBase.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import <AudioToolbox/AudioToolbox.h>

@implementation WKRocketEffect

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    UITableView *tableView = effectView.tableView;

    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;

    // 爆炸点：可见气泡几何中心 + 小范围随机偏移
    CGPoint explodeBase = [self computeExplodePointInView:effectView
                                                 tableView:tableView
                                                  fallback:CGPointMake(viewW / 2, viewH * 0.5)];
    CGFloat restJitterX = ((CGFloat)arc4random_uniform(50)) - 25;
    CGFloat restJitterY = ((CGFloat)arc4random_uniform(40)) - 20;
    CGPoint rest = CGPointMake(explodeBase.x + restJitterX, explodeBase.y + restJitterY);

    // 从左/右随机一侧抛入，旋转方向跟随入场方向
    BOOL fromLeft = (arc4random_uniform(2) == 0);
    CGFloat startX = fromLeft ? -80.0 : (viewW + 80.0);
    CGFloat startY = viewH * (0.10 + (CGFloat)arc4random_uniform(10) / 100.0);
    CGPoint start = CGPointMake(startX, startY);

    UILabel *bomb = [UILabel new];
    bomb.text = @"💣";
    bomb.font = [UIFont systemFontOfSize:56];
    bomb.textAlignment = NSTextAlignmentCenter;
    bomb.frame = CGRectMake(0, 0, 72, 72);
    bomb.center = start;
    bomb.alpha = 1.0;
    [effectView addSubview:bomb];

    // 单段抛物线（符合真实抛体物理）：
    //   - 水平速度恒定（X 始终朝 rest 方向推进，无回弹）
    //   - 垂直受重力加速（控制点在中点上方，形成自然弧顶）
    CAKeyframeAnimation *posAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, start.x, start.y);

    // 控制点：X 在 start/rest 中点，Y 在两者更高那一点上方额外拱起，形成抛物线顶点
    CGFloat arcPeakAbove = 80 + (CGFloat)arc4random_uniform(50); // 80~130pt 峰值高度
    CGFloat controlX = (start.x + rest.x) / 2.0;
    CGFloat controlY = MIN(start.y, rest.y) - arcPeakAbove;
    CGPathAddQuadCurveToPoint(path, NULL, controlX, controlY, rest.x, rest.y);

    posAnim.path = path;
    posAnim.duration = 0.7;
    // 路径时间函数：easeIn → 越接近落点速度越快（模拟重力加速）
    posAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    posAnim.fillMode = kCAFillModeForwards;
    posAnim.removedOnCompletion = NO;
    CGPathRelease(path);

    // 空中连续旋转（方向跟随入场方向）
    CGFloat rotationSign = fromLeft ? 1.0 : -1.0;
    CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotAnim.fromValue = @(-M_PI * 0.3 * rotationSign);
    rotAnim.toValue = @(M_PI * 2.2 * rotationSign);
    rotAnim.duration = 0.7;
    rotAnim.fillMode = kCAFillModeForwards;
    rotAnim.removedOnCompletion = NO;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[posAnim, rotAnim];
    group.duration = 0.7;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [bomb.layer addAnimation:group forKey:@"bomb-throw"];

    bomb.center = rest;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!effectView.superview) return;
        [self fuseShakeView:bomb completion:^{
            [bomb removeFromSuperview];
            [self executeExplosionAtPoint:rest
                               effectView:effectView
                                tableView:tableView];
        }];
    });

    [effectView scheduleRemovalAfterDelay:6.5];
}

#pragma mark - 爆炸点计算（可见气泡几何中心）

+ (CGPoint)computeExplodePointInView:(UIView *)effectView
                           tableView:(UITableView *)tableView
                            fallback:(CGPoint)fallback {
    if (!tableView || tableView.visibleCells.count == 0) return fallback;
    CGFloat sumX = 0, sumY = 0;
    NSInteger count = 0;
    for (UITableViewCell *cell in tableView.visibleCells) {
        CGRect f = [tableView convertRect:cell.frame toView:effectView];
        if (CGRectIsEmpty(f)) continue;
        sumX += CGRectGetMidX(f);
        sumY += CGRectGetMidY(f);
        count++;
    }
    if (count == 0) return fallback;
    return CGPointMake(sumX / count, sumY / count);
}

#pragma mark - 源气泡「弹出」视觉反馈

+ (void)emitPopRingAtPoint:(CGPoint)point inView:(UIView *)host {
    CAShapeLayer *ring = [CAShapeLayer layer];
    CGFloat radius = 20.0;
    ring.path = [UIBezierPath bezierPathWithOvalInRect:
                 CGRectMake(-radius, -radius, radius * 2, radius * 2)].CGPath;
    ring.position = point;
    ring.fillColor = [UIColor clearColor].CGColor;
    ring.strokeColor = [UIColor colorWithWhite:0.2 alpha:0.5].CGColor;
    ring.lineWidth = 3.0;
    [host.layer addSublayer:ring];

    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.fromValue = @(0.3);
    scaleAnim.toValue = @(3.5);
    scaleAnim.duration = 0.4;

    CABasicAnimation *alphaAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alphaAnim.fromValue = @(0.6);
    alphaAnim.toValue = @(0);
    alphaAnim.duration = 0.4;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scaleAnim, alphaAnim];
    group.duration = 0.4;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [ring addAnimation:group forKey:@"pop-ring"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ring removeFromSuperlayer];
    });
}

#pragma mark - 爆炸流程

/// 爆炸分两阶段：
///   阶段 A：💥 emoji 先 pop 出来（0.12s 短暂的预警视觉）
///   阶段 B：紧接着火球、白闪、冲击波、浓烟、气泡物理、屏抖 **同时**触发
///            同时 💥 继续扩散淡出，和爆炸元素一起消失
+ (void)executeExplosionAtPoint:(CGPoint)explodePoint
                     effectView:(WKMessageEffectView *)effectView
                      tableView:(UITableView *)tableView {

    // 阶段 A — 💥 pop 预警
    UILabel *burst = [UILabel new];
    burst.text = @"💥";
    burst.font = [UIFont systemFontOfSize:100];
    burst.textAlignment = NSTextAlignmentCenter;
    burst.frame = CGRectMake(0, 0, 140, 140);
    burst.center = explodePoint;
    burst.transform = CGAffineTransformMakeScale(0.55, 0.55);
    burst.alpha = 1.0;
    [effectView addSubview:burst];

    [UIView animateWithDuration:0.03 delay:0
         usingSpringWithDamping:0.6 initialSpringVelocity:1.5
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        burst.transform = CGAffineTransformMakeScale(1.8, 1.8);
    } completion:nil];

    // 阶段 B — 0.03s 后：💥 扩散淡出 + 所有爆炸元素同步触发
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!effectView.superview) {
            [burst removeFromSuperview];
            return;
        }

        // 手机强震动（真实爆炸冲击感）
        // 1) Heavy impact 瞬间冲击
        UIImpactFeedbackGenerator *heavy =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [heavy prepare];
        [heavy impactOccurred];
        // 2) 系统振动器（长震 ~400ms，相当于电话振动强度）
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

        // 💥 继续扩散淡出
        [UIView animateWithDuration:0.4 animations:^{
            burst.transform = CGAffineTransformMakeScale(2.4, 2.4);
            burst.alpha = 0;
        } completion:^(BOOL f) { [burst removeFromSuperview]; }];

        // 白光闪
        UIView *flash = [[UIView alloc] initWithFrame:effectView.bounds];
        flash.backgroundColor = [UIColor whiteColor];
        flash.alpha = 0.88;
        [effectView addSubview:flash];
        [UIView animateWithDuration:0.35 delay:0
                            options:UIViewAnimationOptionCurveEaseOut animations:^{
            flash.alpha = 0;
        } completion:^(BOOL f) { [flash removeFromSuperview]; }];

        // 三层火球 + 冲击波 + 浓烟 + 气泡物理 + 屏抖：全部同步
        [self emitFireballAtPoint:explodePoint inView:effectView];
        [self emitShockwaveAtPoint:explodePoint inView:effectView];
        [self emitSmokeAtPoint:explodePoint inView:effectView];

        if (tableView) {
            [self applyBubbleShockwavePhysicsInView:effectView
                                         tableView:tableView
                                      explodePoint:explodePoint];
        }

        [self shakeHostView:effectView];
    });
}

#pragma mark - Fuse shake

+ (void)fuseShakeView:(UIView *)view completion:(void(^)(void))completion {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@(-3), @(3), @(-2), @(2), @(-1), @(1), @(0)];
    shake.duration = 0.1;
    [view.layer addAnimation:shake forKey:@"fuse"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completion) completion();
    });
}

#pragma mark - 三层火球

+ (void)emitFireballAtPoint:(CGPoint)point inView:(UIView *)host {
    // ------- 层 1：亮白核心 -------
    CAEmitterLayer *core = [CAEmitterLayer layer];
    core.emitterPosition = point;
    core.emitterShape = kCAEmitterLayerPoint;
    core.renderMode = kCAEmitterLayerAdditive;

    CAEmitterCell *white = [CAEmitterCell emitterCell];
    white.contents = (id)[self whiteHotParticleImage].CGImage;
    white.birthRate = 600;
    white.lifetime = 0.3;  // 非常短
    white.velocity = 180;
    white.velocityRange = 80;
    white.emissionRange = M_PI * 2;
    white.scale = 0.5;
    white.scaleRange = 0.2;
    white.scaleSpeed = 1.0;
    white.alphaSpeed = -3.5; // 快速消
    white.color = [UIColor colorWithRed:1.0 green:0.98 blue:0.85 alpha:1.0].CGColor;
    core.emitterCells = @[white];
    [host.layer addSublayer:core];

    // ------- 层 2：橙色火球 -------
    CAEmitterLayer *flame = [CAEmitterLayer layer];
    flame.emitterPosition = point;
    flame.emitterShape = kCAEmitterLayerPoint;
    flame.renderMode = kCAEmitterLayerAdditive;

    CAEmitterCell *orange = [CAEmitterCell emitterCell];
    orange.contents = (id)[self fireParticleImage].CGImage;
    orange.birthRate = 700;
    orange.lifetime = 0.6;
    orange.velocity = 250;
    orange.velocityRange = 120;
    orange.emissionRange = M_PI * 2;
    orange.scale = 0.6;
    orange.scaleRange = 0.35;
    orange.scaleSpeed = 0.9;
    orange.alphaSpeed = -1.8;
    orange.spin = 2.5;
    orange.spinRange = 4.0;
    orange.color = [UIColor colorWithRed:1.0 green:0.45 blue:0.12 alpha:1.0].CGColor;
    orange.redRange = 0.12;
    orange.greenRange = 0.2;
    orange.blueRange = 0.05;
    flame.emitterCells = @[orange];
    [host.layer addSublayer:flame];

    // ------- 层 3：红色余烬 + 碎屑（受重力）-------
    CAEmitterLayer *embers = [CAEmitterLayer layer];
    embers.emitterPosition = point;
    embers.emitterShape = kCAEmitterLayerPoint;
    embers.renderMode = kCAEmitterLayerAdditive;

    CAEmitterCell *redSpark = [CAEmitterCell emitterCell];
    redSpark.contents = (id)[self sparkParticleImage].CGImage;
    redSpark.birthRate = 450;
    redSpark.lifetime = 1.4;
    redSpark.velocity = 400;
    redSpark.velocityRange = 180;
    redSpark.emissionRange = M_PI * 2;
    redSpark.scale = 0.24;
    redSpark.scaleRange = 0.15;
    redSpark.scaleSpeed = -0.15;
    redSpark.alphaSpeed = -0.7;
    redSpark.yAcceleration = 380; // 向下掉
    redSpark.spin = 2.5;
    redSpark.spinRange = 4.0;
    redSpark.color = [UIColor colorWithRed:1.0 green:0.55 blue:0.2 alpha:1.0].CGColor;
    redSpark.redRange = 0.1;
    redSpark.greenRange = 0.25;
    redSpark.blueRange = 0.1;
    embers.emitterCells = @[redSpark];
    [host.layer addSublayer:embers];

    // 瞬间爆发后立即停火（不是持续喷发）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        core.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.09 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        flame.birthRate = 0;
        embers.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [core removeFromSuperlayer];
        [flame removeFromSuperlayer];
        [embers removeFromSuperlayer];
    });
}

#pragma mark - 冲击波（单道深色气压波）

+ (void)emitShockwaveAtPoint:(CGPoint)point inView:(UIView *)host {
    CAShapeLayer *wave = [CAShapeLayer layer];
    CGFloat radius = 25.0;
    wave.path = [UIBezierPath bezierPathWithOvalInRect:
                 CGRectMake(-radius, -radius, radius * 2, radius * 2)].CGPath;
    wave.position = point;
    wave.fillColor = [UIColor clearColor].CGColor;
    // 深色半透明环，模拟气压波（不是庆祝黄圈）
    wave.strokeColor = [UIColor colorWithWhite:0.15 alpha:0.35].CGColor;
    wave.lineWidth = 10.0;
    [host.layer addSublayer:wave];

    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.fromValue = @(0.3);
    scaleAnim.toValue = @(22.0);
    scaleAnim.duration = 0.5;
    scaleAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

    CABasicAnimation *widthAnim = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
    widthAnim.fromValue = @(10);
    widthAnim.toValue = @(1);
    widthAnim.duration = 0.5;

    CABasicAnimation *alphaAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alphaAnim.fromValue = @(0.5);
    alphaAnim.toValue = @(0);
    alphaAnim.duration = 0.5;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[scaleAnim, widthAnim, alphaAnim];
    group.duration = 0.5;
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [wave addAnimation:group forKey:@"shockwave"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [wave removeFromSuperlayer];
    });
}

#pragma mark - 两阶段烟雾

+ (void)emitSmokeAtPoint:(CGPoint)point inView:(UIView *)host {
    // 阶段 1：爆心全方位喷发（0.25s 密集）
    CAEmitterLayer *radialSmoke = [CAEmitterLayer layer];
    radialSmoke.emitterPosition = point;
    radialSmoke.emitterShape = kCAEmitterLayerCircle;
    radialSmoke.emitterSize = CGSizeMake(30, 30);

    CAEmitterCell *burst = [CAEmitterCell emitterCell];
    burst.contents = (id)[self smokeParticleImage].CGImage;
    burst.birthRate = 55;
    burst.lifetime = 2.2;
    burst.velocity = 60;
    burst.velocityRange = 40;
    burst.emissionRange = M_PI * 2; // 全方位散开
    burst.scale = 0.28;
    burst.scaleRange = 0.15;
    burst.scaleSpeed = 0.55; // 粒子逐渐变大（软化）
    burst.alphaSpeed = -0.5;  // 慢慢透明
    burst.spin = 0.8;
    burst.spinRange = 1.5;
    // 色偏浅，alpha 低（否则叠加成黑块）
    burst.color = [UIColor colorWithWhite:0.55 alpha:0.45].CGColor;
    burst.redRange = 0.08;
    burst.greenRange = 0.08;
    burst.blueRange = 0.08;
    radialSmoke.emitterCells = @[burst];
    [host.layer addSublayer:radialSmoke];

    // 阶段 2：上升烟柱（0.15s 延迟开始，持续 1.3s）
    CAEmitterLayer *risingSmoke = [CAEmitterLayer layer];
    risingSmoke.emitterPosition = point;
    risingSmoke.emitterShape = kCAEmitterLayerRectangle;
    risingSmoke.emitterSize = CGSizeMake(45, 8);

    CAEmitterCell *rise = [CAEmitterCell emitterCell];
    rise.contents = (id)[self smokeParticleImage].CGImage;
    rise.birthRate = 0; // 先关闭，延迟启动
    rise.lifetime = 3.8;
    rise.velocity = 45;
    rise.velocityRange = 25;
    rise.emissionLongitude = -M_PI_2; // 向上
    rise.emissionRange = M_PI_4 * 0.5; // 窄角
    rise.scale = 0.3;
    rise.scaleRange = 0.18;
    rise.scaleSpeed = 0.5; // 上升时膨胀
    rise.alphaSpeed = -0.28; // 慢慢消
    rise.spin = 0.5;
    rise.spinRange = 1.0;
    rise.yAcceleration = -35; // 继续向上（浮力）
    // 上升烟更亮（远离爆心）
    rise.color = [UIColor colorWithWhite:0.6 alpha:0.38].CGColor;
    rise.redRange = 0.1;
    rise.greenRange = 0.1;
    rise.blueRange = 0.1;
    risingSmoke.emitterCells = @[rise];
    [host.layer addSublayer:risingSmoke];

    // 控制发射节奏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        radialSmoke.birthRate = 0; // 爆心喷发结束
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        risingSmoke.beginTime = CACurrentMediaTime();
        [risingSmoke.emitterCells.firstObject setValue:@(18) forKey:@"birthRate"];
        // CAEmitterCell 上的 birthRate 改动要在 layer 层触发
        CAEmitterCell *cell = risingSmoke.emitterCells.firstObject;
        cell.birthRate = 18;
        risingSmoke.emitterCells = @[cell];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        risingSmoke.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [radialSmoke removeFromSuperlayer];
        [risingSmoke removeFromSuperlayer];
    });
}

#pragma mark - Bubble physics (第一版：干净的径向推散 + 固定弹簧参数)

+ (void)applyBubbleShockwavePhysicsInView:(WKMessageEffectView *)effectView
                                tableView:(UITableView *)tableView
                             explodePoint:(CGPoint)explodePoint {

    // 并发锁：同一时刻只允许一个炸弹做气泡物理
    WKMessageEffectManager *mgr = [WKMessageEffectManager shared];
    if (mgr.bubblePhysicsActive) return;
    if (!tableView) return;

    // 气泡快照直接加在 tableView 内部，和真实 cell 同层、同坐标系：
    //   - 滚动 tableView 时，快照会跟着一起滚动（不会出现"两层"视觉）
    //   - 快照会被 tableView 自身 clipsToBounds 剪裁，不会飞到导航/键盘上
    NSArray<WKBubbleSnapshot *> *snapshots =
        [WKBubbleInteractionHelper snapshotCellsIn:tableView addingTo:tableView];

    if (snapshots.count == 0) return;

    mgr.bubblePhysicsActive = YES;
    effectView.snapshots = snapshots;

    // 把爆炸点从 effectView (window) 坐标系转换到 tableView 坐标系
    CGPoint explodeInTable = [effectView convertPoint:explodePoint toView:tableView];

    UIDynamicAnimator *animator = [[UIDynamicAnimator alloc] initWithReferenceView:tableView];
    effectView.animator = animator;

    for (WKBubbleSnapshot *s in snapshots) {
        UIView *view = s.view;
        CGPoint target = s.originalCenter; // 已经是 tableView 坐标系

        CGFloat dx = target.x - explodeInTable.x;
        CGFloat dy = target.y - explodeInTable.y;
        CGFloat dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        CGFloat nx = dx / dist;
        CGFloat ny = dy / dist;

        CGFloat magnitude = MIN(4.0, 1.5 + 300.0 / dist);

        UIPushBehavior *push = [[UIPushBehavior alloc]
            initWithItems:@[view] mode:UIPushBehaviorModeInstantaneous];
        push.pushDirection = CGVectorMake(nx, ny);
        push.magnitude = magnitude;
        [animator addBehavior:push];

        UIDynamicItemBehavior *item = [[UIDynamicItemBehavior alloc] initWithItems:@[view]];
        item.allowsRotation = YES;
        item.angularResistance = 2.0;
        item.resistance = 1.2;
        item.density = 1.0;
        [animator addBehavior:item];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.28 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!tableView.superview) return;
            UIAttachmentBehavior *spring = [[UIAttachmentBehavior alloc]
                initWithItem:view
                offsetFromCenter:UIOffsetZero
                attachedToAnchor:target];
            spring.damping = 0.6;
            spring.frequency = 2.5;
            spring.length = 0;
            [animator addBehavior:spring];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!tableView.superview) {
            [effectView cleanupSnapshots];
            mgr.bubblePhysicsActive = NO;
            return;
        }
        [animator removeAllBehaviors];
        effectView.animator = nil;

        [UIView animateWithDuration:0.45 delay:0
             usingSpringWithDamping:0.85 initialSpringVelocity:0.2
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            for (WKBubbleSnapshot *s in snapshots) {
                s.view.center = s.originalCenter;
                s.view.transform = CGAffineTransformIdentity;
            }
        } completion:^(BOOL finished) {
            [effectView cleanupSnapshots];
            mgr.bubblePhysicsActive = NO;
        }];
    });
}

+ (void)shakeHostView:(UIView *)view {
    UIView *host = view.superview ?: view;
    CAKeyframeAnimation *shakeX = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shakeX.values = @[@(-10), @(10), @(-7), @(7), @(-4), @(4), @(-2), @(0)];
    shakeX.duration = 0.55;
    shakeX.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [host.layer addAnimation:shakeX forKey:@"bomb-shake-x"];

    CAKeyframeAnimation *shakeY = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
    shakeY.values = @[@(-4), @(6), @(-3), @(4), @(-2), @(0)];
    shakeY.duration = 0.45;
    [host.layer addAnimation:shakeY forKey:@"bomb-shake-y"];
}

#pragma mark - Particle images

+ (UIImage *)whiteHotParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 28;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = {
            1.0, 1.0, 1.0, 1.0,
            1.0, 0.95, 0.7, 0.8,
            1.0, 0.8, 0.3, 0.0,
        };
        CGFloat locations[] = {0.0, 0.5, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, locations, 3);
        CGContextDrawRadialGradient(ctx, gradient,
            CGPointMake(size/2, size/2), 0,
            CGPointMake(size/2, size/2), size/2, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

+ (UIImage *)fireParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 40;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = {
            1.0, 0.95, 0.65, 1.0,
            1.0, 0.5, 0.15, 0.9,
            1.0, 0.2, 0.0, 0.0,
        };
        CGFloat locations[] = {0.0, 0.5, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, locations, 3);
        CGContextDrawRadialGradient(ctx, gradient,
            CGPointMake(size/2, size/2), 0,
            CGPointMake(size/2, size/2), size/2, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

+ (UIImage *)sparkParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 10;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = {1, 1, 0.8, 1.0, 1, 0.6, 0.2, 0.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, NULL, 2);
        CGContextDrawRadialGradient(ctx, gradient,
            CGPointMake(size/2, size/2), 0,
            CGPointMake(size/2, size/2), size/2, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

/// 烟雾粒子：必须是半透明 + 柔和边缘，这样多粒子叠加才不会成黑块
+ (UIImage *)smokeParticleImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 96; // 大尺寸 → 梯度柔和
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        // 中心 alpha 压低到 0.4（关键）；边缘彻底透明
        CGFloat colors[] = {
            0.65, 0.65, 0.65, 0.4,
            0.45, 0.45, 0.45, 0.18,
            0.3, 0.3, 0.3, 0.0,
        };
        CGFloat locations[] = {0.0, 0.55, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, locations, 3);
        CGContextDrawRadialGradient(ctx, gradient,
            CGPointMake(size/2, size/2), 0,
            CGPointMake(size/2, size/2), size/2, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

@end
