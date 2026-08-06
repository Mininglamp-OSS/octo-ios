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

/// 处理同步会话数据（保存到本地数据库并触发更新回调）
-(void) handleSyncConversation:(WKSyncConversationWrapModel*)model;

/// 同上，但在 DB 写入 + delegate 通知全部完成后回调 completion（主线程）。
///
/// 为什么需要：内部把 DB 密集写派发到了后台队列，调用方无法知道"什么时候可以安全地
/// 从 DB 回读"。上层原先用「设一个 pending 标记，等下一次 onConversationUpdate 再
/// load」来猜，sync 只返回 0/1 条会话或直接失败时那次 load 就永远不会发生
/// （切空间后列表卡在空态的成因）。有了 completion 就不需要猜。
-(void) handleSyncConversation:(WKSyncConversationWrapModel*)model completion:(void(^ _Nullable)(void))completion;

#pragma mark - 空间作用域 / 会话归属

/// 设置会话读路径的空间作用域，详见 WKConversationDB.spaceScopeId。
/// 传 nil / @"" 关闭作用域（回到"DB 里的会话全都算当前空间"的老行为）。
-(void) setSpaceScope:(nullable NSString*)spaceId;

/// 当前空间作用域。
-(nullable NSString*) spaceScope;

/// 记录一批会话归属于某空间。
/// fullSync=YES 表示 channels 是该空间的 **完整** 会话集（version=0 的
/// conversation/sync 响应），会覆盖式写入 —— 不在集合里的旧归属被清掉，
/// 这是退群 / 删会话 / 被移出的自愈路径（顶替原先 deleteAllConversation 的作用）。
/// fullSync=NO 为增量补充，不删任何已有归属。
-(void) applySpaceMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId fullSync:(BOOL)fullSync;

/// 单条归属补充（实时会话更新 / 建群进群白名单）。
/// ⚠️ 只能拿"有正向证据"的判定结果调用，不要写 fail-open 结论 —— 归属是持久的，
/// 一次猜测会把跨空间污染永久固化。
-(void) addSpaceMembership:(WKChannel*)channel forSpace:(NSString*)spaceId;

/// 删除归属。用于"明确判定不属于该空间"的自愈路径（prune / sweep）。
-(void) removeSpaceMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId;

/// 某空间下指定 channelType 的 channelId 集合，供上层水化空间白名单。
-(NSSet<NSString*>*) spaceChannelIdsForSpace:(NSString*)spaceId channelType:(uint8_t)channelType;

/// 归属表是否已有数据（仅诊断用；作用域不再依赖它，见 WKConversationDB.spaceScopeId）。
-(BOOL) hasSpaceMembership;

/// 指定空间是否已有归属数据（= 至少被完整同步过一次）。
-(BOOL) hasSpaceMembershipForSpace:(NSString*)spaceId;

/// 一次性迁移：把 conversation 表现有的行归属到 spaceId。
/// 老版本靠"清库 + 全量 sync"保证 DB 只有当前空间的会话，所以升级那一刻这些行确实
/// 属于该空间。回填后归属表不会再有"整表为空"的状态，作用域可以一直精确过滤。
-(NSInteger) backfillSpaceMembershipFromExistingConversationsForSpace:(NSString*)spaceId;

/// 清空整张归属表（归属索引一次性重建，见 WKConvListCache.prepareMembershipIfNeeded）。
-(void) deleteAllSpaceMembership;

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


/// handleSyncConversation 全量 sync 完成后(DB 已写,delegate 已通知)触发.
/// VC 用这个信号跑 sync 完成后的 side-effects(snapshotSyncedGroupIds /
/// rebuildGroupDisplayAndReload / loadCategories 等),不再依赖 WKConnected
/// 状态(后者会在 DB 后台写完成前触发,引发子区预览拿不到 conv 的 race).
-(void) onConversationSyncFinished;

@end


NS_ASSUME_NONNULL_END
