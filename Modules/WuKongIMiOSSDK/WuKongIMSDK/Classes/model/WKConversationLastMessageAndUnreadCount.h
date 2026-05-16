//
//  WKConversationLastMessageAndUnreadCount.h
//  WuKongIMSDK
//
//  Created by tt on 2022/5/27.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

// 会话最后一条消息和需要累加的未读数量
@interface WKConversationLastMessageAndUnreadCount : NSObject
// 最后一条消息
@property(nonatomic,strong) WKMessage *lastMessage;
// 需要累加的未读数量
@property(nonatomic,assign) NSInteger incUnreadCount;

// 提醒项
//@property(nonatomic,strong) WKReminderManager *reminderManager;

@end

NS_ASSUME_NONNULL_END
