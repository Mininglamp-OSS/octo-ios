//
//  WKUnreadStateDB.h
//  WuKongIMSDK
//
//  Per-channel 已读进度持久化(last_read_seq + last_local_read_at).
//  存在 per-user 的 SDK DB 里(由 WKDB.switchDB 跟随当前 uid 切库),
//  替代之前 NSUserDefaults 方案 —— 解决多账号污染 / kill flush 不可靠 /
//  与 mergeConversations 的 transaction 无原子性 三个问题.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import <FMDB/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKUnreadStateRecord : NSObject
@property (nonatomic, strong) WKChannel *channel;
@property (nonatomic, assign) uint32_t lastReadSeq;
@property (nonatomic, assign) NSTimeInterval lastLocalReadAt;
@end

@interface WKUnreadStateDB : NSObject
+ (instancetype) shared;

/// 取本 channel 的 last_read_seq. 没有返回 0.
-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel;

/// 取本 channel 的 last_local_read_at. 没有返回 0.
-(NSTimeInterval) lastLocalReadAtForChannel:(WKChannel*)channel;

/// 把 last_read_seq / last_local_read_at 一起写进去. last_read_seq 用 max
/// 单调推进(防 race 写小值), last_local_read_at 直接覆盖.
-(void) setLastReadSeq:(uint32_t)seq lastLocalReadAt:(NSTimeInterval)at forChannel:(WKChannel*)channel;

/// 在外层已持有 db(比如 mergeConversations 的 inTransaction)的场景下,
/// 直接走 db 不再开 inDatabase 嵌套.行为同上.
-(void) setLastReadSeq:(uint32_t)seq lastLocalReadAt:(NSTimeInterval)at forChannel:(WKChannel*)channel db:(FMDatabase*)db;

/// 一次拉所有 channel 的 state, 给 mergeConversations 之类的批量 reconcile 用.
/// key 是 "type:channelId"(对齐 WKUnreadStore.channelKeyFor:).
-(NSDictionary<NSString*, WKUnreadStateRecord*>*) allStateMap;

@end

NS_ASSUME_NONNULL_END
