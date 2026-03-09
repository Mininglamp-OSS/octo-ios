//
//  WKReactionManager.h
//  WuKongIMSDK
//
//  Created by tt on 2021/9/13.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKReaction.h"
@class WKReactionManager;
NS_ASSUME_NONNULL_BEGIN


typedef void(^WKSyncReactionsCallback)(NSArray<WKReaction*> * __nullable reactions,NSError  * __nullable error);
typedef void(^WKAddOrCancelReactionsCallback)(NSError  * __nullable error);

@protocol WKReactionManagerDelegate <NSObject>

@optional

// reaction改变
-(void) reactionManagerChange:(WKReactionManager*)reactionManager reactions:(NSArray<WKReaction*>*)reactions channel:(WKChannel*)channel;

@end

@interface WKReactionManager : NSObject

+ (WKReactionManager *)shared;

/**
 添加或取消回应,如果同一个用户存在reactionName的回应则取消回应
 @param reactionName 回应的名称，一般是emoji或本地emoji图片的名称
 @param messageID 回应消息的ID
 @param complete 结果回掉
 */

-(void) addOrCancelReaction:(NSString*)reactionName messageID:(uint64_t)messageID complete:(void(^_Nullable)(NSError  * _Nullable error))complete;

/**
 添加连接委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKReactionManagerDelegate>) delegate;


/**
 移除连接委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKReactionManagerDelegate>) delegate;


-(void) sync:(WKChannel*)channel;

// 同步点赞数据提供者
@property(nonatomic,copy) void(^syncReactionsProvider)(WKChannel *channel,uint64_t maxVersion,WKSyncReactionsCallback callback);

// 添加或取消点赞数据提供者
@property(nonatomic,copy) void(^addOrCancelReactionProvider)(WKChannel*channel,uint64_t messageID, NSString *reactionName,WKAddOrCancelReactionsCallback callback);


@end

NS_ASSUME_NONNULL_END
