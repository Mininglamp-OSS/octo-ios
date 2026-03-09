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
 最近会话的内容
 */
@property(nonatomic,copy,readonly) NSString *content;


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
