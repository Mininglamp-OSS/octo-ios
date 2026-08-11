//
//  WKDB.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>
#import "WKFMDatabaseQueue.h"
//消息表
#define TB_MESSAGE @"message"

#define TB_STREAM @"stream"

NS_ASSUME_NONNULL_BEGIN

// 数据库健康检查失败通知（主线程发出）
// userInfo: @{ @"imDBPath": NSString, @"uid": NSString }
extern NSString * const WKIMDBHealthCheckFailedNotification;

// 切库完成通知（switchDB: 末尾发出，与调用线程相同）
// 用途：持有 DB 派生内存缓存的类（如 WKConversationSpaceDB.hasAnyMembership）
// 必须在切账号时失效缓存，否则会拿 A 账号的结论去判 B 账号的库。
extern NSString * const WKDBDidSwitchNotification;

@interface WKDB : NSObject

@property (nonatomic, strong) WKFMDatabaseQueue *dbQueue;

/// 当前 dbQueue 指向哪个账号的库（switchDB: 设置）。只读暴露给需要做"账号闸门"的写入方：
/// 所有落库 block 都是在**执行时**才解析 dbQueue，而 switchDB: 会把它换成新账号的库 ——
/// 在入队前捕获这个值、执行时比一次，就能丢弃跨账号的过期写入
/// （见 WKConversationManager.handleSyncConversation:completion:）。
/// 它比上层登录态更适合当判据：这就是"这批写入会落到哪个库"的直接答案，与被保护对象同源。
@property (nonatomic, copy, readonly, nullable) NSString *currentUid;

+ (WKDB *)sharedDB;

/**
 切换用户的数据库

 @param uid 用户uid
 */
-(void) switchDB:(NSString*)uid;

/**
 是否需要切换数据库

 @param uid <#uid description#>
 @return <#return value description#>
 */
-(BOOL) needSwitchDB:(NSString*)uid;

@end

NS_ASSUME_NONNULL_END
