//
//  WKMessageListDataProvider.h
//  Pods
//
//  Created by tt on 2022/5/18.
//

#ifndef WKMessageListDataProvider_h
#define WKMessageListDataProvider_h


#endif /* WKMessageListDataProvider_h */

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageModel.h"
#import "WKConversationContext.h"
#import "WKConversationPosition.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WKMessageListDataProvider <NSObject>

// 请求第一屏消息
// @param position 定位消息的位置，为空则表示定位最新的消息
-(void) pullFirst:(WKConversationPosition * __nullable)position complete:(void(^)(bool more))complete;


// 日期数量
-(NSInteger) dateCount;

// 获取某个section的日期
-(NSString*) dateWithSection:(NSInteger)section;

- (NSArray<NSString *> *)dates; // 当前列表的所有日期

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date; // 获取日期对应的消息

-(NSInteger) messageCount; // 消息数量

// 通过indexPath获取消息model
-(WKMessageModel*__nullable) messageAtIndexPath:(NSIndexPath*)indexPath;

// 通过section获取消息集合
-(NSArray<WKMessageModel*>*) messagesAtSection:(NSInteger)section;

// 最近会话上下文
-(id<WKConversationContext>) conversationContext;



@optional


// 通过clientMsgNo获取消息
-(WKMessageModel* __nullable) messageAtClientMsgNo:(NSString*)clientMsgNo;

// 通过流式编号获取消息
-(WKMessageModel*__nullable) messageAtStreamNo:(NSString*)streamNo;



// 通过orderSeq获取消息的indexpath
-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq;

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo;
-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID;

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo;

// 获取包含有回复messageID的消息的消息
-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID;
-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID;

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath;

-(NSIndexPath*) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove;

// 添加消息
-(void) addMessage:(WKMessageModel*)message;
-(NSIndexPath*) removeMessage:(WKMessageModel*) message;



// 消息已读
-(void) didReaded:(NSArray<WKMessageModel*>*)messages;


// 上拉
-(void) pullup:(void(^)(bool more))complete;
// 下拉加载
-(void) pulldown:(void(^)(bool more))complete;

-(WKMessageModel*) lastMessage;

-(WKMessageModel*) firstMessage;



/**
 清除消息
 */
-(void) clearMessages;

-(NSArray<WKMessageModel*>*) getSelectedMessages; // 获取被选中的消息

-(void) cancelSelectedMessages; // 取消被选中的消息

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType;


-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo;

// -------------------- typing --------------------

- (BOOL)hasTyping;
-(NSIndexPath*) replaceTyping:(WKMessageModel*)message;
-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel; // 根据需要添加typing消息
@end

NS_ASSUME_NONNULL_END
