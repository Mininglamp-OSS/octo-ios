//
//  WKUnreadStore.h
//  WuKongIMSDK
//
//  Single funnel for unread state. Implements the "local-priority"
//  conflict policy from phase 2 design:
//    - markLocalRead: persist last_read_seq + last_local_read_at,
//      enqueue ack to server, clear DB unread to 0.
//    - reconcileServerSnapshot: returns the unread that should land
//      in DB after a sync, respecting local intent.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKUnreadStore : NSObject
+ (instancetype) shared;

/// 用户在本设备读了某 channel 到 readSeq.
/// - 持久化 last_read_seq / last_local_read_at(NSUserDefaults).
/// - 清本地 DB unread 为 0.
/// - 入队 ack 给 server, WKUnreadAckRunner 负责重试上报.
/// 这是所有"用户读了"的唯一入口.
-(void) markLocalRead:(WKChannel*)channel readSeq:(uint32_t)readSeq;

/// 给定 server sync 返回的快照 + 本地 DB 现状, 返回应该写到 DB 的 unread.
/// 决策:
///   1. server.lastSeq <= local.lastReadSeq (用户已经读过了): 返回 0
///   2. AckQueue 还有 pending 上报 (server 还不知道我们读过): 保持本地视图(localUnread)
///   3. 60s 内有过 LocalRead (近期意图保护): 保持本地视图
///   4. 默认: MAX(localUnread, serverUnread) (不丢服务端 +1)
-(NSInteger) reconcileServerSnapshot:(WKChannel*)channel
                         serverUnread:(NSInteger)serverUnread
                        serverLastSeq:(uint32_t)serverLastSeq
                          localUnread:(NSInteger)localUnread;

/// 取 last_read_seq, 没有返回 0.
-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel;

@end

NS_ASSUME_NONNULL_END
