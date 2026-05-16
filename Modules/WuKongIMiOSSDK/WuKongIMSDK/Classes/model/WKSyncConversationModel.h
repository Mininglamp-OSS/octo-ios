//
//  WKOfflineConversation.h
//  WuKongIMSDK
//
//  Created by tt on 2020/9/30.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKMessage.h"
#import "WKConversation.h"

#import "WKCMDDB.h"
NS_ASSUME_NONNULL_BEGIN



@interface WKSyncConversationModel : NSObject

@property(nonatomic,strong) WKChannel *channel; // 频道

@property(nonatomic,strong) WKChannel *parentChannel; // 频道

@property(nonatomic,assign) NSInteger unread; // 消息未读数

@property(nonatomic,assign) BOOL mute;

@property(nonatomic,assign) BOOL stick;

@property(nonatomic,assign) NSTimeInterval timestamp; // 最后一次会话时间

@property(nonatomic,assign) uint32_t lastMsgSeq; // 最后一次会话的消息序列号

@property(nonatomic,copy) NSString *lastMsgClientNo; // 最后一次会话的消息客户端编号

@property(nonatomic,assign) long long version; // 数据版本

@property(nonatomic,strong) NSArray<WKMessage*> *recents; // 会话的最新消息集合

@property(nonatomic,strong) WKConversationExtra *remoteExtra;

@property(nonatomic,strong,readonly) WKConversation *conversation;

@end

@interface WKCMDModel : NSObject

@property(nonatomic,copy) NSString *no; // cmd唯一编号
@property(nonatomic,copy) NSString *cmd;
// 消息时间（服务器时间,单位秒）
@property(nonatomic,assign) NSInteger timestamp;

// cmd 参数
@property(nonatomic,strong) NSDictionary *param;

+(WKCMDModel*) message:(WKMessage*)message;

+(WKCMDModel*) cmdMessage:(WKCMDMessage*)cmdMessage;

@end

@interface WKSyncConversationWrapModel : NSObject

@property(nonatomic,strong) NSArray<WKSyncConversationModel*> *conversations;

@end



NS_ASSUME_NONNULL_END
