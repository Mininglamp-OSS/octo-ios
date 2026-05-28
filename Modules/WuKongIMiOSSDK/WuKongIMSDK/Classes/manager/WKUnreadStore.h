//
//  WKUnreadStore.h
//  WuKongIMSDK
//
//  Single funnel for unread state. Local-priority conflict policy:
//    - markLocalRead: persist last_read_seq + last_local_read_at to
//      WKUnreadStateDB (per-user SDK DB), clear local conversation
//      unread, enqueue ack to server.
//    - reconcileServerSnapshot: returns the unread that should land
//      in DB after a sync, respecting local intent.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

@class WKUnreadReconcileContext;

@interface WKUnreadStore : NSObject
+ (instancetype) shared;

/// 用户在本设备读了某 channel 到 readSeq.
/// - 写 WKUnreadStateDB(last_read_seq + last_local_read_at), 与
///   conversation.unread_count=0 在同一 transaction, 保证原子.
/// - 入队 WKUnreadAckQueueDB, kick WKUnreadAckRunner 上报 server.
/// 这是所有"用户读了"的唯一入口.
-(void) markLocalRead:(WKChannel*)channel readSeq:(uint32_t)readSeq;

/// 给定 server sync 返回的快照 + 本地 DB 现状, 返回应该写到 DB 的 unread.
/// 决策(本地优先):
///   1. server.lastSeq <= local.lastReadSeq → 0 (用户已读过 server 那条最新 seq)
///   2. AckQueue 还有 pending → keep local (server 还不知道我们读过)
///   3. 60s 内有过 LocalRead → keep local (近期意图保护)
///   4. 默认 → MAX(local, server) (不丢服务端 +1)
-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread;

/// 批量场景(mergeConversations 250+ 行 sync): 调用方先 prefetch 一次 context,
/// 把所有 pending ack key + 所有 unread_state 一起预读, 然后逐行 reconcile
/// 时走 hint 变种, 不再每行都开 DB query, 也避开 inTransaction 嵌套.
-(WKUnreadReconcileContext*) prefetchReconcileContext;

-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread
                              context:(nullable WKUnreadReconcileContext*)context;

/// 取 last_read_seq, 没有返回 0.
-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel;

/// 给 reconcile 用的 channel key 格式("type:channelId").
+(NSString*) channelKeyFor:(WKChannel*)channel;

@end


/// Reconcile 批量预读上下文. WKUnreadStore.prefetchReconcileContext 一次
/// 把以下两块数据快照拉出来:
///   - pendingAckChannelKeys: WKUnreadAckQueueDB 里所有 pending 的 key 集合
///   - unreadStateMap: WKUnreadStateDB 里所有 channel 的(lastReadSeq + lastLocalReadAt)
/// 在 mergeConversations 进 inTransaction 之前 prefetch, 避免 reconcile 内部
/// 再开 [dbQueue inDatabase:] 触发 FMDB 重入.
@interface WKUnreadReconcileContext : NSObject
@property (nonatomic, strong, readonly) NSSet<NSString*> *pendingAckChannelKeys;
@property (nonatomic, strong, readonly) NSDictionary *unreadStateMap;  // NSString -> WKUnreadStateRecord
@end

NS_ASSUME_NONNULL_END
