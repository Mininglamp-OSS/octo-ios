// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKHeartEffect.m
//
//  爱心心形绽放 — 以触发气泡中心为起点，多个 ❤️ 向外飞散并在空中
//  组合成一颗心形；心跳脉冲后沿径向继续飘散并淡出。经过可见气泡时
//  让气泡柔和脉冲。

#import "WKHeartEffect.h"
#import "WKMessageEffectView.h"
#import "WuKongBase.h"
#import "WKMessageCell.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKHeartEffect

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    UITableView *tableView = effectView.tableView;

    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;

    // 发射原点：优先气泡中心（保留从消息爆出的仪式感），否则屏幕中心
    CGPoint launch;
    if (!CGRectIsEmpty(sourceRect) && !CGRectIsNull(sourceRect)) {
        launch = CGPointMake(CGRectGetMidX(sourceRect), CGRectGetMidY(sourceRect));
    } else {
        launch = CGPointMake(viewW / 2.0, viewH / 2.0);
    }

    // 心形参数方程外延：x ∈ [-16, 16], y ∈ [-17, 5]（UIKit 下取负）
    // 构图中心到边的最小余量：左右 16k + pad，上 5k + pad，下 17k + pad
    CGFloat pad = 12.0;
    CGFloat k0 = MIN(viewW, viewH) / 45.0; // 舒服尺寸：整幅约 viewW*0.7

    // 以 k0 能否放下为前提，先求安全矩形；若 view 过小则按最大可行 k 收缩
    CGFloat k = k0;
    CGFloat minX = 16.0 * k + pad;
    CGFloat maxX = viewW - 16.0 * k - pad;
    CGFloat minY = 5.0 * k + pad;
    CGFloat maxY = viewH - 17.0 * k - pad;
    if (minX > maxX || minY > maxY) {
        CGFloat kByW = (viewW - 2.0 * pad) / 32.0;
        CGFloat kByH = (viewH - 2.0 * pad) / 22.0;
        k = MIN(kByW, kByH);
        if (k < 3.0) k = 3.0;
        minX = 16.0 * k + pad;
        maxX = viewW - 16.0 * k - pad;
        minY = 5.0 * k + pad;
        maxY = viewH - 17.0 * k - pad;
    }

    // 把发射原点夹取到安全矩形里当作构图中心；若夹取位移过大，等比缩小 k
    // 让心形可以更靠近气泡，避免被推到屏幕正中、失去与气泡的关联
    CGPoint compCenter = CGPointMake(MAX(minX, MIN(maxX, launch.x)),
                                     MAX(minY, MIN(maxY, launch.y)));
    CGFloat dx = fabs(compCenter.x - launch.x);
    CGFloat dy = fabs(compCenter.y - launch.y);
    CGFloat maxDisp = MIN(viewW, viewH) * 0.12;
    if (dx > maxDisp || dy > maxDisp) {
        CGFloat shrink = maxDisp / MAX(dx, dy);
        if (shrink < 0.55) shrink = 0.55; // 最多缩到 55%，保证仍然看得清
        k = k * shrink;
        minX = 16.0 * k + pad;
        maxX = viewW - 16.0 * k - pad;
        minY = 5.0 * k + pad;
        maxY = viewH - 17.0 * k - pad;
        compCenter = CGPointMake(MAX(minX, MIN(maxX, launch.x)),
                                 MAX(minY, MIN(maxY, launch.y)));
    }

    NSMutableArray<UILabel *> *hearts = [NSMutableArray array];
    NSMutableSet<NSString *> *hits = [NSMutableSet set];
    NSArray<NSString *> *heartVariants = @[@"❤️", @"💗", @"💕", @"💖", @"💘"];

    NSInteger totalCount = 26;
    NSTimeInterval flyDuration = 0.9;
    NSTimeInterval beatDuration = 0.75;
    NSTimeInterval scatterDuration = 0.7;
    NSTimeInterval totalLife = flyDuration + beatDuration + scatterDuration;

    for (NSInteger i = 0; i < totalCount; i++) {
        // 均匀分布的角度 + 小幅抖动，避免"机械对称"
        CGFloat baseT = 2.0 * M_PI * ((CGFloat)i / (CGFloat)totalCount);
        CGFloat jitter = ((CGFloat)arc4random_uniform(100) / 100.0 - 0.5)
                         * (2.0 * M_PI / (CGFloat)totalCount) * 0.4;
        CGFloat t = baseT + jitter;

        CGFloat sinT = sin(t);
        CGFloat heartX = 16.0 * sinT * sinT * sinT;
        CGFloat heartY = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t);
        CGFloat targetX = compCenter.x + k * heartX;
        CGFloat targetY = compCenter.y - k * heartY; // UIKit y 向下

        CGFloat fontSize = 22.0 + (CGFloat)arc4random_uniform(15); // 22~36pt
        CGFloat size = fontSize * 1.4;

        UILabel *heart = [UILabel new];
        heart.text = heartVariants[arc4random_uniform((uint32_t)heartVariants.count)];
        heart.font = [UIFont systemFontOfSize:fontSize];
        heart.textAlignment = NSTextAlignmentCenter;
        heart.frame = CGRectMake(0, 0, size, size);
        heart.center = launch;
        heart.alpha = 0;
        heart.transform = CGAffineTransformMakeScale(0.15, 0.15);
        [effectView addSubview:heart];
        [hearts addObject:heart];

        NSTimeInterval staggerDelay = 0.012 * (NSTimeInterval)(i % 6);

        // Phase 1：从气泡中心弹飞到心形轮廓目标点
        [UIView animateWithDuration:flyDuration
                              delay:staggerDelay
             usingSpringWithDamping:0.72
              initialSpringVelocity:0.9
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            heart.center = CGPointMake(targetX, targetY);
            heart.alpha = 0.95;
            heart.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (heart.superview == nil) return;

            // Phase 2：就地心跳脉冲 2 次（CAKeyframe 不影响 UIView 的模型 transform）
            CAKeyframeAnimation *pulse = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            pulse.values = @[@(1.0), @(1.14), @(0.94), @(1.1), @(1.0)];
            pulse.keyTimes = @[@0.0, @0.25, @0.5, @0.75, @1.0];
            pulse.duration = beatDuration;
            [heart.layer addAnimation:pulse forKey:@"heart-beat"];

            // Phase 3：沿"构图中心 → 目标点"方向继续外飘并淡出
            CGFloat vx = targetX - compCenter.x;
            CGFloat vy = targetY - compCenter.y;
            CGFloat len = sqrt(vx * vx + vy * vy);
            CGFloat extend = 38.0 + (CGFloat)arc4random_uniform(26);
            CGFloat endX = targetX;
            CGFloat endY = targetY;
            if (len > 0.5) {
                endX = targetX + vx / len * extend;
                endY = targetY + vy / len * extend;
            } else {
                endY = targetY - extend; // 刚好在中心的极少数点，往上飘
            }

            [UIView animateWithDuration:scatterDuration
                                  delay:beatDuration
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                heart.center = CGPointMake(endX, endY);
                heart.alpha = 0.0;
                heart.transform = CGAffineTransformMakeScale(0.85, 0.85);
            } completion:^(BOOL done) {
                [heart removeFromSuperview];
                [hearts removeObject:heart];
            }];
        }];
    }

    // 气泡联动脉冲：沿用原有碰撞检测（心形飞散过程中经过可见气泡会让气泡跳一下）
    NSDictionary *timerInfo = @{
        @"items": hearts,
        @"hits": hits,
        @"effectView": effectView,
        @"tableView": tableView ?: (id)[NSNull null],
    };
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.06
                                                      target:self
                                                    selector:@selector(onHitTimer:)
                                                    userInfo:timerInfo
                                                     repeats:YES];

    NSTimeInterval cleanupDelay = totalLife + 0.3;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [timer invalidate];
        for (UILabel *h in hearts) [h removeFromSuperview];
    });

    [effectView scheduleRemovalAfterDelay:cleanupDelay + 0.3];
}

+ (void)onHitTimer:(NSTimer *)timer {
    NSDictionary *info = timer.userInfo;
    UIView *effectView = info[@"effectView"];
    NSMutableArray<UILabel *> *items = info[@"items"];
    NSMutableSet<NSString *> *hits = info[@"hits"];
    id tv = info[@"tableView"];
    UITableView *tableView = [tv isKindOfClass:[UITableView class]] ? (UITableView *)tv : nil;

    if (!effectView || effectView.superview == nil) { [timer invalidate]; return; }
    if (!tableView) return;

    NSArray *itemsCopy = [items copy];
    NSArray *cellsCopy = [tableView.visibleCells copy];
    for (UILabel *item in itemsCopy) {
        if (item.superview == nil) continue;
        CALayer *pres = item.layer.presentationLayer;
        if (!pres) continue;
        CGPoint center = pres.position;
        CGSize size = pres.bounds.size;
        CGRect particleFrame = CGRectMake(center.x - size.width / 2,
                                          center.y - size.height / 2,
                                          size.width, size.height);

        for (UITableViewCell *cell in cellsCopy) {
            UIView *bubble = nil;
            if ([cell isKindOfClass:[WKMessageCell class]]) {
                bubble = ((WKMessageCell *)cell).bubbleBackgroundView;
            }
            if (!bubble) continue;

            NSString *key = [NSString stringWithFormat:@"%p-%p", item, bubble];
            if ([hits containsObject:key]) continue;

            CGRect bubbleFrame = [effectView convertRect:bubble.bounds fromView:bubble];
            if (CGRectIsEmpty(bubbleFrame)) continue;

            if (CGRectIntersectsRect(particleFrame, bubbleFrame)) {
                [hits addObject:key];
                [WKBubbleInteractionHelper pulseCell:bubble];
            }
        }
    }
}

@end
