//
//  WKMessageEffectManager.m
//  WuKongBase

#import "WKMessageEffectManager.h"
#import "WKMessageEffectView.h"
#import "WKRocketEffect.h"
#import "WKStarburstEffect.h"
#import "WKHeartEffect.h"
#import "WKPartyEffect.h"
#import "WKMessageModel.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

static NSString * const kTriggeredIdsDefaultsKey = @"WKMessageEffectTriggeredIds";
static const NSInteger kMaxTriggeredIds = 1000;

@interface WKMessageEffectManager ()

@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *effectMap;
@property (nonatomic, strong, nullable) NSTimer *debounceTimer;
@property (nonatomic, copy, nullable) NSString *pendingEffectType;
@property (nonatomic, assign) CGRect pendingSourceRect;
@property (nonatomic, weak, nullable) UIView *pendingHostView;

// 最近一次特效的弱引用，用于页面退出时兜底清理。
// 不再用来 cancel 上一个特效 —— 多个特效可以并行独立运行。
@property (nonatomic, weak, nullable) WKMessageEffectView *currentEffectView;

// (bubblePhysicsActive 在 public header 中声明)

@property (nonatomic, strong) NSMutableOrderedSet<NSString *> *triggeredMessageIds;
@property (nonatomic, strong, nullable) NSTimer *persistTimer;

@end

@implementation WKMessageEffectManager

+ (instancetype)shared {
    static WKMessageEffectManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKMessageEffectManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _effectMap = @{
            @"💣": @"bomb",
            @"👍": @"thumbsup",
            @"❤️": @"heart",
            @"💗": @"heart",
            @"💕": @"heart",
            @"💖": @"heart",
            @"💘": @"heart",
            @"❤": @"heart",
            @"🎉": @"party",
            @"🎊": @"party",
        };

        _triggeredMessageIds = [NSMutableOrderedSet orderedSet];
        NSArray *persisted = [[NSUserDefaults standardUserDefaults] arrayForKey:kTriggeredIdsDefaultsKey];
        if ([persisted isKindOfClass:[NSArray class]]) {
            for (id item in persisted) {
                if ([item isKindOfClass:[NSString class]]) {
                    [_triggeredMessageIds addObject:item];
                }
            }
        }
    }
    return self;
}

#pragma mark - Detection

- (nullable NSString *)effectTypeForMessage:(WKMessageModel *)message {
    if (message.contentType != 1) return nil;

    WKTextContent *textContent = (WKTextContent *)message.content;
    if (![textContent isKindOfClass:[WKTextContent class]]) return nil;

    NSString *text = textContent.content;
    if (!text || text.length == 0) return nil;

    for (NSString *emoji in self.effectMap) {
        if ([text containsString:emoji]) {
            return self.effectMap[emoji];
        }
    }
    return nil;
}

- (BOOL)hasTriggeredForMessage:(WKMessageModel *)message {
    NSString *msgId = message.clientMsgNo;
    if (!msgId) return NO;
    return [self.triggeredMessageIds containsObject:msgId];
}

- (void)markTriggeredForMessage:(WKMessageModel *)message {
    NSString *msgId = message.clientMsgNo;
    if (!msgId) return;
    [self.triggeredMessageIds addObject:msgId];
    while (self.triggeredMessageIds.count > kMaxTriggeredIds) {
        [self.triggeredMessageIds removeObjectAtIndex:0];
    }
    [self schedulePersist];
}

- (void)schedulePersist {
    if (self.persistTimer) return;
    self.persistTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(persistNow)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)persistNow {
    self.persistTimer = nil;
    NSArray *arr = [self.triggeredMessageIds array];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:kTriggeredIdsDefaultsKey];
}

#pragma mark - Trigger

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect {

    [self.debounceTimer invalidate];
    self.pendingEffectType = effectType;
    self.pendingSourceRect = sourceRect;
    self.pendingHostView = hostView;

    self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                         target:self
                                                       selector:@selector(firePendingEffect)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)firePendingEffect {
    UIView *hostView = self.pendingHostView;
    NSString *effectType = self.pendingEffectType;
    if (!hostView || !effectType) return;

    // ⚠️ 不再 cancelCurrentEffect —— 让已有特效独立完成，多个特效可并行

    UIWindow *window = hostView.window ?: UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    // 顶层 effectView（挂 window）：装炸弹轨迹、💥、粒子、冲击波等需要置顶的视觉
    CGRect hostFrameInWindow = [hostView convertRect:hostView.bounds toView:window];
    WKMessageEffectView *effectView = [[WKMessageEffectView alloc] initWithFrame:hostFrameInWindow];
    effectView.sourceHostView = hostView;
    for (UIView *sub in hostView.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            effectView.tableView = (UITableView *)sub;
            break;
        }
    }
    [window addSubview:effectView];

    self.currentEffectView = effectView;

    // 气泡物理用 tableView 作为承载层（和真实 cell 同层，滚动时一起滚动，视觉一致）
    // 不再单独创建 bubbleLayer

    // sourceRect：从 hostView 坐标系转到 effectView 坐标系
    CGRect sourceRect = CGRectZero;
    if (!CGRectIsEmpty(self.pendingSourceRect)) {
        sourceRect = [hostView convertRect:self.pendingSourceRect toView:effectView];
    }

    if ([effectType isEqualToString:@"bomb"]) {
        [WKRocketEffect playInView:effectView sourceRect:sourceRect];
    } else if ([effectType isEqualToString:@"thumbsup"]) {
        [WKStarburstEffect playInView:effectView sourceRect:sourceRect];
    } else if ([effectType isEqualToString:@"heart"]) {
        [WKHeartEffect playInView:effectView sourceRect:sourceRect];
    } else if ([effectType isEqualToString:@"party"]) {
        [WKPartyEffect playInView:effectView sourceRect:sourceRect];
    }

    self.pendingEffectType = nil;
    self.pendingHostView = nil;
}

- (void)cancelCurrentEffect {
    [self.debounceTimer invalidate];
    self.debounceTimer = nil;
    // 兜底把最近一个特效的快照恢复（否则原 cell 会一直隐藏）
    [self.currentEffectView cleanupSnapshots];
    [self.currentEffectView removeFromSuperview];
    self.currentEffectView = nil;
    self.bubblePhysicsActive = NO;
}

@end
