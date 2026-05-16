// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLocalNotificationManager.h
//  WuKongBase
//
//  Created by tt on 2020/7/21.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKLocalNotificationManager : NSObject <UNUserNotificationCenterDelegate>

+ (WKLocalNotificationManager *)shared;

/// 注册为通知中心代理（在 App 启动时调用）
-(void) registerAsNotificationDelegate;


/// 显示本地通知
/// @param message <#message description#>
-(void) showLocalNotification:(WKMessage*)message;

// 显示本地通知在允许的情况下
-(void) showLocalNotificationIfNeed:(WKMessage*)message;

/// 判断消息是否属于当前空间（用于空间隔离过滤）
-(BOOL) isMessageInCurrentSpace:(WKMessage*)message;

@end



NS_ASSUME_NONNULL_END
