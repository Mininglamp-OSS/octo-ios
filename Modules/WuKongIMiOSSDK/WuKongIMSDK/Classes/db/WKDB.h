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
