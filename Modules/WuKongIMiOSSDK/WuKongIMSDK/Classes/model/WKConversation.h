//
//  WKConversation.h
//  WuKongIMSDK
//
//  Created by tt on 2019/12/8.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKChannelInfo.h"
#import "WKMessage.h"
#import "WKReminderManager.h"
#import "WKConversationExtra.h"
NS_ASSUME_NONNULL_BEGIN



@interface WKConversation : NSObject<NSCopying>

@property(nonatomic,strong) WKChannel *channel; // 频道

@property(nonatomic,strong,nullable) WKChannel *parentChannel; // 父类频道
/**
 *  频道资料，可能为空，如果为空可以调用WKChannelManager fetchChannelInfo:completion 触发频道信息变更委托
 */
@property(nullable,nonatomic,strong,readonly) WKChannelInfo *channelInfo;
/**
 头像
 */
@property(nonatomic,copy) NSString *avatar;
/**
 最新一条消息的客户端seq
 */
//@property(nonatomic,assign) uint32_t lastClientSeq;
/// 最后一条消息的客户端编号
@property(nonatomic,copy) NSString *lastClientMsgNo;

// 最后一条消息的额messageSeq
@property(nonatomic,assign) uint32_t lastMessageSeq;

/**
 最后一条消息 （如果内存没有则去数据库查询）
 */
@property(nonatomic,strong) WKMessage *lastMessage;

/**
 最后一条消息（如果没有不进行数据库加载）
 */
@property(nonatomic,strong) WKMessage *lastMessageInner;

/**
 最新一条消息时间 （10位时间戳到秒）
 */
@property(nonatomic,assign) NSInteger lastMsgTimestamp;


//@property(nonatomic,assign) uint32_t browseTo;
/**
 未读消息数量
 */
@property(nonatomic,assign) NSInteger unreadCount;


/**
 提醒项
 */
@property(nonatomic,strong) NSArray<WKReminder*> *reminders;
@property(nonatomic,strong,readonly) NSArray<WKReminder*> *simpleReminders; // 除去重复的type了的reminder

/**
 扩展数据
 */
@property(nonatomic,strong) NSDictionary *extra;
/// 数据版本
@property(nonatomic,assign) long long version;
// 是否已删除
@property(nonatomic,assign) NSInteger isDeleted;
// 免打扰
@property(nonatomic,assign) BOOL mute;
// 置顶
@property(nonatomic,assign) BOOL stick;

/// 重新加载最后一条消息（重新从数据库里获取）
-(void) reloadLastMessage;
// 服务端扩展数据
@property(nonatomic,strong) WKConversationExtra *remoteExtra;

@end

NS_ASSUME_NONNULL_END
