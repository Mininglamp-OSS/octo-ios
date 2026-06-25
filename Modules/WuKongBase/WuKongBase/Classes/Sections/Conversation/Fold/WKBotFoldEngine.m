//
//  WKBotFoldEngine.m
//  WuKongBase
//

#import "WKBotFoldEngine.h"
#import "WKConstant.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

#pragma mark - 五类边界 content type 集合

static NSSet<NSNumber *> *WKBotFoldBoundaryTypes(void) {
    static NSSet<NSNumber *> *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 与 web `vm.ts hasFileAttachment()` 完全一致：image/gif/smallVideo/file/richText。
        // voice=4 不在内（语音可折叠）。
        s = [NSSet setWithArray:@[ @(WK_IMAGE),       // 2
                                   @(WK_GIF),         // 3
                                   @(WK_SMALLVIDEO),  // 5
                                   @(WK_FILE),        // 8
                                   @(WK_RICHTEXT) ]]; // 14
    });
    return s;
}

#pragma mark - WKBotFoldSession

@implementation WKBotFoldSession
- (instancetype)initWithMessages:(NSArray<WKMessageModel *> *)messages
                    participants:(NSArray<WKChannelInfo *> *)participants
                        isActive:(BOOL)isActive
                        expanded:(BOOL)expanded {
    if (self = [super init]) {
        _messages = [messages copy] ?: @[];
        _participants = [participants copy] ?: @[];
        _isActive = isActive;
        _expanded = expanded;
    }
    return self;
}
@end

#pragma mark - WKBotFoldRenderItem

@interface WKBotFoldRenderItem ()
@property(nonatomic, assign, readwrite) WKBotFoldRenderItemType type;
@property(nonatomic, strong, readwrite, nullable) WKMessageModel *message;
@property(nonatomic, strong, readwrite, nullable) WKBotFoldSession *foldSession;
@end

@implementation WKBotFoldRenderItem
+ (instancetype)itemWithMessage:(WKMessageModel *)message {
    WKBotFoldRenderItem *item = [WKBotFoldRenderItem new];
    item.type = WKBotFoldRenderItemTypeMessage;
    item.message = message;
    return item;
}
+ (instancetype)itemWithFoldSession:(WKBotFoldSession *)foldSession {
    WKBotFoldRenderItem *item = [WKBotFoldRenderItem new];
    item.type = WKBotFoldRenderItemTypeFoldSession;
    item.foldSession = foldSession;
    return item;
}
@end

#pragma mark - WKBotFoldEngineConfig

@implementation WKBotFoldEngineConfig
+ (instancetype)defaultConfig {
    WKBotFoldEngineConfig *c = [WKBotFoldEngineConfig new];
    c.minGroupSize = 2;
    c.gapThreshold = 120;
    c.activeWindow = 120;
    c.isChannelGroup = NO;
    c.isChannelRobot = NO;
    c.disabled = NO;
    c.referenceTimestamp = 0;
    return c;
}
@end

#pragma mark - WKBotFoldEngine

@implementation WKBotFoldEngine

#pragma mark 公开判定函数

+ (BOOL)isFoldBoundaryAttachment:(WKMessageModel *)message {
    if (!message) return NO;
    return [WKBotFoldBoundaryTypes() containsObject:@(message.contentType)];
}

+ (BOOL)isFoldableBotMessage:(WKMessageModel *)message {
    if (!message) return NO;
    if (message.isSend) return NO;                          // 自己发的不折
    if ([self isFoldBoundaryAttachment:message]) return NO; // 五类边界
    NSInteger ct = message.contentType;
    if (ct == WK_TYPING) return NO;       // 101
    if (ct == WK_SCREENSHOT) return NO;   // 20
    if (ct >= 1000) return NO;            // 系统消息 1000+
    if (ct <= 0) return NO;               // 异常 / unknown
    return YES;
}

#pragma mark 私有：bot 判定（三层 fallback）

- (BOOL)isBotSentMessage:(WKMessageModel *)m withConfig:(WKBotFoldEngineConfig *)config {
    if (config.botMessageJudge) {
        return config.botMessageJudge(m);
    }
    // fallback 1: from（WKChannelInfo）robot 字段
    if (m.from && m.from.robot) return YES;
    // fallback 2: 消息正文带 robotID
    if (m.message.content && m.message.content.robotID.length > 0) return YES;
    return NO;
}

#pragma mark 私有：参与者去重（保留首次出现顺序）

- (NSArray<WKChannelInfo *> *)participantsFromMessages:(NSArray<WKMessageModel *> *)msgs {
    NSMutableArray<WKChannelInfo *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seenUids = [NSMutableSet set];
    for (WKMessageModel *m in msgs) {
        NSString *uid = m.fromUid;
        if (uid.length == 0) continue;
        if ([seenUids containsObject:uid]) continue;
        [seenUids addObject:uid];
        if (m.from) [out addObject:m.from];
    }
    return [out copy];
}

#pragma mark 主入口

- (NSArray<WKBotFoldRenderItem *> *)buildRenderItemsForMessages:(NSArray<WKMessageModel *> *)messages
                                                          config:(WKBotFoldEngineConfig *)config
                                          alreadyShownAsRegular:(nullable NSSet<NSString *> *)alreadyShownAsRegular {
    if (messages.count == 0) return @[];
    if (!config) config = [WKBotFoldEngineConfig defaultConfig];

    // 频道级 short-circuit：非群、无 robot、或 disabled → 全部独立渲染。
    BOOL channelEligible = config.isChannelGroup && config.isChannelRobot;
    if (config.disabled || !channelEligible) {
        NSMutableArray<WKBotFoldRenderItem *> *passthrough = [NSMutableArray arrayWithCapacity:messages.count];
        for (WKMessageModel *m in messages) {
            [passthrough addObject:[WKBotFoldRenderItem itemWithMessage:m]];
        }
        return [passthrough copy];
    }

    NSTimeInterval refNow = config.referenceTimestamp;
    if (refNow <= 0) refNow = [NSDate date].timeIntervalSince1970;

    NSMutableArray<WKBotFoldRenderItem *> *items = [NSMutableArray array];
    NSMutableArray<WKMessageModel *> *pending = [NSMutableArray array];
    NSSet<NSString *> *expandedSet = config.expandedMessageIDs ?: [NSSet set];

    void (^flushPending)(BOOL) = ^(BOOL maybeLastGroup) {
        if (pending.count == 0) return;
        if ((NSInteger)pending.count >= config.minGroupSize) {
            NSArray<WKChannelInfo *> *participants = [self participantsFromMessages:pending];
            BOOL isActive = NO;
            if (maybeLastGroup) {
                WKMessageModel *last = pending.lastObject;
                NSTimeInterval lastTs = last.timestamp;
                if (config.activeWindow > 0 && lastTs > 0 && (refNow - lastTs) < config.activeWindow) {
                    isActive = YES;
                }
            }
            // 是否已展开：本组内任一消息的 clientMsgNo 命中 expandedSet 即视为已展开
            BOOL expanded = NO;
            if (expandedSet.count > 0) {
                for (WKMessageModel *m in pending) {
                    if (m.clientMsgNo.length > 0 && [expandedSet containsObject:m.clientMsgNo]) {
                        expanded = YES;
                        break;
                    }
                }
            }
            WKBotFoldSession *session = [[WKBotFoldSession alloc] initWithMessages:[pending copy]
                                                                       participants:participants
                                                                           isActive:isActive
                                                                           expanded:expanded];
            [items addObject:[WKBotFoldRenderItem itemWithFoldSession:session]];
            // 折叠卡内部已经统一渲染了 title + 摘要 + (展开时)讨论记录，
            // **永远只 emit FoldCard 一项**（无论展开/收起），不再单独输出 Message 行——
            // 这样视觉上始终是同一张卡，不会被 UITableView 拆成多 cell 产生背景割裂。
        } else {
            // 小于成组阈值，全部退化为独立 message。
            for (WKMessageModel *m in pending) {
                [items addObject:[WKBotFoldRenderItem itemWithMessage:m]];
            }
        }
        [pending removeAllObjects];
    };

    for (NSUInteger i = 0; i < messages.count; i++) {
        WKMessageModel *m = messages[i];

        // 1) "停留期间已展示为普通 cell" → 强制独立。
        NSString *cmn = m.clientMsgNo;
        if (cmn.length > 0 && [alreadyShownAsRegular containsObject:cmn]) {
            flushPending(NO);
            [items addObject:[WKBotFoldRenderItem itemWithMessage:m]];
            continue;
        }

        // 2) 五类边界 → flush + 独立。
        if ([[self class] isFoldBoundaryAttachment:m]) {
            flushPending(NO);
            [items addObject:[WKBotFoldRenderItem itemWithMessage:m]];
            continue;
        }

        // 3) 非可折叠（自己发/系统/异常/typing） → flush + 独立。
        if (![[self class] isFoldableBotMessage:m]) {
            flushPending(NO);
            [items addObject:[WKBotFoldRenderItem itemWithMessage:m]];
            continue;
        }

        // 4) 必须是 bot 发的。普通群员（非 bot）的可折叠类型也作为分组边界。
        if (![self isBotSentMessage:m withConfig:config]) {
            flushPending(NO);
            [items addObject:[WKBotFoldRenderItem itemWithMessage:m]];
            continue;
        }

        // 5) gap 检查：与 pending 最后一条间隔 ≥ gapThreshold 即断组（先 flush 当前组，自己起一组）。
        if (pending.count > 0) {
            WKMessageModel *prev = pending.lastObject;
            NSTimeInterval gap = m.timestamp - prev.timestamp;
            if (gap >= config.gapThreshold) {
                flushPending(NO);
            }
        }
        [pending addObject:m];
    }
    flushPending(YES); // 最后一组才可能 active

    return [items copy];
}

@end
