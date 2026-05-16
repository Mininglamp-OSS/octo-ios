// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
