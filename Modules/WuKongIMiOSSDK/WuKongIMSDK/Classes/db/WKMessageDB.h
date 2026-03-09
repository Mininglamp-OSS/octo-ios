//
//  WKMessageDB.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
#import "WKSendackPacket.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageDB : NSObject

+ (WKMessageDB *)shared;
/**
 保存消息

 @param messages 消息集合
 @return 返回去重了的消息集合
 */
-(NSArray<WKMessage*>*) saveMessages:(NSArray<WKMessage*>*)messages;


/// 保存或更新消息
/// @param messages <#messages description#>
-(NSArray<WKMessage*>*) replaceMessages:(NSArray<WKMessage*>*)messages;


/**
 获取频道中，从指定消息之前、指定数量的最新消息实体

 @param channel 频道
 @param oldestOrderSeq 截止的客户端排序号
 @param limit 消息数量限制
 @return 消息实体集合
 
 例如：  oldestOrderSeq为20，count为2，会返回oldestOrderSeq为19和18的WKMessage对象列表。
 */
//-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel oldestOrderSeq:(uint32_t)oldestOrderSeq limit:(int) limit;
//

/// 获取频道中，从指定消息之前、指定数量的最新消息实体
/// @param channel 查询指定频道
/// @param startOrderSeq 开始orderSeq
/// @param endOrderSeq 结束排序seq
/// @param limit 限制
/// @param pullMode 拉取模式
-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq  limit:(int) limit pullMode:(WKPullMode)pullMode;


/// 获取消息列表
/// @param channel 频道对象
/// @param keyword 关键字
-(NSArray<WKMessage*>*) getMessages:(WKChannel*)channel keyword:(NSString*)keyword limit:(int) limit;

/// 获取消息
/// @param messageSeq 偏移的messageSeq
/// @param limit 数据限制
-(NSArray<WKMessage*>*) getMessages:(uint32_t)messageSeq limit:(int)limit;


-(NSArray<WKMessage*>*) getDeletedMessagesWithChannel:(WKChannel*)channel minMessageSeq:(uint32_t)minMessageSeq maxMessageSeq:(uint32_t)maxMessageSeq;


/// 获取消息序号区间内已经被删除的消息的messageSeq
/// @param channel 频道
/// @param minMessageSeq 最小消息序号
/// @param maxMessageSeq 最大消息序号
-(NSArray<NSNumber*>*) getDeletedMessageSeqWithChannel:(WKChannel*)channel  minMessageSeq:(uint32_t)minMessageSeq maxMessageSeq:(uint32_t)maxMessageSeq;

/// 获取比messageSeq小并且已删除了的序号
/// @param channel 频道
/// @param messageSeq  消息序号
/// @param limit 最大数量
-(NSArray<NSNumber*>*) getDeletedLessThanMessageSeqWithChannel:(WKChannel*)channel  messageSeq:(uint32_t)messageSeq limit:(int)limit;

/// 获取比messageSeq大并且已删除了的序号
/// @param channel 频道
/// @param messageSeq  消息序号
/// @param limit 最大数量
-(NSArray<NSNumber*>*) getDeletedMoreThanMessageSeqWithChannel:(WKChannel*)channel  messageSeq:(uint32_t)messageSeq limit:(int)limit;

/**
 通过序列号获取消息
 
 @param clientSeqs <#clientSeqs description#>
 @return <#return value description#>
 */
-(NSArray<WKMessage*>*) getMessagesWithClientSeqs:(NSArray<NSNumber*>*)clientSeqs;


/// 通过客户端消息编号获取消息列表
/// @param clientMsgNos <#clientMsgNos description#>
-(NSArray<WKMessage*>*) getMessagesWithClientMsgNos:(NSArray*)clientMsgNos;

/**
 通过消息id集合获取消息
 */
-(NSArray<WKMessage*>*) getMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs;

/**
 通过客户端消息编号获取消息

 @param clientMsgNo 客户端消息编号
 @return <#return value description#>
 */
-(WKMessage*) getMessageWithClientMsgNo:(NSString*)clientMsgNo;
/**
 获取指定clientSeq的消息

 @param clientSeq 客户端序号
 @return <#return value description#>
 */
-(WKMessage*) getMessage:(uint32_t)clientSeq;


/// 通过消息序号查询消息
/// @param channel <#channel description#>
/// @param messageSeq <#messageSeq description#>
-(WKMessage*) getMessage:(WKChannel*)channel messageSeq:(uint32_t)messageSeq;



/// 通过排序号获取频道内指定消息
/// @param orderSeq <#orderSeq description#>
/// @param channel <#channel description#>
-(WKMessage*) getMessage:(WKChannel*)channel orderSeq:(uint32_t)orderSeq;


/// 获取小于指定orderSeq 有messageSeq的第一条消息
/// @param channel <#channel description#>
/// @param orderSeq <#orderSeq description#>
-(WKMessage*) getMessage:(WKChannel*)channel lessThanAndFirstMessageSeq:(uint32_t)orderSeq;

// 获取大于指定orderSeq 有messageSeq的第一条消息
-(WKMessage*) getMessage:(WKChannel*)channel moreThanAndFirstMessageSeq:(uint32_t)orderSeq;
/**
 通过消息ID获取消息

 @param messageId <#messageId description#>
 @return <#return value description#>
 */
-(WKMessage*) getMessageWithMessageId:(uint64_t)messageId;

/**
 更新消息通过发送回执消息
 
 @param sendackPackets <#sendackPackets description#>
 */
-(void) updateMessageWithSendackPackets:(NSArray<WKSendackPacket*> *)sendackPackets;


/**
 更新消息

 @param content 消息content内容
 @param status 消息状态
 @param extra 消息扩展数据
 @param clientSeq 消息客户端唯一编号
 */
-(void) updateMessageContent:(NSData*)content status:(WKMessageStatus)status extra:(NSDictionary*)extra clientSeq:(uint32_t)clientSeq;


/**
 更新语音消息已读状态

 @param voiceReaded 语音是否已读
 @param clientSeq 客户端唯一ID
 */
-(void) updateMessageVoiceReaded:(BOOL)voiceReaded clientSeq:(uint32_t)clientSeq;





/**
 更新消息扩展字段

 @param extra <#extra description#>
 @param clientSeq <#clientSeq description#>
 */
-(void) updateMessageExtra:(NSDictionary*) extra clientSeq:(uint32_t)clientSeq;
/**
 将上传中的消息状态更改为发送失败的状态
 */
-(void) updateMessageUploadingToFailStatus;


/// 获取所有等待发送的消息
-(NSArray<WKMessage*>*) getMessagesWaitSend;
/**
 更新消息状态

 @param status 消息状态
 @param clientSeq 消息clientSeq
 */
-(void) updateMessageStatus:(WKMessageStatus)status withClientSeq:(uint32_t)clientSeq;


/// 更新消息撤回状态
/// @param revoke <#revoke description#>
/// @param clientMsgNo <#clientMsgNo description#>
-(void) updateMessageRevoke:(BOOL)revoke clientMsgNo:(NSString*)clientMsgNo;

/**
 获取某个频道消息表中最大的message_seq

 @return <#return value description#>
 */
-(uint32_t) getMaxMessageSeq:(WKChannel*)channel;


/**
 删除消息
 
 @param message 消息对象
 */
-(void) deleteMessage:(WKMessage*)message;

-(void) deleteMessagesWithClientSeqs:(NSArray<NSNumber*>*)ids;

-(void) deleteMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs;

-(void) deleteMessagesWithMessageIDs:(NSArray<NSNumber*>*)messageIDs db:(FMDatabase*)db;

/**
  彻底将消息从数据库删除 （deleteMessage只是标记为删除）
 */
- (void)destoryMessage:(WKMessage *)message;

/**
  获取指定频道内指定发送者的消息集合
 */
-(NSArray<WKMessage*>*) getMessages:(NSString*)fromUID channel:(WKChannel*)channel;


/**
 清除指定频道的消息
 
 @param channel 频道
 */
-(void) clearMessages:(WKChannel*)channel;


/// 清除所有消息
-(void) clearAllMessages;

/// 清除指定maxMsgSeq以前的所有消息
///  @param channel 频道
///  @param maxMsgSeq 指定的messageSeq
///  @param isContain 清除的消息是否包含指定的maxMsgSeq
- (void) clearFromMsgSeq:(WKChannel*)channel maxMsgSeq:(uint32_t)maxMsgSeq isContain:(BOOL)isContain;
/**
 获取最后一条消息

 @param channel <#channel description#>
 @return <#return value description#>
 */
-(WKMessage*) getLastMessage:(WKChannel*)channel;


/// 获取指定偏移量的最新消息
/// @param channel <#channel description#>
/// @param offset <#offset description#>
-(WKMessage*) getLastMessage:(WKChannel*)channel offset:(NSInteger)offset;


/// 查询排序在指定message之前的消息数量
/// @param message <#message description#>
-(NSInteger) getOrderCountMoreThanMessage:(WKMessage*)message;

/**
  获取指定频道的最大扩展版本
 */
-(long long) getMessageExtraMaxVersion:(WKChannel*)channel;

/**
  获取需要焚烧的消息（阅后即焚）
 */
-(NSArray<WKMessage*>*) getMessagesOfNeedFlame;

/**
  获取消息最大ID
 */
-(long long) getMessageMaxID;

/// 更新消息为已查看
-(NSArray<WKMessage*>*) updateViewed:(NSArray<WKMessage*>*)messages;

/**
 获取指定messageSeq的周围第一条消息的messageSeq 0表示没有
 */
-(uint32_t) getChannelAroundFirstMessageSeq:(WKChannel*)channel messageSeq:(uint32_t)messageSeq;

-(WKMessageContent*) decodeContent:(NSInteger)contentType data:(NSData *)contentData db:(FMDatabase*)db;

// 保存流
-(void) saveOrUpdateStreams:(NSArray<WKStream*>*)streams;

// 获取流
-(NSArray<WKStream*>*) getStreams:(NSString*)streamNo;

// 获取过期消息
-(NSArray<WKMessage*>*) getExpireMessages:(NSInteger)limit;

@end

NS_ASSUME_NONNULL_END
