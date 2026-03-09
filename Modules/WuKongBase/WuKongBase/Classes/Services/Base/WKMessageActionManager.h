//
//  WKMessageActionManager.h
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageActionManager : NSObject

+ (WKMessageActionManager *)shared;

/**
 转发消息
 */
-(void) forwardMessages:(NSArray<WKMessage*>*)messages;

/**
 转发消息
 */
-(void) forwardContent:(WKMessageContent*)messageContent complete:(void(^__nullable)(void))complete;

/**
 发送消息给朋友
 */
-(void) sendContentToFriend:(WKMessageContent*)messageContent complete:(void(^__nullable)(void))complete;
@end

NS_ASSUME_NONNULL_END
