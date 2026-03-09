//
//  WKMessageList.h
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import <Foundation/Foundation.h>
#import "WKMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageList : NSObject

@property(nonatomic,strong) NSMutableArray<NSString*> *dates; // 消息日期

// 插入消息
-(void) insertMessages:(NSArray<WKMessageModel*>*)messages;

// 添加消息
-(void) addMessages:(NSArray<WKMessageModel*>*)messages;

-(void) addMessage:(WKMessageModel*)message;

// 清空消息
-(void) clearMessages;

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date;

// 设置消息
-(void) setMessages:(NSArray<WKMessageModel*>*)messages forDate:(NSString*)date;

-(WKMessageModel*) lastMessage;

-(WKMessageModel*) firstMessage;

-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq;

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo;

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo;

-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID;

// 获取包含有回复messageID的消息的消息
-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID;
-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID;

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath;

-(NSIndexPath*) removeMessage:(WKMessageModel*) message;

// sectionRemove 表示 section是否整个都移除了
-(NSIndexPath*) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove;


-(NSInteger) messageCount;

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
