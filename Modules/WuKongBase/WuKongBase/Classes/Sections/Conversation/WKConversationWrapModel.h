//
//  WKConversationModel.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationWrapModel : NSObject


-(instancetype) initWithConversation:(WKConversation*)conversation;

/**
 频道
 */
@property(nonatomic,strong,readonly) WKChannel *channel;
@property(nonatomic,strong,readonly) WKChannel *parentChannel;

@property(nullable,nonatomic,strong,readonly) WKChannelInfo *channelInfo;



-(void) addOrUpdateChildren:(WKConversationWrapModel *)conversationWrapModel;

/// 子区数量 (通过 children 计算)
@property(nonatomic,assign,readonly) NSInteger childrenCount;

/// 子区数量 (通过解析 channelId 计算，用于会话列表显示)
@property(nonatomic,assign) NSInteger threadCount;

/// 子区预览数据（最多2个，用于会话列表展示）
@property(nonatomic,strong, nullable) NSArray *threadPreviews;

-(void) setChannelInfo:(WKChannelInfo * _Nullable)channelInfo;


/**
 开始发起频道信息请求
 */
-(void) startChannelRequest;

/**
 取消发起的频道信息请求
 */
-(void) cancelChannelRequest;

@property(nonatomic,copy,readonly) NSString *lastClientMsgNo;


/**
 最后一条消息
 */
@property(nonatomic,strong) WKMessage *lastMessage;

-(void) reloadLastMessage;
/**
 最后一条消息的正文类型
 */
@property(nonatomic,assign,readonly) NSInteger lastContentType;

/**
 最新一条消息时间
 */
@property(nonatomic,assign,readonly) NSInteger lastMsgTimestamp;

/**
 最近会话的内容（已按空间过滤）
 */
@property(nonatomic,copy,readonly) NSString *content;

/// 获取当前空间的最后一条消息（用于会话列表的展示判断，如撤回、未知类型等）
-(WKMessage* _Nullable) spaceFilteredLastMessage;


/**
 是否置顶
 */
@property(nonatomic,assign,readonly) BOOL stick;


/**
 是否免打扰
 */
@property(nonatomic,assign,readonly) BOOL mute;


/// 输入中
@property(nonatomic,assign) BOOL typing;


// 输入者
@property(nonatomic,copy) NSString *typer;

/**
 未读消息数量
 */
@property(nonatomic,assign) NSInteger unreadCount;


@property(nonatomic,strong) NSArray<WKReminder*> *simpleReminders;

/// 最近 tab 视角下的「活动未读」= 主群未读 + 最新子区未读。
/// - 与 -lastMsgTimestamp / -content / -spaceFilteredLastMessage 同源：这几个都
///   走 lastChildConversation 反映最新一条消息；unread 只读 self.c.unreadCount
///   会漏掉子区消息带来的未读，用户视角是「预览时间对但红点不亮」（长时间后台后
///   突然收到子区消息尤其明显）。
/// - **仅用于最近 tab 里父群行 cell 的 badge 显示**。关注 tab 里父群 group-summary
///   badge 依然走 unreadCount（只反映主群自身），因为那边子区在 threadToggle /
///   groupThread 上有独立 indicator/胶囊；双算会重复计数。
/// - Tab 底部总未读 / follow section header / recent 汇总里 `count += m.unreadCount`
///   的地方 **不要** 用这个 getter：子区在 threadWrapModels 里已被独立累加，父群
///   再 fold 一次会重复。
@property(nonatomic,assign,readonly) NSInteger recentTabActivityUnreadCount;

/**
 扩展数据
 */
@property(nonatomic,strong,readonly) NSDictionary *extra;

// 服务器的最近会话扩展数据
@property(nonatomic,strong) WKConversationExtra *remoteExtra;

-(void) setConversation:(WKConversation*) conversation;

-(WKConversation*) getConversation;

@end

NS_ASSUME_NONNULL_END
