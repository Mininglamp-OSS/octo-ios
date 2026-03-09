//
//  WKLocalNotificationManager.h
//  WuKongBase
//
//  Created by tt on 2020/7/21.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKLocalNotificationManager : NSObject

+ (WKLocalNotificationManager *)shared;


/// 显示本地通知
/// @param message <#message description#>
-(void) showLocalNotification:(WKMessage*)message;

// 显示本地通知在允许的情况下
-(void) showLocalNotificationIfNeed:(WKMessage*)message;

@end



NS_ASSUME_NONNULL_END
