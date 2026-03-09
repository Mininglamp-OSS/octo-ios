//
//  WKSDK.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/23.
//

#import "WuKongIMSDKHeader.h"

NS_ASSUME_NONNULL_BEGIN



// 悟空IM SDK
@interface WKSDK : NSObject

+ (WKSDK *)shared;

@property(nonatomic,strong) WKOptions* options;

/**
 连接信息串
 */
@property(nonatomic,copy) NSString *connectURL;

/**
 连接管理者
 */
@property(nonatomic,strong) WKConnectionManager *connectionManager;


/**
 聊天管理者
 */
@property(nonatomic,strong) WKChatManager *chatManager;


/**
 频道管理者
 */
@property(nonatomic,strong) WKChannelManager *channelManager;

/**
 频道信息提供者
 */
@property(nonatomic,strong) WKChannelInfoUpdate channelInfoUpdate;


/**
 媒体文件管理者
 */
@property(nonatomic,strong) WKMediaManager *mediaManager;


/**
 编码者
 */
@property(nonatomic,strong) WKCoder *coder;


/**
 包body的编码解码者管理
 */
@property(nonatomic,strong) WKPakcetBodyCoderManager *bodyCoderManager;


/**
 最近会话管理
 */
@property(nonatomic,strong) WKConversationManager *conversationManager;


/// cmd管理者
@property(nonatomic,strong) WKCMDManager *cmdManager;

// 消息已读回执管理者
@property(nonatomic,strong) WKReceiptManager *receiptManager;


// 消息回应管理
//  负责点赞数据的维护
@property(nonatomic,strong) WKReactionManager *reactionManager;

// 机器人管理者
@property(nonatomic,strong) WKRobotManager *robotManager;

// 置顶消息管理者
@property(nonatomic,strong) WKPinnedMessageManager *pinnedMessageManager;

// 提醒管理者
// 负责最近会话的提醒项，比如 有人@我，入群申请等等 还可以自定义一些提醒，比如类似微信的 [红包] [转账] 列表都会有提醒
@property(nonatomic,strong) WKReminderManager *reminderManager;

@property(nonatomic,strong) WKFlameManager *flameManager; // 阅后即焚管理者

// sdk版本号，每次升级记得修改此处
@property(nonatomic,copy,readonly) NSString *sdkVersion;



/**
 是否是debug模式

 @return <#return value description#>
 */
-(BOOL) isDebug;



/// 注册消息正文
/// @param cls 正文的class （需要继承WKMessageContent）
-(void) registerMessageContent:(Class)cls;


/// 注册消息正文（指定正文类型）
/// @param cls 正文的class （需要继承WKMessageContent）
/// @param contentType 正文类型
-(void) registerMessageContent:(Class)cls contentType:(NSInteger)contentType;


/**
 获取正文类型对应的正文对象

 @param contentType <#contentType description#>
 @return <#return value description#>
 */
-(Class) getMessageContent:(NSInteger)contentType;


/**
 是否是系统消息 （目前规定的系统消息的contentType类型为 [1000,2000]之间）

 @param contentType 正文类型
 @return <#return value description#>
 */
-(BOOL) isSystemMessage:(NSInteger)contentType;


// 离线消息拉取（普通模式）
@property(nonatomic,copy,readonly) WKOfflineMessagePull offlineMessagePull;
@property(nonatomic,copy,readonly) WKOfflineMessageAck offlineMessageAck;

// 离线会话拉取（万人群模式）
//@property(nonatomic,copy,readonly) WKOfflineMessagePull offlineMessagePull;

/**
 离线消息提供者

 @param offlineMessageCallback 消息回调
 @param offlineMessageAckCallback ack回调
 */
-(void) setOfflineMessageProvider:(WKOfflineMessagePull) offlineMessageCallback offlineMessagesAck:(WKOfflineMessageAck) offlineMessageAckCallback;


/**
 获取消息文件上传任务

 @param message <#message description#>
 @return <#return value description#>
 */
-(WKMessageFileUploadTask*) getMessageFileUploadTask:(WKMessage*)message;


/// 获取消息下载任务
/// @param message <#message description#>
-(WKMessageFileDownloadTask*) getMessageDownloadTask:(WKMessage*)message;

@end

NS_ASSUME_NONNULL_END
