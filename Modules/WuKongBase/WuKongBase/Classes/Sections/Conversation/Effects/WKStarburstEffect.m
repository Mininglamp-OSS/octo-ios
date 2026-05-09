//
//  WKStarburstEffect.m → 「点赞雨」
//
//  触发：消息文本含 👍
//  视觉：大量不同大小的 👍 从屏幕顶部各个位置陆续降落，像真实雨滴
//    - 数量多（~18 个）、尺寸小（30~55pt）、持续时间长（~2s 生成 + 2~3s 下落）
//    - X 位置完全随机（而不是均匀分布），有真实"随风"的感觉
//    - 定时器检测 👍 经过可见气泡时让气泡脉冲

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
        // 每个 👍 出现的时间随机分布，避免「一波一波」的倒出感
        NSTimeInterval delay = (NSTimeInterval)i * (spawnDuration / totalCount);
        delay += (NSTimeInterval)arc4random_uniform(80) / 1000.0; // ±80ms 抖动

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (effectView.superview == nil) return;

            // 尺寸缩小：30~55pt（之前 54~94 太大）
            CGFloat fontSize = 30.0 + (CGFloat)(arc4random_uniform(26));
            CGFloat size = fontSize * 1.3;

            UILabel *thumb = [UILabel new];
            thumb.text = @"👍";
            thumb.font = [UIFont systemFontOfSize:fontSize];
            thumb.textAlignment = NSTextAlignmentCenter;
            thumb.frame = CGRectMake(0, 0, size, size);

            // X 完全随机（不按下标均分），真正雨滴感
            CGFloat xStart = (CGFloat)arc4random_uniform((uint32_t)(viewW - size)) + size / 2;
            CGFloat xDrift = (CGFloat)(arc4random_uniform(60)) - 30; // 下落过程中轻微漂移
            CGFloat yStart = -size;
            CGFloat yEnd = viewH + size;

            thumb.center = CGPointMake(xStart, yStart);
            [effectView addSubview:thumb];
            [thumbs addObject:thumb];

            // 每滴下落时长不同，节奏感更自然
            NSTimeInterval duration = 1.8 + (NSTimeInterval)(arc4random_uniform(120)) / 100.0; // 1.8~3.0s

            // Y：轻度 ease-in，避免开局过慢
            CAKeyframeAnimation *yAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
            yAnim.values = @[@(yStart), @(yEnd)];
            yAnim.keyTimes = @[@0, @1];
            yAnim.timingFunctions = @[[CAMediaTimingFunction functionWithControlPoints:0.4 :0 :0.7 :1]];
            yAnim.duration = duration;

            // X：微漂移（小幅度摇摆，不过度）
            CAKeyframeAnimation *xAnim = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
            CGFloat swayMid1 = xStart + xDrift * 0.4;
            CGFloat swayMid2 = xStart + xDrift * 0.7;
            xAnim.values = @[@(xStart), @(swayMid1), @(swayMid2), @(xStart + xDrift)];
            xAnim.duration = duration;

            // 旋转：轻微，避免 emoji 翻倒显得奇怪
            CABasicAnimation *rotAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            rotAnim.fromValue = @(0);
            CGFloat targetRot = ((CGFloat)(arc4random_uniform(200)) / 100.0) - 1.0; // -1 ~ +1 弧度
            rotAnim.toValue = @(targetRot);
            rotAnim.duration = duration;

            CAAnimationGroup *group = [CAAnimationGroup animation];
            group.animations = @[yAnim, xAnim, rotAnim];
            group.duration = duration;
            group.fillMode = kCAFillModeForwards;
            group.removedOnCompletion = NO;
            [thumb.layer addAnimation:group forKey:@"thumb-rain"];

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
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                      target:self
                                                    selector:@selector(onHitCheckTimer:)
                                                    userInfo:timerUserInfo
                                                     repeats:YES];

    // 最晚 2.0s 生成 + 3.0s 下落 = 5s 后全部结束
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [timer invalidate];
        for (UILabel *t in thumbs) {
            [t removeFromSuperview];
        }
    });

    [effectView scheduleRemovalAfterDelay:5.5];
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
        // 粒子实际矩形
        CGRect particleFrame = CGRectMake(center.x - size.width / 2,
                                          center.y - size.height / 2,
                                          size.width, size.height);

        for (UITableViewCell *cell in cellsCopy) {
            // 精确到「气泡本身」的矩形，不再用整个 cell 的 row
            UIView *bubble = nil;
            if ([cell isKindOfClass:[WKMessageCell class]]) {
                bubble = ((WKMessageCell *)cell).bubbleBackgroundView;
            }
            if (!bubble) continue;

            NSString *hitKey = [NSString stringWithFormat:@"%p-%p", thumb, bubble];
            if ([hits containsObject:hitKey]) continue;

            CGRect bubbleFrame = [effectView convertRect:bubble.bounds fromView:bubble];
            if (CGRectIsEmpty(bubbleFrame)) continue;

            // 真矩形碰撞（粒子 ∩ 气泡）
            if (CGRectIntersectsRect(particleFrame, bubbleFrame)) {
                [hits addObject:hitKey];
                // 只脉冲气泡本身，不摇整个 cell
                [WKBubbleInteractionHelper pulseCell:bubble];
            }
        }
    }
}

@end
