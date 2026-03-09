//
//  WKMessageManager.h
//  WuKongBase
//
//  Created by tt on 2020/1/28.
//

#import <Foundation/Foundation.h>
#import "WKMessageModel.h"
NS_ASSUME_NONNULL_BEGIN
@class WKMessageManager;
@protocol WKMessageManagerDelegate <NSObject>


@optional


/**
 删除消息

 @param manager <#manager description#>
 @param messages 消息对象
 */
-(void) messageManager:(WKMessageManager*)manager deleteMessages:(NSArray<WKMessageModel*>*)messages;


/**
 清除指定频道的消息

 @param manager <#manager description#>
 @param channel 频道
 */
-(void) messageManager:(WKMessageManager*)manager clearMessages:(WKChannel*)channel;


/**
 撤回消息

 @param manager <#manager description#>
 @param message 需要撤回的消息对象
 */
-(void) messageManager:(WKMessageManager*)manager revokeMessage:(WKMessageModel*)message complete:(void(^__nullable)(NSError * __nullable error))complete;


/// 设置最近会话的未读数
/// @param manager <#manager description#>
/// @param channel 频道
/// @param messageSeq 最新消息的messageSeq (只有超大群需要)
/// @param complete <#complete description#>
-(void) messageManager:(WKMessageManager*) manager conversationSetUnread:(WKChannel*)channel unread:(NSInteger)unread messageSeq:(uint32_t)messageSeq complete:(void(^__nullable)(NSError * __nullable error))complete;


///  更新语音消息为已读
/// @param manager <#manager description#>
/// @param message 语音消息
/// @param complete <#complete description#>
-(void) messageManager:(WKMessageManager*) manager updateMessageVoiceReaded:(WKMessageModel*)message complete:(void(^__nullable)(NSError * __nullable error))complete;

//收藏单个表情
-(void) messageManager:(WKMessageManager*) manager collectExpressions:(WKMessageModel*)message;


@end


@interface WKMessageManager : NSObject

+ (WKMessageManager *)shared;

@property(nonatomic, strong) id<WKMessageManagerDelegate> delegate;


/**
 删除指定消息

 @param messages <#message description#>
 */
-(void) deleteMessages:(NSArray<WKMessageModel*>*)messages;


/**
 清除指定频道的消息

 @param channel <#channel description#>
 */
-(void) clearMessages:(WKChannel*)channel;


/// 设置最近会话的未读数
/// @param channel <#channel description#>
-(void) conversationSetUnread:(WKChannel*)channel unread:(NSInteger)unread  messageSeq:(uint32_t)messageSeq complete:(void(^__nullable)(NSError *__nullable error))complete;


/**
 撤回消息

 @param message <#message description#>
 */
-(void) revokeMessage:(WKMessageModel*)message complete:(void(^__nullable)(NSError *__nullable error))complete;


/// 更新语音消息为已读
/// @param message 语音消息
/// @param complete <#complete description#>
-(void) updateMessageVoiceReaded:(WKMessageModel*)message complete:(void(^__nullable)(NSError *__nullable error))complete;

/**
 收藏单个表情
 */
-(void) collectExpressions:(WKMessageModel*)message;

@end

NS_ASSUME_NONNULL_END
