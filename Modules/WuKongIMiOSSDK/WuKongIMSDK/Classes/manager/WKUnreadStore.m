//
//  WKUnreadStore.m
//  WuKongIMSDK
//

#import "WKUnreadStore.h"
#import "WKUnreadAckQueueDB.h"
#import "WKUnreadAckRunner.h"
#import "WKConversationDB.h"
#import "WKConversation.h"
#import "WKConversationManager.h"
#import "WKSDK.h"

static NSString *const kLastReadSeqMapKey = @"WKUnreadStore.lastReadSeqByChannel";
static NSString *const kLastLocalReadAtMapKey = @"WKUnreadStore.lastLocalReadAtByChannel";
// 本地 mark-read 后多少秒内,server snapshot 不能把 unread 拉回.
static NSTimeInterval const kLocalReadProtectionWindow = 60.0;

@interface WKUnreadStore ()
// 内存缓存,避免每次 reconcile 都读 NSUserDefaults.
@property (nonatomic, strong) NSMutableDictionary<NSString*,NSNumber*> *lastReadSeqCache;
@property (nonatomic, strong) NSMutableDictionary<NSString*,NSNumber*> *lastLocalReadAtCache;
@property (nonatomic, strong) NSLock *cacheLock;
@end

@implementation WKUnreadStore

+ (instancetype) shared {
    static WKUnreadStore *_inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _inst = [[self alloc] init];
    });
    return _inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheLock = [[NSLock alloc] init];
        NSDictionary *seqMap = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kLastReadSeqMapKey];
        NSDictionary *atMap  = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kLastLocalReadAtMapKey];
        _lastReadSeqCache = seqMap ? [seqMap mutableCopy] : [NSMutableDictionary dictionary];
        _lastLocalReadAtCache = atMap ? [atMap mutableCopy] : [NSMutableDictionary dictionary];
    }
    return self;
}

-(NSString*) keyFor:(WKChannel*)channel {
    return [[self class] channelKeyFor:channel];
}

+(NSString*) channelKeyFor:(WKChannel*)channel {
    if (!channel) return @"";
    return [NSString stringWithFormat:@"%d:%@", channel.channelType, channel.channelId ?: @""];
}

-(void) persistCaches {
    [[NSUserDefaults standardUserDefaults] setObject:[self.lastReadSeqCache copy] forKey:kLastReadSeqMapKey];
    [[NSUserDefaults standardUserDefaults] setObject:[self.lastLocalReadAtCache copy] forKey:kLastLocalReadAtMapKey];
    // 强制 flush. iOS 默认会延迟批量写,如果用户 mark-read 后立刻 kill app(iOS
    // 没机会做 graceful suspend),lastReadSeq 会丢, 下次启动 reconcile 走不进
    // branch 1, 退到 MAX(local, server) → 红点复活 regression.
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return 0;
    [self.cacheLock lock];
    NSNumber *v = self.lastReadSeqCache[[self keyFor:channel]];
    [self.cacheLock unlock];
    return v ? (uint32_t)[v unsignedLongLongValue] : 0;
}

-(NSTimeInterval) lastLocalReadAtForChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return 0;
    [self.cacheLock lock];
    NSNumber *v = self.lastLocalReadAtCache[[self keyFor:channel]];
    [self.cacheLock unlock];
    return v ? [v doubleValue] : 0;
}

-(void) markLocalRead:(WKChannel*)channel readSeq:(uint32_t)readSeq {
    if (!channel || channel.channelId.length == 0) return;
    // 调用方传 0 通常意味着 lastMessage 还没 ready(异步加载 race / subroom
    // 冷启动). 不能用 0 上报: server 端 PUT coversation/clearUnread 收到
    // message_seq=0 不会真清, 而 cache 里如果没有真值会落 lastReadSeq=0,
    // reconcile branch 1 永远走不进, 重启后红点复活.
    // 兜底从 DB local conversation row 拿 lastMessageSeq —— 那是 SDK 已知的
    // 该频道最新 seq, 用它作为"已读到这里"的进度可接受(用户都点"全部已读"了).
    if (readSeq == 0) {
        WKConversation *local = [[WKSDK shared].conversationManager getConversation:channel];
        if (local && local.lastMessageSeq > 0) {
            readSeq = local.lastMessageSeq;
            NSLog(@"[UnreadStore] markLocalRead channelId=%@ readSeq=0 → fallback to local.lastMessageSeq=%u",
                  channel.channelId, readSeq);
        } else {
            NSLog(@"[UnreadStore] markLocalRead channelId=%@ readSeq=0 AND no local fallback, SKIP (would corrupt cache)",
                  channel.channelId);
            return;
        }
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSString *key = [self keyFor:channel];

    [self.cacheLock lock];
    uint32_t prev = self.lastReadSeqCache[key] ? (uint32_t)[self.lastReadSeqCache[key] unsignedLongLongValue] : 0;
    uint32_t merged = MAX(prev, readSeq);
    self.lastReadSeqCache[key] = @(merged);
    self.lastLocalReadAtCache[key] = @(now);
    [self persistCaches];
    [self.cacheLock unlock];

    NSLog(@"[UnreadStore] markLocalRead channelId=%@ type=%d readSeq=%u (prev=%u)",
          channel.channelId, channel.channelType, merged, prev);

    // 清本地 DB unread + 通知 UI(走 SDK 既有路径,会触发 onConversationUnreadCountUpdate).
    [[WKSDK shared].conversationManager clearConversationUnreadCount:channel];

    // 入队上报给 server. WKUnreadAckRunner 负责实际 PUT + 重试.
    [[WKUnreadAckQueueDB shared] enqueue:channel lastReadSeq:merged];
    [[WKUnreadAckRunner shared] kick];
}

-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread {
    return [self reconcileServerSnapshot:channel
                            serverUnread:serverUnread
                           serverLastSeq:serverLastSeq
                             localUnread:localUnread
                     pendingChannelKeys:nil];
}

-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread
                  pendingChannelKeys:(NSSet<NSString*>*)pendingChannelKeys {
    if (!channel || channel.channelId.length == 0) {
        return MAX(localUnread, serverUnread);
    }
    uint32_t lastReadSeq = [self lastReadSeqForChannel:channel];
    NSTimeInterval lastReadAt = [self lastLocalReadAtForChannel:channel];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL hasPendingAck;
    if (pendingChannelKeys) {
        // 调用方已 prefetch 过(避免 inTransaction 嵌套 inDatabase 触发 FMDB 重入).
        hasPendingAck = [pendingChannelKeys containsObject:[[self class] channelKeyFor:channel]];
    } else {
        hasPendingAck = [[WKUnreadAckQueueDB shared] hasPending:channel];
    }
    BOOL inProtectionWindow = (lastReadAt > 0 && (now - lastReadAt) < kLocalReadProtectionWindow);

    // 1. 用户已经读过 server 那条最新 seq: 直接 0, server 的 unread 数是 stale.
    if (lastReadSeq > 0 && serverLastSeq > 0 && lastReadSeq >= serverLastSeq) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> 0 (read past, lastReadSeq=%u >= serverLastSeq=%u)",
              channel.channelId, lastReadSeq, serverLastSeq);
        return 0;
    }
    // 2. 还有 pending ack: server 还不知道我们读了,用本地视图,不被 server 拉高.
    if (hasPendingAck) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (pending ack, keep local; server=%ld)",
              channel.channelId, (long)localUnread, (long)serverUnread);
        return localUnread;
    }
    // 3. 近期本地 mark-read 保护窗口: 网络抖动导致 ack 还没成功 / cmd 还没下发,
    //    保持本地 0 不让 server 重新点亮红点.
    if (inProtectionWindow) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (within %.0fs read window; server=%ld)",
              channel.channelId, (long)localUnread, kLocalReadProtectionWindow, (long)serverUnread);
        return localUnread;
    }
    // 4. 默认: max, 防 sync 把刚 +1 的本地值拉低.
    NSInteger result = MAX(localUnread, serverUnread);
    if (result != localUnread || result != serverUnread) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (max of local=%ld server=%ld)",
              channel.channelId, (long)result, (long)localUnread, (long)serverUnread);
    }
    return result;
}

@end
