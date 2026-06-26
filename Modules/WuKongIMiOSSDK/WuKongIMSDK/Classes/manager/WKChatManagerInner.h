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


/// 批量检测被 @ 的消息, 给会话补 [有人@我] reminder。
/// live recv (saveMessages → addOrUpdateConversationWithMessages) 路径已经在
/// makeConversationLastMessageAndUnreadCount 里内联做了; conversation/sync 接口
/// 把 recents 直接走 [WKMessageDB replaceMessages:] 写库, 绕过 chat manager 那条
/// 路径, 离线期间(杀进程)收到的 @ 消息 reminder 不会被本地补偿。在 sync 完成后
/// 显式调一刀, 修复杀进程后离线 @ 不显示。
///
/// 与内联路径用同一套判定 (isMentionedMe + showUnread/子区 bypass + 不补自己发的)。
/// 命中后调 [WKReminderManager updateConversations:] 让会话列表角标立刻刷新。
-(void) compensateMentionRemindersFromMessages:(NSArray<WKMessage*>*)messages;



@end
