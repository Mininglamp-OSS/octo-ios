//
//  WKUnreadAckQueueDB.h
//  WuKongIMSDK
//
//  Persistent mark-read upload queue. Call sites enqueue when user
//  reads a conversation locally; WKUnreadAckRunner drains the queue
//  with exponential backoff. This is the durable fix for "server's
//  view of unread permanently lags client" (bug A: 子区 server=1).
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKUnreadAckEntry : NSObject
@property (nonatomic, strong) WKChannel *channel;
@property (nonatomic, assign) uint32_t lastReadSeq;
@property (nonatomic, assign) NSInteger attempts;
@property (nonatomic, assign) NSTimeInterval nextRetryAt;
@property (nonatomic, assign) NSTimeInterval createdAt;
@end

@interface WKUnreadAckQueueDB : NSObject
+ (instancetype) shared;

/// 入队 / 更新. 同 channel 已存在则覆盖 lastReadSeq(单调递增取 max),
/// attempts / next_retry_at 归零,立即可重试.
-(void) enqueue:(WKChannel*)channel lastReadSeq:(uint32_t)seq;

/// 拉所有 next_retry_at <= now 的条目. 返回按 created_at 升序.
-(NSArray<WKUnreadAckEntry*>*) dueEntries;

/// 本 channel 是否还在队列里(无论是否到期).用于 mergeConversations 的本地优先决策.
-(BOOL) hasPending:(WKChannel*)channel;

/// 取本 channel 当前队列条目(没有返回 nil).
-(nullable WKUnreadAckEntry*) entryForChannel:(WKChannel*)channel;

/// 上报成功:删除队列条目. 只有当 stored last_read_seq <= ackedSeq 时才删,
/// 防止 race(老 upload 在飞时新 enqueue 把 seq 推高)删掉新读.
-(void) markDone:(WKChannel*)channel ackedSeq:(uint32_t)ackedSeq;

/// 上报失败:attempts++, next_retry_at 按指数退避计算.
-(void) markFailed:(WKChannel*)channel;

/// 当前有 pending 上报的所有 channel 的 key 集合("type:channelId").
/// mergeConversations 在进 inTransaction 之前调用一次, 避免 reconcile 嵌套
/// inDatabase 触发 FMDB 重入(WKUnreadStore.reconcileServerSnapshot:hasPendingHint:).
-(NSSet<NSString*>*) allPendingChannelKeys;

/// 取下一个未来到期的 next_retry_at(全队列 min). 没有返回 0.
/// Runner drain 完后调度自动重试用.
-(NSTimeInterval) earliestFutureRetryAt;

/// 调试用:列全部条目.
-(NSArray<WKUnreadAckEntry*>*) allEntries;

@end

NS_ASSUME_NONNULL_END
