//
//  WKConversationManagerInner.h
//  Pods
//
//  Created by tt on 2022/5/27.
//

#ifndef WKConversationManagerInner_h
#define WKConversationManagerInner_h


#endif /* WKConversationManagerInner_h */


@interface WKConversationManager ()

/**
 添加或更新最近会话

 @param conversation conversation
 @param incUnreadCount 未读数递增数量
 */
-(WKConversationAddOrUpdateResult*) addOrUpdateConversation:(WKConversation*)conversation incUnreadCount:(NSInteger)incUnreadCount;

-(WKConversationAddOrUpdateResult*) addOrUpdateConversation:(WKConversation*)cs;

/// 处理同步下来的最近会话
/// @param model 会话同步对象
-(void) handleSyncConversation:(WKSyncConversationWrapModel*)model;





/**
  调用最近会话更新委托

 @param conversations 会话数组
 */
- (void)callOnConversationUpdateDelegates:(NSArray<WKConversation*>*)conversations;


/// 调用删除所有最近会话委托
- (void)callOnConversationAllDeleteDelegate;




@end
