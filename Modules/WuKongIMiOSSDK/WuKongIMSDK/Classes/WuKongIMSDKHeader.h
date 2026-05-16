//
//  WuKongIMSDKHeader.h
//  Pods
//
//  Created by tt on 2022/12/13.
//


#import <Foundation/Foundation.h>
#import "WKOptions.h"
#import "WKConnectionManager.h"
#import "WKCoder.h"
#import "WKPakcetBodyCoderManager.h"
#import "WKChatManager.h"
#import "WKPinnedMessageManager.h"
#import "WKMessageContent.h"
#import "WKConversationManager.h"
#import "WKChannelManager.h"
#import "WKMediaManager.h"
#import "WKMessageFileUploadTask.h"
#import "WKMessageFileDownloadTask.h"
#import "WKTaskManager.h"
#import "WKCMDManager.h"
#import "WKReceiptManager.h"
#import "WKTaskOperator.h"
#import "WKReactionManager.h"
#import "WKRobotManager.h"
#import "WKReminderManager.h"
#import "WKFlameManager.h"
#import "WKConst.h"


NS_ASSUME_NONNULL_BEGIN

/**
 频道资料回调

 @param error 错误
 */
typedef void (^WKChannelInfoCallback)(NSError * _Nullable error,bool notifyBefore);


/**
 离线消息回调

 @param messages 获取的离线消息
 @param more 是否还有更多消息
 @param error 错误信息
 */
typedef void(^WKOfflineMessageCallback)(NSArray<WKMessage*>* __nullable messages,bool more,NSError * __nullable error);

/**
 离线消息ack回调
 @param messageSeq 最后收到的消息序列号
 */

typedef void(^WKOfflineMessageAck)(uint32_t messageSeq,void(^complete)(NSError *error));


/**
 用户信息提供者 （第三方需要设置）

 */
typedef WKTaskOperator* _Nullable (^WKChannelInfoUpdate)(WKChannel *channel,WKChannelInfoCallback callback);


/**
 离线消息拉取

 @param limit <#limit description#>
 @param messageSeq <#messageSeq description#>
 @param callback <#callback description#>
 */
typedef void (^WKOfflineMessagePull)(int limit,uint32_t messageSeq,WKOfflineMessageCallback callback);

NS_ASSUME_NONNULL_END
