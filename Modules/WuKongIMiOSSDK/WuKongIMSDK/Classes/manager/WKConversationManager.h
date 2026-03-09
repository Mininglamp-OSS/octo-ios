//
//  WKConversationManager.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
#import "WKConversation.h"
#import "WKConversationDB.h"
#import "WKSyncConversationModel.h"
#import "WKConversationExtra.h"

@protocol WKConversationManagerDelegate;

NS_ASSUME_NONNULL_BEGIN

typedef void(^WKSyncConversationCallback)(WKSyncConversationWrapModel* __nullable model,NSError * __nullable error);

typedef void(^WKSyncConversationAck)(uint64_t cmdVersion,void(^ _Nullable complete)(NSError * _Nullable error));

// 同步会话返回 timestamp：最新会话的时间戳 lastMsgSeqs：客户端所有会话的最后一条消息序列号 格式： channelID:channelType:last_msg_seq|channelID:channelType:last_msg_seq
typedef void (^WKSyncConversationProvider)(long long version,NSString *lastMsgSeqs,WKSyncConversationCallback callback);


// 同步最近会话扩展
typedef void(^WKSyncConversationExtraCallback)(NSArray<WKConversationExtra*>* __nullable extras,NSError * __nullable error);
typedef void (^WKSyncConversationExtraProvider)(long long version,WKSyncConversationExtraCallback callback);
// 更新扩展
typedef void (^WKUpdateConversationExtraCallback)(int64_t version,NSError * __nullable error);
typedef void (^WKUpdateConversationExtraProvider)(WKConversationExtra *extra,WKUpdateConversationExtraCallback callback);



@interface WKConversationManager : NSObject

/**
 获取最近会话列表
 
 @return 最好会话对象集合
 */
-(NSArray<WKConversation*>*) getConversationList;


/// 添加最近会话信息
/// @param conversation <#conversation description#>
-(void) addConversation:(WKConversation*)conversation;

/**
 清除指定频道的未读消息
 
 @param channel <#channel description#>
 */
-(void) clearConversationUnreadCount:(WKChannel*)channel;


/// 设置未读数
/// @param channel 频道
/// @param unread 未读数量
-(void) setConversationUnreadCount:(WKChannel*)channel unread:(NSInteger)unread;



/// 恢复指定频道的会话
/// @param channel <#channel description#>
-(void) recoveryConversation:(WKChannel*)channel;



// 更新或添加扩展
-(void) updateOrAddExtra:(WKConversationExtra*)extra;

// 同步最近会话扩展
-(void) syncExtra;


/// 删除最近会话
/// @param channel 频道
-(void) deleteConversation:(WKChannel*)channel;



/// 获取指定频道的最近会话信息
/// @param channel <#channel description#>
-(WKConversation*) getConversation:(WKChannel*)channel;

-(NSArray<WKConversation*>*) getConversations:(NSArray<WKChannel*>*)channels;

/**
 添加最近会话委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKConversationManagerDelegate>) delegate;


/**
 移除最近会话委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKConversationManagerDelegate>) delegate;

/**
 获取所有会话未读数量
 */
-(NSInteger) getAllConversationUnreadCount;

/**
 调用最近会话更新委托

 @param conversation <#conversation description#>
 */
- (void)callOnConversationUpdateDelegate:(WKConversation*)conversation;

/// 设置同步会话提供者
/// @param syncConversationProvider <#syncConversationProvider description#>
/// @param syncConversationAck <#syncConversationAck description#>
-(void) setSyncConversationProviderAndAck:(WKSyncConversationProvider) syncConversationProvider ack:(WKSyncConversationAck)syncConversationAck;



/// 同步最近会话
@property(nonatomic,copy,readonly) WKSyncConversationProvider syncConversationProvider;
@property(nonatomic,copy,readonly) WKSyncConversationAck syncConversationAck;

// 同步扩展提供者
@property(nonatomic,copy) WKSyncConversationExtraProvider syncConversationExtraProvider;
// 更新扩展提供者
@property(nonatomic,copy) WKUpdateConversationExtraProvider updateConversationExtraProvider;



@end


@protocol WKConversationManagerDelegate <NSObject>

@optional

/**
 最近会话更新
 */
- (void)onConversationUpdate:(NSArray<WKConversation*>*)conversations;

/**
 最近会话未读数更新
 
 @param channel 频道
 @param unreadCount 未读数量
 */
- (void)onConversationUnreadCountUpdate:(WKChannel*)channel unreadCount:(NSInteger)unreadCount;


/// 最近会话被删除
/// @param channel <#channel description#>
-(void) onConversationDelete:(WKChannel*)channel;


/// 所有最近会话删除
-(void) onConversationAllDelete;

@end


NS_ASSUME_NONNULL_END
