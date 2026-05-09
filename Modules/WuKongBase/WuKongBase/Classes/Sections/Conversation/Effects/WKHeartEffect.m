//
//  WKHeartEffect.m
//
//  爱心上升 — 多个不同尺寸、颜色的 ❤️ 从底部缓缓飘升到顶部，
//  带自然左右摆动。经过可见气泡时让气泡脉冲（心跳感）。

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

    NSMutableArray<UILabel *> *hearts = [NSMutableArray array];
    NSMutableSet<NSString *> *hits = [NSMutableSet set];

    // 爱心使用多种变体以视觉多样
    NSArray<NSString *> *heartVariants = @[@"❤️", @"💗", @"💕", @"💖", @"💘"];

    NSInteger totalCount = 22;
    NSTimeInterval spawnDuration = 2.2;

    for (NSInteger i = 0; i < totalCount; i++) {
        NSTimeInterval delay = (NSTimeInterval)i * (spawnDuration / totalCount);
        delay += (NSTimeInterval)arc4random_uniform(120) / 1000.0;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (effectView.superview == nil) return;

            CGFloat fontSize = 22.0 + (CGFloat)(arc4random_uniform(24)); // 22~46pt
            CGFloat size = fontSize * 1.4;

            UILabel *heart = [UILabel new];
            heart.text = heartVariants[arc4random_uniform((uint32_t)heartVariants.count)];
            heart.font = [UIFont systemFontOfSize:fontSize];
            heart.textAlignment = NSTextAlignmentCenter;
            heart.frame = CGRectMake(0, 0, size, size);

            CGFloat xStart = (CGFloat)arc4random_uniform((uint32_t)(viewW - size)) + size / 2;
            CGFloat yStart = viewH + size;
            CGFloat yEnd = -size;

            heart.center = CGPointMake(xStart, yStart);
            heart.alpha = 0.95;
            [effectView addSubview:heart];
            [hearts addObject:heart];

            NSTimeInterval duration = 2.8 + (NSTimeInterval)(arc4random_uniform(150)) / 100.0; // 2.8~4.3s

            // Y：匀速上升（缓慢浮力感）
            CAKeyframeAnimation *yAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
            yAnim.values = @[@(yStart), @(yEnd)];
            yAnim.duration = duration;

            // X：正弦式左右摇摆（比直线更自然）
            CAKeyframeAnimation *xAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
            CGFloat swayAmp = 20.0 + (CGFloat)arc4random_uniform(25);
            xAnim.values = @[
                @(xStart),
                @(xStart + swayAmp),
                @(xStart),
                @(xStart - swayAmp * 0.8),
                @(xStart + swayAmp * 0.5),
                @(xStart),
            ];
            xAnim.duration = duration;

            // 轻微缩放脉冲（心跳感）
            CAKeyframeAnimation *scaleAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            scaleAnim.values = @[@(0.9), @(1.1), @(0.95), @(1.05), @(1.0)];
            scaleAnim.duration = 1.0;
            scaleAnim.repeatCount = HUGE_VALF;

            // 末段淡出
            CAKeyframeAnimation *fadeAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
            fadeAnim.values = @[@(0.95), @(0.95), @(0)];
            fadeAnim.keyTimes = @[@0, @0.7, @1.0];
            fadeAnim.duration = duration;

            CAAnimationGroup *group = [CAAnimationGroup animation];
            group.animations = @[yAnim, xAnim, fadeAnim];
            group.duration = duration;
            group.fillMode = kCAFillModeForwards;
            group.removedOnCompletion = NO;
            [heart.layer addAnimation:group forKey:@"heart-rise"];
            [heart.layer addAnimation:scaleAnim forKey:@"heart-beat"];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [heart removeFromSuperview];
                [hearts removeObject:heart];
            });
        });
    }

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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [timer invalidate];
        for (UILabel *h in hearts) [h removeFromSuperview];
    });

    [effectView scheduleRemovalAfterDelay:7.5];
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
