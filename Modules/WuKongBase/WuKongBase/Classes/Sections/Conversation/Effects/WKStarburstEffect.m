//
//  WKStarburstEffect.m → 「点赞上升」
//
//  触发：消息文本含 👍
//  视觉：参照 ❤️ 的上升逻辑，多个不同尺寸的 👍 从屏幕底部外侧缓缓飘升到顶部外侧，
//  x 方向做正弦摇摆，生命周期末段淡出。经过可见气泡时让气泡脉冲。
//

#import "WKStarburstEffect.h"
#import "WKMessageEffectView.h"
#import "WuKongBase.h"
#import "WKMessageCell.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKStarburstEffect

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    UITableView *tableView = effectView.tableView;

    CGFloat viewW = effectView.bounds.size.width;
    CGFloat viewH = effectView.bounds.size.height;

    NSMutableArray<UILabel *> *thumbs = [NSMutableArray array];
    NSMutableSet<NSString *> *hits = [NSMutableSet set];

    NSInteger totalCount = 18;
    NSTimeInterval spawnDuration = 2.0;

    for (NSInteger i = 0; i < totalCount; i++) {
        NSTimeInterval delay = (NSTimeInterval)i * (spawnDuration / totalCount);
        delay += (NSTimeInterval)arc4random_uniform(120) / 1000.0;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (effectView.superview == nil) return;

            // 尺寸：22~46pt（和 ❤️ 一致）
            CGFloat fontSize = 22.0 + (CGFloat)(arc4random_uniform(24));
            CGFloat size = fontSize * 1.4;

            UILabel *thumb = [UILabel new];
            thumb.text = @"👍";
            thumb.font = [UIFont systemFontOfSize:fontSize];
            thumb.textAlignment = NSTextAlignmentCenter;
            thumb.frame = CGRectMake(0, 0, size, size);

            // 从底部外侧起飞，往顶部外侧飘走
            CGFloat xStart = (CGFloat)arc4random_uniform((uint32_t)(viewW - size)) + size / 2;
            CGFloat yStart = viewH + size;
            CGFloat yEnd = -size;

            thumb.center = CGPointMake(xStart, yStart);
            thumb.alpha = 0.95;
            [effectView addSubview:thumb];
            [thumbs addObject:thumb];

            NSTimeInterval duration = 2.8 + (NSTimeInterval)(arc4random_uniform(150)) / 100.0; // 2.8~4.3s

            // Y：匀速上升
            CAKeyframeAnimation *yAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
            yAnim.values = @[@(yStart), @(yEnd)];
            yAnim.duration = duration;

            // X：正弦式摆动
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

            // 轻微缩放脉冲（有节奏感）
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
            [thumb.layer addAnimation:group forKey:@"thumb-rise"];
            [thumb.layer addAnimation:scaleAnim forKey:@"thumb-pulse"];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [thumb removeFromSuperview];
                [thumbs removeObject:thumb];
            });
        });
    }

    NSDictionary *timerUserInfo = @{
        @"thumbs": thumbs,
        @"hits": hits,
        @"effectView": effectView,
        @"tableView": tableView ?: (id)[NSNull null],
    };
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.06
                                                      target:self
                                                    selector:@selector(onHitCheckTimer:)
                                                    userInfo:timerUserInfo
                                                     repeats:YES];

    // 2.0s 生成 + 4.3s 上升 ≈ 6.5s 后全部结束
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [timer invalidate];
        for (UILabel *t in thumbs) {
            [t removeFromSuperview];
        }
    });

    [effectView scheduleRemovalAfterDelay:7.5];
}

+ (void)onHitCheckTimer:(NSTimer *)timer {
    NSDictionary *info = timer.userInfo;
    UIView *effectView = info[@"effectView"];
    NSMutableArray<UILabel *> *thumbs = info[@"thumbs"];
    NSMutableSet<NSString *> *hits = info[@"hits"];
    id tableViewAny = info[@"tableView"];
    UITableView *tableView = [tableViewAny isKindOfClass:[UITableView class]] ? (UITableView *)tableViewAny : nil;

    if (!effectView || effectView.superview == nil) {
        [timer invalidate];
        return;
    }
    if (!tableView) return;

    NSArray<UILabel *> *thumbsCopy = [thumbs copy];
    NSArray<UITableViewCell *> *cellsCopy = [tableView.visibleCells copy];

    for (UILabel *thumb in thumbsCopy) {
        if (thumb.superview == nil) continue;
        CALayer *pres = thumb.layer.presentationLayer;
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

            NSString *hitKey = [NSString stringWithFormat:@"%p-%p", thumb, bubble];
            if ([hits containsObject:hitKey]) continue;

            CGRect bubbleFrame = [effectView convertRect:bubble.bounds fromView:bubble];
            if (CGRectIsEmpty(bubbleFrame)) continue;

            if (CGRectIntersectsRect(particleFrame, bubbleFrame)) {
                [hits addObject:hitKey];
                [WKBubbleInteractionHelper pulseCell:bubble];
            }
        }
    }
}

@end
