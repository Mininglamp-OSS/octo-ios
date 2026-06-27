//
//  WKChatManagerInner.h
//  Pods
//
//  Created by tt on 2022/5/27.
//

#ifndef WKChatManagerInner_h
#define WKChatManagerInner_h


#endif /* WKChatManagerInner_h */


@interface WKChatManager ()


/**
 处理发送消息回执

 @param sendackArray <#sendackArray description#>
 */
-(void) handleSendack:(NSArray<WKSendackPacket*> *)sendackArray;


/**
 处理收到消息

 @param packets <#packets description#>
 */
-(void) handleRecv:(NSArray<WKRecvPacket*>*) packets;


/**
 处理消息 （流程： 保存消息-> 触发收到消息委托 -> 保存或更新最近会话 -> 触发最近会话委托）

 @param messages <#messages description#>
 */
-(void) handleMessages:(NSArray<WKMessage*>*) messages;


// 调用消息状态改变委托
//- (void)callMessageStatusChangeDelegate:(NSArray<WKMessageStatusModel*>*)statusModels;




/// 调用收到消息的委托
/// @param messages <#messages description#>
- (void)callRecvMessagesDelegate:(NSArray<WKMessage*>*)messages;

// 调用流式消息委托
- (void)callStreamDelegate:(NSArray<WKStream*>*)streams;

/// 获取所有消息存储之前的拦截器
-(NSArray<MessageStoreBeforeIntercept>*) getMessageStoreBeforeIntercepts;



@end
