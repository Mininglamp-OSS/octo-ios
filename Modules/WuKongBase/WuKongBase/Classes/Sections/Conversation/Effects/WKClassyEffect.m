//
//  WKClassyEffect.m
//  WuKongBase
//
//  [有品位] 特效：从屏幕顶部降下若干个 👍，每个独立选择若干可见气泡，
//  相邻气泡之间沿二次贝塞尔抛物线跳跃；落地瞬间触发 pulseCell，
//  完成所有落点后再坠落出屏幕。
//
//  关键点：
//    - 每个 👍 的落点序列、arc 高度、落点内偏移、旋转、字号都是独立随机
//    - 抛物线用物理近似（quadratic Bezier，控制点 y = 中点 y - 2*peakHeight）
//    - 每段时长用 sqrt(2h/g) 近似，使大跳落地慢、小跳落地快
//

#import "WKClassyEffect.h"
#import "WKMessageEffectView.h"
#import "WuKongBase.h"
#import "WKMessageCell.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKClassyEffect

#pragma mark - Entry

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    UITableView *tableView = effectView.tableView;

    // 采集可见气泡顶部中心点（effectView 坐标系），按 y 升序
    NSArray<NSValue *> *bubbleTops = [self collectBubbleTopCentersInEffectView:effectView tableView:tableView];
    if (bubbleTops.count == 0) {
        // 没有可见气泡就退化为纯降落
        [self rainFallbackInView:effectView];
        return;
    }

    CGFloat viewH = effectView.bounds.size.height;

    NSInteger totalCount = 10;          // 👍 的数量
    NSTimeInterval spawnWindow = 3.2;   // 入场窗口：拉长节奏，避免扎堆
    NSTimeInterval maxHopEnd = 0;       // 最晚完成时间，决定 effectView 移除

    // 首个气泡作为所有 👍 的入场落点，x 以它为中心轻微散开
    CGPoint firstBubble = [bubbleTops.firstObject CGPointValue];

    // 把入场窗口切成 N 个桶，每个 👍 在自己桶内随机挑一个时刻 —— 保证最小间隔、
    // 同时每次播放的节奏都不一样，不会像按拍子掉落
    NSTimeInterval bucketSize = spawnWindow / (NSTimeInterval)totalCount;

    for (NSInteger i = 0; i < totalCount; i++) {
        NSTimeInterval bucketStart = (NSTimeInterval)i * bucketSize;
        NSTimeInterval jitter = (NSTimeInterval)arc4random_uniform(1000) / 1000.0 * bucketSize;
        NSTimeInterval delay = bucketStart + jitter;

        // 每个 thumb 独立路径：从首个气泡开始，按步长 1/2/3 依次挑选后续气泡
        NSArray<NSValue *> *waypoints = [self pickWaypointsFromAll:bubbleTops];
        if (waypoints.count == 0) continue;

        CGFloat fontSize = 28.0 + (CGFloat)arc4random_uniform(14);   // 28~42
        CGFloat size = fontSize * 1.3;
        // 入场位置：第一个气泡正上方（±14pt 随机偏移），刚好在屏幕外
        CGFloat xStart = firstBubble.x + ((CGFloat)arc4random_uniform(28) - 14);
        CGFloat yStart = -size - 8;

        NSTimeInterval duration = [self buildAndScheduleHopForThumbAtDelay:delay
                                                                 xStart:xStart
                                                                 yStart:yStart
                                                                   size:size
                                                               fontSize:fontSize
                                                              waypoints:waypoints
                                                                  viewH:viewH
                                                             effectView:effectView
                                                              tableView:tableView];

        NSTimeInterval end = delay + duration;
        if (end > maxHopEnd) maxHopEnd = end;
    }

    [effectView scheduleRemovalAfterDelay:maxHopEnd + 0.5];
}

#pragma mark - Per-thumb builder

+ (NSTimeInterval)buildAndScheduleHopForThumbAtDelay:(NSTimeInterval)delay
                                              xStart:(CGFloat)xStart
                                              yStart:(CGFloat)yStart
                                                size:(CGFloat)size
                                            fontSize:(CGFloat)fontSize
                                           waypoints:(NSArray<NSValue *> *)waypoints
                                               viewH:(CGFloat)viewH
                                          effectView:(WKMessageEffectView *)effectView
                                           tableView:(UITableView *)tableView {

    // 预先计算所有段：起点 + 每个气泡落点 + 坠落出屏
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    [points addObject:[NSValue valueWithCGPoint:CGPointMake(xStart, yStart)]];

    for (NSValue *wp in waypoints) {
        CGPoint base = [wp CGPointValue];
        CGFloat dx = (CGFloat)((NSInteger)arc4random_uniform(50) - 25); // 气泡上 ±25pt
        CGPoint landing = CGPointMake(base.x + dx, base.y - size * 0.35); // 踩在顶沿偏上
        [points addObject:[NSValue valueWithCGPoint:landing]];
    }
    // 最后坠落出屏
    CGPoint lastBubble = [points.lastObject CGPointValue];
    CGPoint fallEnd = CGPointMake(lastBubble.x + ((CGFloat)arc4random_uniform(80) - 40), viewH + size);
    [points addObject:[NSValue valueWithCGPoint:fallEnd]];

    // 每段时长：依据 peakHeight 用 sqrt(2h/g) 近似
    const CGFloat g = 1400.0;
    NSMutableArray<NSNumber *> *segDurations = [NSMutableArray array];
    NSMutableArray<NSValue *> *controlPoints = [NSMutableArray array];

    for (NSInteger j = 0; j < (NSInteger)points.count - 1; j++) {
        CGPoint from = [points[j] CGPointValue];
        CGPoint to = [points[j + 1] CGPointValue];
        CGFloat dist = hypot(to.x - from.x, to.y - from.y);
        BOOL isEntry = (j == 0);
        BOOL isFall = (j == (NSInteger)points.count - 2);

        // 弹跳高度：跳得越远，抛物越高（物理感）；入场/坠落是近乎直落
        CGFloat peakH;
        if (isEntry) {
            peakH = 6.0; // 几乎直线落到第一个气泡，避免"飞入"感
        } else if (isFall) {
            peakH = 8.0;
        } else {
            // 主要由水平距离决定：dx 越大 → 抛物越高
            CGFloat dx = fabs(to.x - from.x);
            peakH = 35.0 + dx * 0.35 + (CGFloat)arc4random_uniform(20);
            peakH = MIN(peakH, 130.0);
        }

        // 贝塞尔控制点
        CGFloat midX = (from.x + to.x) / 2.0 + (isEntry ? 0 : ((CGFloat)arc4random_uniform(30) - 15));
        CGFloat topY = MIN(from.y, to.y) - peakH * 2.0;
        [controlPoints addObject:[NSValue valueWithCGPoint:CGPointMake(midX, topY)]];

        // 段时长
        NSTimeInterval segDur;
        if (isEntry) {
            segDur = 0.22 + dist / 2000.0;   // 快速入场
        } else if (isFall) {
            segDur = 0.55;
        } else {
            segDur = 2.0 * sqrt(2.0 * peakH / g);   // 真实重力下的飞行时长
            segDur = MAX(0.22, MIN(0.55, segDur));
        }
        [segDurations addObject:@(segDur)];
    }

    NSTimeInterval totalDur = 0;
    for (NSNumber *d in segDurations) totalDur += d.doubleValue;

    // 采样每段贝塞尔，拼成 values + keyTimes
    const NSInteger samplesPerSeg = 8;
    NSMutableArray *posValues = [NSMutableArray array];
    NSMutableArray *rotValues = [NSMutableArray array];
    NSMutableArray *scaleValues = [NSMutableArray array];
    NSMutableArray<NSNumber *> *keyTimes = [NSMutableArray array];

    [posValues addObject:points.firstObject];
    [rotValues addObject:@(0)];
    [scaleValues addObject:@(1.0)];
    [keyTimes addObject:@(0)];

    NSTimeInterval accT = 0;
    CGFloat accRot = 0;

    for (NSInteger j = 0; j < (NSInteger)segDurations.count; j++) {
        CGPoint p0 = [points[j] CGPointValue];
        CGPoint p2 = [points[j + 1] CGPointValue];
        CGPoint p1 = [controlPoints[j] CGPointValue];
        NSTimeInterval segDur = [segDurations[j] doubleValue];

        // 每段加一次随机旋转增量（非首段/末段才旋转明显些）
        CGFloat rotInc = ((CGFloat)arc4random_uniform(50) - 25) * M_PI / 180.0; // ±25°

        for (NSInteger k = 1; k <= samplesPerSeg; k++) {
            CGFloat u = (CGFloat)k / (CGFloat)samplesPerSeg;
            CGFloat mu = 1.0 - u;
            CGPoint p = CGPointMake(mu * mu * p0.x + 2 * mu * u * p1.x + u * u * p2.x,
                                    mu * mu * p0.y + 2 * mu * u * p1.y + u * u * p2.y);
            [posValues addObject:[NSValue valueWithCGPoint:p]];
            [rotValues addObject:@(accRot + rotInc * u)];

            // 落地前 0.12 的 u 区间做 squash：
            CGFloat scale = 1.0;
            if (k == samplesPerSeg) {
                scale = 0.85; // 触地瞬间挤压
            } else if (k == samplesPerSeg - 1) {
                scale = 0.95;
            } else if (k == 1) {
                scale = 1.08; // 起跳抬起
            }
            [scaleValues addObject:@(scale)];

            NSTimeInterval tAbs = accT + segDur * u;
            [keyTimes addObject:@(tAbs / totalDur)];
        }

        accRot += rotInc;
        accT += segDur;
    }

    // 保证末位 keyTime 为 1（浮点误差兜底）
    keyTimes[keyTimes.count - 1] = @(1.0);

    // 调度生成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (effectView.superview == nil) return;

        UILabel *thumb = [[UILabel alloc] init];
        thumb.text = @"👍";
        thumb.font = [UIFont systemFontOfSize:fontSize];
        thumb.textAlignment = NSTextAlignmentCenter;
        thumb.frame = CGRectMake(0, 0, size, size);
        thumb.center = [points.firstObject CGPointValue];
        [effectView addSubview:thumb];

        CAKeyframeAnimation *posAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        posAnim.values = posValues;
        posAnim.keyTimes = keyTimes;
        posAnim.duration = totalDur;
        posAnim.calculationMode = kCAAnimationLinear;

        CAKeyframeAnimation *rotAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotAnim.values = rotValues;
        rotAnim.keyTimes = keyTimes;
        rotAnim.duration = totalDur;

        CAKeyframeAnimation *scaleAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        scaleAnim.values = scaleValues;
        scaleAnim.keyTimes = keyTimes;
        scaleAnim.duration = totalDur;

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[posAnim, rotAnim, scaleAnim];
        group.duration = totalDur;
        group.fillMode = kCAFillModeForwards;
        group.removedOnCompletion = NO;
        [thumb.layer addAnimation:group forKey:@"classy-hop"];

        // 每个落点时刻 pulse 对应气泡
        NSTimeInterval acc = 0;
        for (NSInteger j = 0; j < (NSInteger)waypoints.count; j++) {
            acc += [segDurations[j] doubleValue]; // 对应 points[j+1]，即 waypoints[j]
            CGPoint targetInView = [points[j + 1] CGPointValue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(acc * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self pulseBubbleAt:targetInView effectView:effectView tableView:tableView];
            });
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((totalDur + 0.1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [thumb removeFromSuperview];
        });
    });

    return totalDur;
}

#pragma mark - Helpers

+ (NSArray<NSValue *> *)collectBubbleTopCentersInEffectView:(WKMessageEffectView *)effectView
                                                 tableView:(UITableView *)tableView {
    if (!tableView) return @[];
    // 只收集「在 effectView 可见区域内」的气泡：
    //   - 上缘被导航/状态栏遮挡的 → 过滤
    //   - 下缘被输入栏/键盘遮挡的 → 过滤
    // effectView 的 frame 已对齐 hostView（WKMessageListView）的可视区域，
    // 以此为裁剪参考即可。
    CGRect visible = effectView.bounds;
    CGFloat topMargin = 4.0;      // 顶部留一点余量
    CGFloat bottomMargin = 12.0;  // 底部为气泡跳起后仍能"踩"留空间

    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    for (UITableViewCell *cell in tableView.visibleCells) {
        UIView *bubble = nil;
        if ([cell isKindOfClass:[WKMessageCell class]]) {
            bubble = ((WKMessageCell *)cell).bubbleBackgroundView;
        }
        if (!bubble || CGRectIsEmpty(bubble.bounds)) continue;
        CGRect frameInEffect = [effectView convertRect:bubble.bounds fromView:bubble];
        if (CGRectIsEmpty(frameInEffect)) continue;

        // 气泡整体需落在 effectView 可见区域内（允许略微切边以容错）
        if (CGRectGetMinY(frameInEffect) < CGRectGetMinY(visible) + topMargin) continue;
        if (CGRectGetMaxY(frameInEffect) > CGRectGetMaxY(visible) - bottomMargin) continue;

        CGPoint topCenter = CGPointMake(CGRectGetMidX(frameInEffect), CGRectGetMinY(frameInEffect));
        [result addObject:[NSValue valueWithCGPoint:topCenter]];
    }
    [result sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
        CGFloat ya = [a CGPointValue].y;
        CGFloat yb = [b CGPointValue].y;
        if (ya < yb) return NSOrderedAscending;
        if (ya > yb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

+ (NSArray<NSValue *> *)pickWaypointsFromAll:(NSArray<NSValue *> *)all {
    NSInteger n = (NSInteger)all.count;
    if (n == 0) return @[];

    // 可视气泡数量 < 4：所有 👍 都挨个踩每一个，避免跳过
    if (n < 4) return all;

    NSMutableArray<NSValue *> *out = [NSMutableArray array];
    [out addObject:all[0]]; // 始终从最顶部气泡开始
    NSInteger cur = 0;

    while (cur < n - 1) {
        // 步长分布：1 ≈60%, 2 ≈40%（最多跨 1 个气泡，不跳过 2 个）
        NSInteger step = (arc4random_uniform(100) < 60) ? 1 : 2;

        NSInteger next = MIN(cur + step, n - 1);
        [out addObject:all[next]];
        cur = next;
    }
    return out;
}

+ (void)pulseBubbleAt:(CGPoint)pointInEffectView
           effectView:(WKMessageEffectView *)effectView
            tableView:(UITableView *)tableView {
    if (!tableView || effectView.superview == nil) return;
    CGPoint pInTable = [effectView convertPoint:pointInEffectView toView:tableView];
    // 向下 1pt 避开顶边误差
    pInTable.y += 1.0;
    NSIndexPath *ip = [tableView indexPathForRowAtPoint:pInTable];
    if (!ip) return;
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:ip];
    if ([cell isKindOfClass:[WKMessageCell class]]) {
        UIView *bubble = ((WKMessageCell *)cell).bubbleBackgroundView;
        if (bubble) {
            [WKBubbleInteractionHelper pulseCell:bubble];
        }
    }
}

#pragma mark - Fallback (no visible bubbles)

+ (void)rainFallbackInView:(WKMessageEffectView *)effectView {
    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;
    for (NSInteger i = 0; i < 10; i++) {
        NSTimeInterval delay = i * 0.1 + (NSTimeInterval)arc4random_uniform(60) / 1000.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (effectView.superview == nil) return;
            CGFloat fs = 28.0 + arc4random_uniform(14);
            CGFloat size = fs * 1.3;
            UILabel *thumb = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
            thumb.text = @"👍";
            thumb.font = [UIFont systemFontOfSize:fs];
            thumb.textAlignment = NSTextAlignmentCenter;
            CGFloat x = arc4random_uniform((uint32_t)MAX(1, viewW - size)) + size / 2;
            thumb.center = CGPointMake(x, -size);
            [effectView addSubview:thumb];
            [UIView animateWithDuration:1.8 delay:0
                                options:UIViewAnimationOptionCurveEaseIn animations:^{
                thumb.center = CGPointMake(x, viewH + size);
            } completion:^(BOOL finished) {
                [thumb removeFromSuperview];
            }];
        });
    }
    [effectView scheduleRemovalAfterDelay:2.5];
}

@end
