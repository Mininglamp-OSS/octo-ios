// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAITextIngestor.m
//  WuKongBase
//

#import "WKAITextIngestor.h"
#import "WKMessageCell.h"
#import "WKMessageModel.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongIMSDK/WKTextContent.h>

static const NSTimeInterval kSpawnIntervalIdle   = 0.55;
static const NSTimeInterval kSpawnIntervalActive = 0.28;

// 飞行片段的字体：略大、加粗，让"信息感"更明显
static const CGFloat kFragmentFontSize = 13.0;
// 单段字符长度（Composed character count，Chinese-aware）
// 完整短句的合理长度：太短没信息感，太长视觉拥挤
static const NSInteger kFragmentMinChars = 2;
static const NSInteger kFragmentMaxChars = 14;

// 起点环：按钮外圈 +14pt；终点环：按钮中心附近一个小圆内
static const CGFloat kStartRingExtra  = 14.0;
static const CGFloat kEndRingFactor   = 0.20; // 相对按钮半径

@interface WKAITextIngestor ()
@property(nonatomic, weak) UIView *messageListView;
@property(nonatomic, weak) UITableView *tableView;
@property(nonatomic, weak) UIView *destination;
@property(nonatomic, strong) CADisplayLink *timer;
@property(nonatomic, assign) NSTimeInterval lastSpawn;
/// 已显示过的片段 —— 一轮内不重复，全部出过一次后清空再来
@property(nonatomic, strong) NSMutableSet<NSString *> *seenFragments;
@end

@implementation WKAITextIngestor

- (instancetype)initWithMessageListView:(UIView *)mlv
                              tableView:(UITableView *)tv
                            destination:(UIView *)dest {
    if ((self = [super init])) {
        _messageListView = mlv;
        _tableView = tv;
        _destination = dest;
        _seenFragments = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc { [self stop]; }

#pragma mark - Lifecycle

- (void)start {
    if (self.timer || UIAccessibilityIsReduceMotionEnabled()) return;
    self.timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.timer.preferredFramesPerSecond = 15; // 调度足够，省 CPU
    [self.timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)setActive:(BOOL)active { _active = active; }

#pragma mark - Tick

- (void)tick:(CADisplayLink *)link {
    NSTimeInterval interval = self.active ? kSpawnIntervalActive : kSpawnIntervalIdle;
    if (link.timestamp - self.lastSpawn < interval) return;
    if (!self.messageListView || self.messageListView.window == nil) return; // 不在屏不消耗
    [self spawnOneFragment];
    self.lastSpawn = link.timestamp;
}

#pragma mark - Spawn

- (void)spawnOneFragment {
    UITableView *tv = self.tableView;
    if (!tv) return;
    NSArray<NSIndexPath *> *paths = tv.indexPathsForVisibleRows;
    if (paths.count == 0) return;

    // 收集所有可见 cell 的全部合格片段（不去 cell 维度采样，直接进入字段池）
    NSMutableArray<NSString *> *allFragments = [NSMutableArray array];
    for (NSIndexPath *ip in paths) {
        UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
        if (![cell isKindOfClass:WKMessageCell.class]) continue;
        WKMessageCell *mcell = (WKMessageCell *)cell;
        WKMessageModel *model = mcell.messageModel;
        if (!model || ![model.content isKindOfClass:WKTextContent.class]) continue;
        NSString *text = ((WKTextContent *)model.content).content;
        [allFragments addObjectsFromArray:[self extractAllFragments:text]];
    }
    if (allFragments.count == 0) return;

    // 去重池：先剔除已展示过的；如果 unseen 空了说明本轮过完，清空 seenSet 重新开始
    NSMutableArray<NSString *> *unseen = [NSMutableArray array];
    for (NSString *f in allFragments) {
        if (![self.seenFragments containsObject:f]) [unseen addObject:f];
    }
    if (unseen.count == 0) {
        [self.seenFragments removeAllObjects];
        [unseen addObjectsFromArray:allFragments];
    }

    NSString *fragment = unseen[arc4random_uniform((uint32_t)unseen.count)];
    [self.seenFragments addObject:fragment];
    [self animateFragment:fragment];
}

/// 从一段文本中切出所有"完整短语"（按标点切，长度 [min, max]）
- (NSArray<NSString *> *)extractAllFragments:(NSString *)text {
    if (text.length == 0) return @[];

    // 切分隔符：CJK 标点 + ASCII 标点 + 空白 + 符号
    static NSCharacterSet *seps = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *m = [NSMutableCharacterSet new];
        [m formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
        [m formUnionWithCharacterSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [m formUnionWithCharacterSet:NSCharacterSet.symbolCharacterSet];
        seps = [m copy];
    });

    NSArray<NSString *> *segments = [text componentsSeparatedByCharactersInSet:seps];
    NSMutableArray<NSString *> *good = [NSMutableArray array];
    for (NSString *s in segments) {
        NSInteger n = [self composedCount:s];
        if (n >= kFragmentMinChars && n <= kFragmentMaxChars) [good addObject:s];
    }
    return good;
}

- (NSInteger)composedCount:(NSString *)s {
    __block NSInteger n = 0;
    [s enumerateSubstringsInRange:NSMakeRange(0, s.length)
                          options:NSStringEnumerationByComposedCharacterSequences
                       usingBlock:^(NSString *sub, NSRange r, NSRange er, BOOL *stop) {
        n++;
    }];
    return n;
}

#pragma mark - Animate

- (void)animateFragment:(NSString *)text {
    UIView *parent = self.messageListView;
    UIView *target = self.destination;
    if (!parent || !target) return;

    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:kFragmentFontSize weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    // 暗底也读得清：黑色 1pt 阴影 + 白色微 glow
    label.layer.shadowColor = [UIColor blackColor].CGColor;
    label.layer.shadowOffset = CGSizeMake(0, 1);
    label.layer.shadowRadius = 2.5;
    label.layer.shadowOpacity = 0.65;
    label.userInteractionEnabled = NO;
    [label sizeToFit];
    label.alpha = 0;

    // 几何：在按钮外圈随机角度生点，沿径向飞向按钮中心附近
    CGPoint btnCenter = [parent convertPoint:CGPointMake(target.bounds.size.width  / 2.0,
                                                          target.bounds.size.height / 2.0)
                                    fromView:target];
    CGFloat btnRadius = target.bounds.size.width / 2.0;
    CGFloat startR = btnRadius + kStartRingExtra;
    CGFloat endR   = btnRadius * kEndRingFactor;
    CGFloat angle  = (CGFloat)arc4random_uniform(360) * (CGFloat)M_PI / 180.0;
    CGPoint startCenter = CGPointMake(btnCenter.x + startR * cos(angle),
                                      btnCenter.y + startR * sin(angle));
    CGPoint endCenter   = CGPointMake(btnCenter.x + endR   * cos(angle),
                                      btnCenter.y + endR   * sin(angle));

    label.center = startCenter;
    [parent addSubview:label];

    // 时长 1.4~1.9s（用户要求慢）
    NSTimeInterval duration = 1.4 + (arc4random_uniform(50) / 100.0);

    [UIView animateKeyframesWithDuration:duration
                                   delay:0
                                 options:UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        // alpha keyframes：保留半透明溶解感
        // 0% → 0   (起点完全透明)
        // 25% → 0.95 (淡入到峰值)
        // 70% → 0.6  (一路保持半透明)
        // 100% → 0  (溶解进按钮)
        [UIView addKeyframeWithRelativeStartTime:0.0  relativeDuration:0.25 animations:^{
            label.alpha = 0.95;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.25 relativeDuration:0.45 animations:^{
            label.alpha = 0.65;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.70 relativeDuration:0.30 animations:^{
            label.alpha = 0.0;
        }];

        // 位置 + scale 全程
        [UIView addKeyframeWithRelativeStartTime:0.0  relativeDuration:1.0 animations:^{
            label.center = endCenter;
            label.transform = CGAffineTransformMakeScale(0.55, 0.55);
        }];
    } completion:^(BOOL finished) {
        [label removeFromSuperview];
    }];
}

@end
