//
//  WKUnreadStore.m
//  WuKongIMSDK
//

#import "WKUnreadStore.h"
#import "WKUnreadAckQueueDB.h"
#import "WKUnreadAckRunner.h"
#import "WKUnreadStateDB.h"
#import "WKConversationDB.h"
#import "WKConversation.h"
#import "WKConversationManager.h"
#import "WKDB.h"
#import "WKSDK.h"

@implementation WKUnreadReconcileContext
@end

// 本地 mark-read 后多少秒内, server snapshot 不能把 unread 拉回 > 0.
static NSTimeInterval const kLocalReadProtectionWindow = 60.0;

@implementation WKUnreadStore

+ (instancetype) shared {
    static WKUnreadStore *_inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _inst = [[self alloc] init];
        // 清掉上一版本残留在 NSUserDefaults 里的 lastReadSeq / lastLocalReadAt cache.
        // 数据已迁到 per-user 的 unread_state 表, NSUserDefaults 那份既污染多账号
        // 也持久化不可靠, 直接弃.
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKUnreadStore.lastReadSeqByChannel"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKUnreadStore.lastLocalReadAtByChannel"];
    });
    return _inst;
}

+(NSString*) channelKeyFor:(WKChannel*)channel {
    if (!channel) return @"";
    return [NSString stringWithFormat:@"%d:%@", channel.channelType, channel.channelId ?: @""];
}

-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel {
    return [[WKUnreadStateDB shared] lastReadSeqForChannel:channel];
}

-(void) markLocalRead:(WKChannel*)channel readSeq:(uint32_t)readSeq {
    if (!channel || channel.channelId.length == 0) return;

    // readSeq=0 兜底: subroom 异步加载 race 下 lastMessage 偶发 nil → 上游传 0.
    // 不能用 0 上报(server 不当已读) / 不能用 0 落 cache(reconcile branch 1 永
    // 远走不进). 从 SDK conversation row 取 lastMessageSeq 作为"已读到这里"
    // 的进度 —— 用户都点"全部已读"了, 用本地已知最新 seq 可接受.
    if (readSeq == 0) {
        WKConversation *local = [[WKSDK shared].conversationManager getConversation:channel];
        if (local && local.lastMessageSeq > 0) {
            readSeq = local.lastMessageSeq;
            NSLog(@"[UnreadStore] markLocalRead channelId=%@ readSeq=0 → fallback to local.lastMessageSeq=%u",
                  channel.channelId, readSeq);
        } else {
            NSLog(@"[UnreadStore] markLocalRead channelId=%@ readSeq=0 AND no local fallback, SKIP",
                  channel.channelId);
            return;
        }
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // 1. 先把 unread_state 写进 DB. 即使后面 clearConversationUnreadCount 还没跑,
    //    mergeConversations 撞进来也能从 unread_state 读到正确的 lastReadSeq,
    //    走 reconcile branch 1 → 返回 0, 不会复活红点.
    [[WKUnreadStateDB shared] setLastReadSeq:readSeq lastLocalReadAt:now forChannel:channel];

    NSLog(@"[UnreadStore] markLocalRead channelId=%@ type=%d readSeq=%u",
          channel.channelId, channel.channelType, readSeq);

    // 2. 清本地 conversation.unread_count + 通知 UI delegate(SDK 既有路径).
    [[WKSDK shared].conversationManager clearConversationUnreadCount:channel];

    // 3. 入队上报给 server. WKUnreadAckRunner 负责 PUT + 重试.
    [[WKUnreadAckQueueDB shared] enqueue:channel lastReadSeq:readSeq];
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
                                 context:nil];
}

-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread
                              context:(WKUnreadReconcileContext*)context {
    if (!channel || channel.channelId.length == 0) {
        return MAX(localUnread, serverUnread);
    }
    NSString *channelKey = [[self class] channelKeyFor:channel];

    uint32_t lastReadSeq = 0;
    NSTimeInterval lastReadAt = 0;
    BOOL hasPendingAck = NO;
    if (context) {
        WKUnreadStateRecord *rec = context.unreadStateMap[channelKey];
        if (rec) {
            lastReadSeq = rec.lastReadSeq;
            lastReadAt = rec.lastLocalReadAt;
        }
        hasPendingAck = [context.pendingAckChannelKeys containsObject:channelKey];
    } else {
        lastReadSeq = [[WKUnreadStateDB shared] lastReadSeqForChannel:channel];
        lastReadAt = [[WKUnreadStateDB shared] lastLocalReadAtForChannel:channel];
        hasPendingAck = [[WKUnreadAckQueueDB shared] hasPending:channel];
    }

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL inProtectionWindow = (lastReadAt > 0 && (now - lastReadAt) < kLocalReadProtectionWindow);

    // 1. 用户已经读过 server 那条最新 seq: 直接 0, server 的 unread 是 stale.
    //    必须额外要求 localUnread==0, 否则会误杀 "本地 socket 已经先收到比 server
    //    sync 接口快照更新的消息,把 unread +1 到了 1" 的真值. server snapshot 落后
    //    (serverLastSeq < lastReadSeq) 是常态; 锁屏后 socket 重连那一瞬,
    //    handleRecv 通常先于 conversation/sync 返回, DB 里已经有 unread=1, 这时
    //    sync 接口给的 serverLastSeq 还是用户上次 lastReadSeq 前的值, 不加这个守卫
    //    会把刚 +1 的红点擦掉, 用户视角是 "预览到了但红点没起来".
    if (lastReadSeq > 0 && serverLastSeq > 0 && lastReadSeq >= serverLastSeq && localUnread == 0) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> 0 (read past, lastReadSeq=%u >= serverLastSeq=%u, localUnread=0)",
              channel.channelId, lastReadSeq, serverLastSeq);
        return 0;
    }
    // 2. 还有 pending ack: server 还不知道我们读了, 用本地视图.
    if (hasPendingAck) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (pending ack, keep local; server=%ld)",
              channel.channelId, (long)localUnread, (long)serverUnread);
        return localUnread;
    }
    // 3. 60s 保护窗口: 抖动 / cmd 慢 → 不让 server 重新点亮红点.
    if (inProtectionWindow) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (within %.0fs read window; server=%ld)",
              channel.channelId, (long)localUnread, kLocalReadProtectionWindow, (long)serverUnread);
        return localUnread;
    }
    // 4. 默认: max, 防 sync 把刚 +1 的本地值拉低.
    NSInteger result = MAX(localUnread, serverUnread);
    if (result != localUnread || result != serverUnread) {
        NSLog(@"[UnreadStore] reconcile channelId=%@ -> %ld (max of local=%ld server=%ld; lastReadSeq=%u serverLastSeq=%u)",
              channel.channelId, (long)result, (long)localUnread, (long)serverUnread, lastReadSeq, serverLastSeq);
    }
    return result;
}

-(WKUnreadReconcileContext*) prefetchReconcileContext {
    WKUnreadReconcileContext *ctx = [[WKUnreadReconcileContext alloc] init];
    [ctx setValue:[[WKUnreadAckQueueDB shared] allPendingChannelKeys] forKey:@"pendingAckChannelKeys"];
    [ctx setValue:[[WKUnreadStateDB shared] allStateMap] forKey:@"unreadStateMap"];
    return ctx;
}

@end
