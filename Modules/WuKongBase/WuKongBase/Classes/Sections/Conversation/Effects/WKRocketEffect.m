// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
            // 爆炸瞬间：炸弹外壳裂开，碎片向四周崩飞（与 💥/火球同帧触发）
            [self emitBombShatterFromLabel:bomb inView:effectView];
            [bomb removeFromSuperview];
            [self executeExplosionAtPoint:rest
                               effectView:effectView
                                tableView:tableView];
        }];
    });

    [effectView scheduleRemovalAfterDelay:8.5];
}

#pragma mark - 爆炸点计算（可见气泡几何中心）

/// 计算爆炸落点。关键：必须落在**真正可见**的 tableView 区域内 ——
/// 当键盘弹出、输入/表情面板展开时，tableView 的 `adjustedContentInset.bottom`
/// 会包含那块被遮挡的高度，这里要把它从可见区域里扣掉，
/// 避免爆炸发生在键盘后面的死区，玩家一个字都看不见。
+ (CGPoint)computeExplodePointInView:(UIView *)effectView
                           tableView:(UITableView *)tableView
                            fallback:(CGPoint)fallback {
    if (!tableView || tableView.visibleCells.count == 0) return fallback;

    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        insets = tableView.adjustedContentInset;
    } else {
        insets = tableView.contentInset;
    }
    // tableView 自身坐标系中的"真正能看到内容的矩形"
    //   bounds.origin = contentOffset（scrollView 特性）
    //   顶部 inset 下移、底部 inset 被键盘/面板吃掉，都要剔除
    CGRect scrollBounds = tableView.bounds;
    CGRect visibleContentRect = CGRectMake(
        scrollBounds.origin.x,
        scrollBounds.origin.y + insets.top,
        scrollBounds.size.width,
        scrollBounds.size.height - insets.top - insets.bottom
    );

    CGFloat sumX = 0, sumY = 0;
    NSInteger count = 0;
    for (UITableViewCell *cell in tableView.visibleCells) {
        // cell.frame 与 visibleContentRect 都在 tableView 坐标系 → 直接相交
        CGRect intersect = CGRectIntersection(cell.frame, visibleContentRect);
        if (CGRectIsEmpty(intersect) || intersect.size.height < 10) continue;
        CGRect f = [tableView convertRect:intersect toView:effectView];
        if (CGRectIsEmpty(f)) continue;
        sumX += CGRectGetMidX(f);
        sumY += CGRectGetMidY(f);
        count++;
    }
    if (count == 0) {
        // 所有 cell 都在遮挡区外（极端情况）→ 用可见矩形几何中心兜底
        CGRect visibleInEffect = [tableView convertRect:visibleContentRect toView:effectView];
        if (!CGRectIsEmpty(visibleInEffect)) {
            return CGPointMake(CGRectGetMidX(visibleInEffect),
                               CGRectGetMidY(visibleInEffect));
        }
        return fallback;
    }
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

#pragma mark - Bomb shatter (外壳炸裂成碎片)

/// 在爆炸瞬间把炸弹 emoji 切成 N×N 小碎片向四周抛飞。
/// 每片独立动画：抛物线位移（向外 + 微微上抛后受"重力"下落）+ 随机旋转 + 缩小淡出。
+ (void)emitBombShatterFromLabel:(UILabel *)bomb inView:(UIView *)host {
    if (!bomb || !host) return;

    // 1) 把炸弹 label 当前样子渲染成一张 UIImage（包含正在进行的抖动并非问题，抖动幅度已很小）
    CGSize labelSize = bomb.bounds.size;
    if (labelSize.width <= 0 || labelSize.height <= 0) return;

    UIGraphicsBeginImageContextWithOptions(labelSize, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return; }
    [bomb.layer renderInContext:ctx];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!snapshot.CGImage) return;

    // 2) 切 5×5 = 25 块碎片（每块约 14×14pt，够小够碎）
    const int COLS = 5;
    const int ROWS = 5;
    CGFloat pxScale = snapshot.scale;              // Retina: 2 或 3
    CGFloat cellW = labelSize.width  / (CGFloat)COLS;
    CGFloat cellH = labelSize.height / (CGFloat)ROWS;
    CGPoint center = bomb.center;

    for (int row = 0; row < ROWS; row++) {
        for (int col = 0; col < COLS; col++) {
            // CGImage 按像素取，所以 rect 要乘 scale
            CGRect cropPx = CGRectMake(col * cellW * pxScale,
                                       row * cellH * pxScale,
                                       cellW * pxScale,
                                       cellH * pxScale);
            CGImageRef cgSub = CGImageCreateWithImageInRect(snapshot.CGImage, cropPx);
            if (!cgSub) continue;
            UIImage *piece = [UIImage imageWithCGImage:cgSub
                                                 scale:pxScale
                                           orientation:UIImageOrientationUp];
            CGImageRelease(cgSub);

            UIImageView *frag = [[UIImageView alloc] initWithImage:piece];
            frag.frame = CGRectMake(0, 0, cellW, cellH);
            // 起始位置：碎片在原炸弹里的格子中心
            CGFloat fx = center.x - labelSize.width  / 2.0 + col * cellW + cellW / 2.0;
            CGFloat fy = center.y - labelSize.height / 2.0 + row * cellH + cellH / 2.0;
            frag.center = CGPointMake(fx, fy);
            [host addSubview:frag];

            // 方向：从爆心指向碎片当前位置（向外放射）；
            // 正中心那格 dist=0，给个随机方向避免原地不动
            CGFloat dx = fx - center.x;
            CGFloat dy = fy - center.y;
            CGFloat dist = sqrt(dx * dx + dy * dy);
            CGFloat nx, ny;
            if (dist < 0.5) {
                CGFloat theta = (CGFloat)arc4random_uniform(360) * (CGFloat)M_PI / 180.0;
                nx = cosf(theta); ny = sinf(theta);
            } else {
                nx = dx / dist; ny = dy / dist;
            }

            // 放射距离 + 下落量（抛物线终点）
            CGFloat flyDist = 70.0 + (CGFloat)arc4random_uniform(80);   // 70~150pt 向外
            CGFloat dropAmount = 50.0 + (CGFloat)arc4random_uniform(60); // 50~110pt 向下
            CGFloat endX = fx + nx * flyDist;
            CGFloat endY = fy + ny * flyDist + dropAmount;

            // 抛物线控制点：在起点和终点的 X 中点、Y 略高处
            // → 先有"被炸飞向外上方"的感觉，再因重力落下
            CGFloat midX = (fx + endX) / 2.0;
            CGFloat midY = MIN(fy, endY) - (25.0 + (CGFloat)arc4random_uniform(35)); // 拱起 25~60pt

            CGMutablePathRef path = CGPathCreateMutable();
            CGPathMoveToPoint(path, NULL, fx, fy);
            CGPathAddQuadCurveToPoint(path, NULL, midX, midY, endX, endY);

            NSTimeInterval duration = 0.55 + (CGFloat)arc4random_uniform(30) / 100.0; // 0.55~0.84s

            CAKeyframeAnimation *posAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            posAnim.path = path;
            posAnim.duration = duration;
            posAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            CGPathRelease(path);

            // 随机旋转 ±1~4π
            CGFloat rotDir = (arc4random_uniform(2) == 0) ? 1.0 : -1.0;
            CGFloat rotTurns = 1.0 + (CGFloat)arc4random_uniform(30) / 10.0; // 1.0 ~ 4.0 圈
            CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            rotAnim.fromValue = @(0);
            rotAnim.toValue = @(rotDir * rotTurns * 2.0 * M_PI);
            rotAnim.duration = duration;

            CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            scaleAnim.fromValue = @(1.0);
            scaleAnim.toValue = @(0.35);
            scaleAnim.duration = duration;
            scaleAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];

            CABasicAnimation *alphaAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
            alphaAnim.fromValue = @(1.0);
            alphaAnim.toValue = @(0.0);
            alphaAnim.duration = duration;
            alphaAnim.beginTime = duration * 0.5; // 前半段还很清晰，后半段才淡出
            alphaAnim.fillMode = kCAFillModeForwards;

            CAAnimationGroup *group = [CAAnimationGroup animation];
            group.animations = @[posAnim, rotAnim, scaleAnim, alphaAnim];
            group.duration = duration;
            group.fillMode = kCAFillModeForwards;
            group.removedOnCompletion = NO;

            [CATransaction begin];
            [CATransaction setCompletionBlock:^{
                [frag removeFromSuperview];
            }];
            [frag.layer addAnimation:group forKey:@"shatter"];
            [CATransaction commit];
        }
    }
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

#pragma mark - 火焰爆炸（4 阶段真实爆裂）

/// 爆炸火焰流程（模拟真实爆裂瞬间）：
///   阶段 1 - 白光核爆（0~0.12s）：中心极亮白光瞬间炸开（像闪光弹）
///   阶段 2 - 主火球（0~0.35s）：黄→橙→红径向渐变大团，快速膨胀并淡出（核心火球）
///   阶段 3 - 火焰花瓣（0~0.45s）：6 瓣随机角度的火焰向外抛射 + 自旋（火舌冲出的感觉）
///   阶段 4 - 爆星火花（0~1.3s）：高亮金色小火星向各方向迸射，受重力下落（碎屑飞散）
/// 全部以 UIImageView + UIView.animate 实现（替代原 CAEmitter 粒子雨），
/// 视觉上是"一团火球炸开"而不是"一把小粒子四散"。
+ (void)emitFireballAtPoint:(CGPoint)point inView:(UIView *)host {
    UIImage *flashImg   = [self flashCoreImage];
    UIImage *fireImg    = [self fireballImage];

    // === 阶段 3：先加火焰花瓣（放在最底层，被核心和白闪盖住）===
    const int petalCount = 6;
    for (int i = 0; i < petalCount; i++) {
        CGFloat startSize = 52.0 + (CGFloat)arc4random_uniform(30); // 52~82pt
        UIImageView *petal = [[UIImageView alloc] initWithImage:fireImg];
        petal.bounds = CGRectMake(0, 0, startSize, startSize);
        petal.center = point;
        petal.alpha = 0.95;
        [host addSubview:petal];

        // 等分角度 + 随机偏移 → 放射均匀但不机械
        CGFloat baseAngle = (2.0 * (CGFloat)M_PI / petalCount) * i;
        CGFloat jitter = ((CGFloat)arc4random_uniform(41) - 20) * (CGFloat)M_PI / 180.0;
        CGFloat angle = baseAngle + jitter;
        CGFloat distance = 55.0 + (CGFloat)arc4random_uniform(70); // 55~125pt
        CGFloat endX = point.x + cosf(angle) * distance;
        CGFloat endY = point.y + sinf(angle) * distance;

        CGFloat rotDir = (arc4random_uniform(2) == 0) ? 1.0 : -1.0;
        CGFloat rotTurns = 0.35 + (CGFloat)arc4random_uniform(30) / 100.0; // 0.35~0.65 圈
        CGFloat scaleEnd = 1.5 + (CGFloat)arc4random_uniform(9) / 10.0;    // 1.5~2.4x
        NSTimeInterval duration = 0.40 + (CGFloat)arc4random_uniform(10) / 100.0; // 0.40~0.50s

        [UIView animateWithDuration:duration delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            petal.center = CGPointMake(endX, endY);
            petal.transform = CGAffineTransformRotate(
                CGAffineTransformMakeScale(scaleEnd, scaleEnd),
                rotDir * rotTurns * 2.0 * (CGFloat)M_PI);
            petal.alpha = 0;
        } completion:^(BOOL finished) {
            [petal removeFromSuperview];
        }];
    }

    // === 阶段 2：主火球核心（中层）===
    UIImageView *core = [[UIImageView alloc] initWithImage:fireImg];
    core.bounds = CGRectMake(0, 0, 100, 100);
    core.center = point;
    core.alpha = 1.0;
    core.transform = CGAffineTransformMakeScale(0.35, 0.35); // 从很小开始
    [host addSubview:core];

    [UIView animateWithDuration:0.35 delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        core.transform = CGAffineTransformMakeScale(2.6, 2.6);
        core.alpha = 0;
    } completion:^(BOOL finished) {
        [core removeFromSuperview];
    }];

    // === 阶段 1：白光核爆（最上层，极短）===
    UIImageView *flash = [[UIImageView alloc] initWithImage:flashImg];
    flash.bounds = CGRectMake(0, 0, 80, 80);
    flash.center = point;
    flash.alpha = 1.0;
    flash.transform = CGAffineTransformMakeScale(0.3, 0.3);
    [host addSubview:flash];

    [UIView animateWithDuration:0.12 delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        flash.transform = CGAffineTransformMakeScale(2.4, 2.4);
        flash.alpha = 0;
    } completion:^(BOOL finished) {
        [flash removeFromSuperview];
    }];

    // === 阶段 4：爆星火花（亮粒子向外迸射 + 重力下落）===
    CAEmitterLayer *sparks = [CAEmitterLayer layer];
    sparks.emitterPosition = point;
    sparks.emitterShape = kCAEmitterLayerPoint;
    sparks.renderMode = kCAEmitterLayerAdditive;

    CAEmitterCell *spark = [CAEmitterCell emitterCell];
    spark.contents = (id)[self sparkParticleImage].CGImage;
    spark.birthRate = 400;
    spark.lifetime = 1.3;
    spark.velocity = 380;
    spark.velocityRange = 220;
    spark.emissionRange = (CGFloat)M_PI * 2;
    spark.scale = 0.22;
    spark.scaleRange = 0.12;
    spark.scaleSpeed = -0.1;
    spark.alphaSpeed = -0.75;
    spark.yAcceleration = 420;  // 重力下落
    spark.spin = 3;
    spark.spinRange = 5;
    spark.color = [UIColor colorWithRed:1.0 green:0.85 blue:0.30 alpha:1.0].CGColor;
    spark.redRange = 0.1;
    spark.greenRange = 0.3;
    spark.blueRange = 0.2;
    sparks.emitterCells = @[spark];
    [host.layer addSublayer:sparks];

    // 瞬间爆发后立即关火星发射
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sparks.birthRate = 0;
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sparks removeFromSuperlayer];
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
    // 温和延长：原 3.8s 太短→消散一瞬间就没了；调到 5.5s 让淡出阶段肉眼可见
    rise.lifetime = 5.5;
    rise.velocity = 25;             // 原 45 → 25（放慢，避免飞出屏顶后才开始淡出）
    rise.velocityRange = 20;
    rise.emissionLongitude = -M_PI_2; // 向上
    rise.emissionRange = M_PI_4 * 0.6; // 稍微加宽一点，更像膨胀烟柱
    rise.scale = 0.32;
    rise.scaleRange = 0.18;
    rise.scaleSpeed = 0.35;         // 膨胀放慢（原 0.5）
    rise.alphaSpeed = -0.18;        // 原 -0.28 → -0.18（5.5s 内线性淡出，整条消散曲线可见）
    rise.spin = 0.5;
    rise.spinRange = 1.0;
    rise.yAcceleration = -12;       // 原 -35 → -12（浮力减弱，不越飞越快）
    // 上升烟更亮（远离爆心）
    rise.color = [UIColor colorWithWhite:0.6 alpha:0.45].CGColor;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    // 兼容保留：当前版本已不再使用（旧 CAEmitter 爆炸方案的遗留），
    // 若未来再用轻量粒子需要亮白小点可以直接取这个。
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
    // 兼容保留：旧 CAEmitter 爆炸方案的遗留。
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

/// 白光核爆贴图：正中心 alpha=1 的纯白，向外经过奶油色快速过渡到透明橙
/// 用作阶段 1 的瞬间白闪；UIImageView 放大 ~7 倍再淡出，就是炸弹起爆白光
+ (UIImage *)flashCoreImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 100;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = {
            1.00, 1.00, 1.00, 1.00,   // 0.0: 纯白中心
            1.00, 0.98, 0.85, 0.70,   // 0.35: 奶油色
            1.00, 0.80, 0.40, 0.00,   // 1.0: 透明橙边缘
        };
        CGFloat locations[] = {0.0, 0.35, 1.0};
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

/// 主火球贴图：黄白核 → 亮橙 → 橙红 → 深红 → 透明的径向渐变
/// 用作阶段 2（核心）和阶段 3（花瓣）的火焰主视觉。
/// 尺寸大 (120pt) 便于放大时仍有细节；多段 location 让颜色过渡更像真实火焰色温
+ (UIImage *)fireballImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 120;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat colors[] = {
            1.00, 0.95, 0.55, 1.00,   // 0.0: 黄白 (火心最热)
            1.00, 0.65, 0.20, 0.95,   // 0.3: 亮橙
            1.00, 0.35, 0.10, 0.75,   // 0.55: 橙红
            0.90, 0.12, 0.00, 0.35,   // 0.8: 深红
            0.50, 0.05, 0.00, 0.00,   // 1.0: 透明
        };
        CGFloat locations[] = {0.0, 0.3, 0.55, 0.8, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, locations, 5);
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
