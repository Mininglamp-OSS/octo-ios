//
//  WKMessageEffectManager.m
//  WuKongBase

#import "WKMessageEffectManager.h"
#import "WKMessageEffectView.h"
#import "WKRocketEffect.h"
#import "WKRocketLaunchEffect.h"
#import "WKStarburstEffect.h"
#import "WKHeartEffect.h"
#import "WKPartyEffect.h"
#import "WKActionVideoEffect.h"
#import "WKClassyVideoEffect.h"
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
@property (nonatomic, strong, nullable) UIImage *pendingAvatarImage;
@property (nonatomic, copy, nullable) NSArray<UIImage *> *pendingMemberAvatars;
@property (nonatomic, assign) BOOL pendingFromSelf;

// 追踪**所有**活跃的 effectView（可能多个并行特效）。弱引用 → view 被 removeFromSuperview
// 后自动从 hash table 中消失，不会导致循环引用或"僵尸"记录。
// 页面退出 cancelCurrentEffect 时需要清理全部，不能只清最后一个。
@property (nonatomic, strong) NSHashTable<WKMessageEffectView *> *activeEffectViews;

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
            @"[使命必达]": @"rocketLaunch",
            @"[崇尚行动]": @"actionVideo",
            @"[有品位]":   @"classyVideo",
        };

        _triggeredMessageIds = [NSMutableOrderedSet orderedSet];
        _activeEffectViews = [NSHashTable weakObjectsHashTable];
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

    // 匹配规则：
    //   - 以 "[" 开头的 key（如 [使命必达]、[有品位]）要求**整条消息恰好就是这个 tag**（去前后空白）——
    //     目的：混在其它文字里的小内联表情不触发特效（用户："和其他文字一起的那种小表情包则不展示动画"）。
    //   - 其它 key（单字符 emoji 💣👍❤️🎉🎊）保留子串匹配——作为 reaction 写在句中也应触发。
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *key in self.effectMap) {
        if ([key hasPrefix:@"["]) {
            if ([trimmed isEqualToString:key]) {
                return self.effectMap[key];
            }
        } else {
            if ([text containsString:key]) {
                return self.effectMap[key];
            }
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
    [self triggerEffect:effectType inHostView:hostView sourceRect:sourceRect avatarImage:nil memberAvatars:nil fromSelf:NO];
}

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage {
    [self triggerEffect:effectType inHostView:hostView sourceRect:sourceRect avatarImage:avatarImage memberAvatars:nil fromSelf:NO];
}

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
        memberAvatars:(nullable NSArray<UIImage *> *)memberAvatars {
    [self triggerEffect:effectType inHostView:hostView sourceRect:sourceRect avatarImage:avatarImage memberAvatars:memberAvatars fromSelf:NO];
}

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
             fromSelf:(BOOL)fromSelf {
    [self triggerEffect:effectType inHostView:hostView sourceRect:sourceRect avatarImage:avatarImage memberAvatars:nil fromSelf:fromSelf];
}

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
        memberAvatars:(nullable NSArray<UIImage *> *)memberAvatars
             fromSelf:(BOOL)fromSelf {

    [self.debounceTimer invalidate];
    self.pendingEffectType = effectType;
    self.pendingSourceRect = sourceRect;
    self.pendingHostView = hostView;
    self.pendingAvatarImage = avatarImage;
    self.pendingMemberAvatars = memberAvatars;
    self.pendingFromSelf = fromSelf;

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

    // 加入活跃集合（弱引用），让 cancelCurrentEffect 能清理所有并行中的特效
    [self.activeEffectViews addObject:effectView];

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
    } else if ([effectType isEqualToString:@"rocketLaunch"]) {
        [WKRocketLaunchEffect playInView:effectView
                              sourceRect:sourceRect
                             avatarImage:self.pendingAvatarImage
                           memberAvatars:self.pendingMemberAvatars];
    } else if ([effectType isEqualToString:@"actionVideo"]) {
        [WKActionVideoEffect playInView:effectView sourceRect:sourceRect];
    } else if ([effectType isEqualToString:@"classyVideo"]) {
        [WKClassyVideoEffect playInView:effectView sourceRect:sourceRect];
    }

    self.pendingEffectType = nil;
    self.pendingAvatarImage = nil;
    self.pendingMemberAvatars = nil;
    self.pendingHostView = nil;
}

- (void)cancelCurrentEffect {
    [self.debounceTimer invalidate];
    self.debounceTimer = nil;
    // 清理**所有**活跃特效（不只最后一个）——快速连发表情时会有多个 effectView 并行跑在 window 上，
    // 离开聊天页面必须把它们全部清掉，避免"回到其他页面还在播"的 bug。
    NSArray<WKMessageEffectView *> *snapshot = [self.activeEffectViews.allObjects copy];
    for (WKMessageEffectView *view in snapshot) {
        [view cleanupSnapshots];
        [view removeFromSuperview];
    }
    [self.activeEffectViews removeAllObjects];
    self.bubblePhysicsActive = NO;
}

@end
