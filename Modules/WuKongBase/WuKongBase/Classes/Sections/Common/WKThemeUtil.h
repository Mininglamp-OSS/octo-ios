//
//  WKThemeUtil.h
//  WuKongBase
//
//  Created by tt on 2022/9/9.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKAppConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKThemeUtil : NSObject

// 获取某个频道的背景数据
+(NSData*) getChatBackground:(WKChannel*)channel style:(WKSystemStyle)style;

// 是否存在聊天背景图
+(BOOL) existChatBackground:(WKChannel*)channel;

/**
 保存某个频道的背景图
 */
+(BOOL) saveChatBackground:(WKChannel*)channel data:(NSData*)data style:(WKSystemStyle)style;

// 保存默认背景图
+(BOOL) saveDefaultBackground:(NSData*)data style:(WKSystemStyle)style;

// 是否存在默认的聊天背景
+(BOOL) existDefaultbackground;

// 获取全局的默认背景图数据
+(NSData*) getDefaultBackground:(WKSystemStyle)style;

@end

NS_ASSUME_NONNULL_END
