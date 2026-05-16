//
//  WKChatManager.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
#import "WKMessageContent.h"
#import "WKSendackPacket.h"
#import "WKRecvPacket.h"
#import "WKConversation.h"
#import "WKMessageStatusModel.h"
#import "WKSyncChannelMessageModel.h"
#import "WKSetting.h"
#import "WKMessageExtra.h"
#import "WKChatDataProvider.h"

@protocol WKChatManagerDelegate;

NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^MessageStoreBeforeIntercept)(WKMessage*message);



@interface WKChatManager : NSObject


/**
 发送消息 (发送并保存消息)

 @param content 消息正文
 @param channel 投递到那个频道
 */
-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel;

/**
 发送消息 (发送并保存消息)
 @param content 消息正文
 @param channel 投递到那个频道
 @param topic 话题
 */
-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel topic:(NSString*)topic;

/**
 发送消息 (发送并保存消息)

 @param content 消息正文
 @param channel 投递到那个频道
 @param setting 消息设置
 */
-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel setting:(WKSetting * __nullable)setting;

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel setting:(WKSetting * __nullable)setting topic:(NSString*)topic;

/**
 发送消息（仅仅发送，不保存）

 @param message 消息
 @return <#return value description#>
 */
-(WKMessage*) sendMessage:(WKMessage*)message;

/// 发送消息
/// @param message 消息对象
/// @param addRetryQueue 是否添加到重试队列，如果是true，消息发送失败将会进行指定次数的重试
-(WKMessage*) sendMessage:(WKMessage*)message addRetryQueue:(BOOL)addRetryQueue;


/**
 消息重发
 @param message 重发的消息
 */
-(WKMessage*) resendMessage:(WKMessage*)message;



/**
 保存消息 (都为自己所发消息)

 @param content 消息正文
 @param channel 频道
 */
-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel;


/**
 保存消息（可自定发送者）

 @param content 消息正文
 @param channel 频道
 @param fromUid 发送者uid
 @return <#return value description#>
 */
-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:( NSString* __nullable)fromUid;

-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString* __nullable)fromUid  status:(WKMessageStatus)status;


/// 保存消息
- (NSArray<WKMessage*>*) saveMessages:(NSArray<WKMessage*>*)messages;


// 添加或更新消息（如果存在则更新，不存在添加）
- (void) addOrUpdateMessages:(NSArray<WKMessage*>*)messages;

// 添加或更新消息（如果存在则更新，不存在添加）
// notify 是否通知ui
-(void) addOrUpdateMessages:(NSArray<WKMessage*>*)messages notify:(BOOL)notify;
/**
 转发消息

 @param content 消息正文
 @param channel 频道
 @return <#return value description#>
 */
-(WKMessage*) forwardMessage:(WKMessageContent*)content channel:(WKChannel*)channel;

/**
 编辑消息
 @param message 需要编辑的消息
 @param newContent 编辑后的正文
 */
-(WKMessage*) editMessage:(WKMessage*)message newContent:(WKMessageContent*)newContent;

/**
 删除消息

 @param message 消息对象
 */
-(void) deleteMessage:(WKMessage*)message;

/**
 删除指定频道指定发送者的消息
 */
-(void) deleteMessage:(NSString*)fromUID channel:(WKChannel*)channel;


/**
 清除指定频道的消息

 @param channel 频道
 */
-(void) clearMessages:(WKChannel*)channel;


/// 清除当前用户的所有消息
-(void) clearAllMessages;

/**
 清除指定maxMsgSeq以前的所有消息
 @param channel 频道
 @param maxMsgSeq 指定的messageSeq
 @param isContain 清除的消息是否包含指定的maxMsgSeq
 */
- (void) clearFromMsgSeq:(WKChannel*)channel maxMsgSeq:(uint32_t)maxMsgSeq isContain:(BOOL)isContain;

/**
  查询某个频道最新的消息 （一般是第一次进入会话页面查询首屏消息时调用此方法）
 @param channel 频道
 @param limit 消息数量限制
 @param complete 查询回调
 */
-(void) pullLastMessages:(WKChannel*)channel limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
  查询某个频道最新的消息 （一般是第一次进入会话页面查询首屏消息时调用此方法）
 @param channel 频道
 @param endOrderSeq 结束的orderSeq，如果为0表示不约束
 @param limit 消息数量限制
 @param complete 查询回调
 */
-(void) pullLastMessages:(WKChannel*)channel endOrderSeq:(uint32_t)endOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;


/**
 查询某个频道最新的消息 （一般是第一次进入会话页面查询首屏消息时调用此方法）
@param channel 频道
@param endOrderSeq 结束的orderSeq，如果为0表示不约束
@param maxMessageSeq 频道最大的messageSeq，也就是服务器最大的messageSeq ，非必填，可为0
@param limit 消息数量限制
@param complete 查询回调
 */
-(void) pullLastMessages:(WKChannel*)channel endOrderSeq:(uint32_t)endOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
  下拉加载消息
 @param channel 频道
 @param startOrderSeq 起始的orderSeq 比如需要查询 100以上的10条消息 那么startOrderSeq就是100 查询出来的数据为 90 91 92 93 94 95 96 97 98 99
 @param limit 消息数量限制
 @param complete 查询回调
 */
-(void) pullDown:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
 上拉加载消息
 @param startOrderSeq 起始的orderSeq 比如需要查询 100以下的10条消息 那么startOrderSeq就是100 查询出来的数据为 101 102 103 104 105 106 107 108 109 110
 @param limit 消息数量限制
 @param complete 查询回调
 */
-(void) pullUp:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

-(void) pullUp:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
 查询指定orderSeq周围的消息 上5条下5条 ，比如 orderSeq 为 20 则查询 16 17 18 19 20 21 22 23 24 25 主要使用在定位消息
 @param channel 频道
 @param orderSeq 以此OrderSeq查询周围的消息
 */
-(void) pullAround:(WKChannel*)channel orderSeq:(uint32_t)orderSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
 查询指定orderSeq周围的消息 上5条下5条 ，比如 orderSeq 为 20 则查询 16 17 18 19 20 21 22 23 24 25 主要使用在定位消息
 @param channel 频道
 @param orderSeq 以此OrderSeq查询周围的消息
 @param maxMessageSeq 目前服务器最大的messageSeq（目的第一屏数据不请求接口）
 */
-(void) pullAround:(WKChannel*)channel orderSeq:(uint32_t)orderSeq maxMessageSeq:(uint32_t)maxMessageSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
  拉取历史消息
 @param channel 频道
 @param startOrderSeq 基准messageSeq 以此messageSeq为基准进行上下浮动查询
 @param endOrderSeq 结束的messageSeq 查询到此messageSeq为终止 如果为 0 则不做限制 limit限制查询数量
 @param limit 消息数量限制
 @param pullMode 拉取方式
 @param complete 查询回调
 */
-(void) pullMessages:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq limit:(int)limit pullMode:(WKPullMode)pullMode  complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete;

/**
 查询消息
 @param channel 频道
 @param aroundOrderSeq 以此OrderSeq查询周围的消息
 */
-(void) getMessages:(WKChannel*)channel aroundOrderSeq:(uint32_t)aroundOrderSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete DEPRECATED_MSG_ATTRIBUTE("use pullAround");;


/**
 更新语音消息已读状态
 
 @param message 消息
 */
-(void) updateMessageVoiceReaded:(WKMessage*)message;

/**
 更新本地扩展数据

 @param message 消息对象
 */
-(void) updateMessageLocalExtra:(WKMessage*)message;

/**
  更新消息远程扩展
 */
-(void) updateMessageRemoteExtra:(WKMessage*)message;


/// 撤回消息
/// @param message <#message description#>
-(void) revokeMessage:(WKMessage*)message;



/// 获取orderSeq
/// @param messageSeq <#messageSeq description#>
-(uint32_t) getOrderSeq:(uint32_t)messageSeq;

-(uint32_t) getMessageSeq:(uint32_t) orderSeq;

/**
 获取最接近orderSeq的有效orderSeq
 */
-(uint32_t) getOrNearbyMessageSeq:(uint32_t)orderSeq;


/// 正文包装为消息
/// @param content 消息正文
/// @param channel 频道
/// @param fromUid 发送者UID
-(WKMessage*) contentToMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString * __nullable)fromUid;



/// 通过正文类型获取content
/// @param contentType 正文类型
-(WKMessageContent*) getMessageContent:(NSInteger)contentType;

/**
 添加委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKChatManagerDelegate>) delegate;


/**
 移除委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKChatManagerDelegate>) delegate;



/// 添加消息存储之拦截器
/// @param sid 拦截器唯一ID
/// @param intercept 拦截器 返回true表示消息存储 返回false表示消息不存储
-(void) addMessageStoreBeforeIntercept:(NSString*)sid intercept:(MessageStoreBeforeIntercept)intercept;


/// 移除消息存储之前的拦截器
/// @param sid 拦截器唯一ID
-(void) removeMessageStoreBeforeIntercept:(NSString*)sid;





///  调用拦截器获得消息是否需要存储
/// @param message <#message description#>
-(BOOL) needStoreOfIntercept:(WKMessage*)message;

/**
 同步消息的扩展数据
 */
-(void) syncMessageExtra:(WKChannel*)channel complete:(void(^_Nullable)(NSError * _Nullable error))complete;

/**
  标记消息为已读
 */
//-(void) markReaded:(WKChannel*)channel messages:(NSArray<WKMessage*>*)messages;


// 获取某个频道内最新的消息
-(WKMessage*) getLastMessage:(WKChannel*)channel;

// 通知UI消息更新
- (void)callMessageUpdateDelegate:(WKMessage*)message;

// 通知UI收到消息
- (void)callRecvMessagesDelegate:(NSArray<WKMessage*>*)messages;

/// 同步频道消息提供者（由第三方设置）
@property(nonatomic,copy) WKSyncChannelMessageProvider syncChannelMessageProvider;

@property(nonatomic,copy) WKSyncMessageExtraProvider syncMessageExtraProvider; // 同步消息扩展
@property(nonatomic,copy) WKUpdateMessageExtraProvider updateMessageExtraProvider; // 更新消息扩展

// 消息编辑提供者
@property(nonatomic,copy) WKMessageEditProvider messageEditProvider;

// 调用消息更新委托
- (void)callMessageUpdateDelegate:(WKMessage*)message left:(NSInteger)left total:(NSInteger)total;

@end

/**
 聊天管理委托
 */
@protocol WKChatManagerDelegate <NSObject>

@optional

/**
 收到消息回调
 
 @param message 收到的消息
 @param left 消息剩余数量 ，可当left为0时再刷新UI
 */
- (void)onRecvMessages:(WKMessage*)message left:(NSInteger)left;

/**
 消息更新
 
 @param message <#message description#>
 @param left 消息剩余数量 ，可当left为0时再刷新UI
 */
-(void) onMessageUpdate:(WKMessage*) message left:(NSInteger)left;

/**
 消息更新
 
 @param message <#message description#>
 @param left 消息剩余数量 ，可当left为0时再刷新UI
 @param total 消息总数量
 */
-(void) onMessageUpdate:(WKMessage*) message left:(NSInteger)left total:(NSInteger)total;

/**
  发送消息回执回调
 */
-(void) onSendack:(WKSendackPacket*) sendackPacket left:(NSInteger)left;


/**
 消息被删除

 @param message 被删除的消息
 */
-(void) onMessageDeleted:(WKMessage*) message;


/**
 指定频道的消息已清除

 @param channel <#channel description#>
 */
-(void) onMessageCleared:(WKChannel*)channel;


/// 清除所有消息
-(void) onMessageAllCleared;

// 流消息
-(void) onMessageStream:(WKStream*)stream;



@end



NS_ASSUME_NONNULL_END
