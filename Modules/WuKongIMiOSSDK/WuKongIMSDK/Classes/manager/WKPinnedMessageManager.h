//
//  WKPinnedMessageManager.h
//  WuKongIMSDK
//
//  Created by tt on 2024/5/22.
//

#import <Foundation/Foundation.h>
#import "WKPinnedMessage.h"
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKPinnedMessageManagerDelegate <NSObject>

@optional

// 置顶消息改变
-(void) pinnedMessageChange:(WKChannel*)channel;

@end

@interface WKPinnedMessageManager : NSObject


/**
 添加委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKPinnedMessageManagerDelegate>) delegate;
/**
 移除委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKPinnedMessageManagerDelegate>) delegate;

+ (WKPinnedMessageManager *)shared;

// 通过频道获取置顶的消息集合
-(NSArray<WKMessage*>*) getPinnedMessagesByChannel:(WKChannel*)channel;

// 获取某个频道的最大version
-(uint64_t) getMaxVersion:(WKChannel*)channel;

// 删除某个频道的所有置顶
-(void) deletePinnedByChannel:(WKChannel*)channel;

// 删除某条消息的置顶
-(void) deletePinnedByMessageId:(uint64_t)messageId;

// 添加或更新置顶消息
-(void) addOrUpdatePinnedMessages:(NSArray<WKPinnedMessage*>*)messages;

// 是否置顶
-(BOOL) hasPinned:(uint64_t)messageId;

@end

NS_ASSUME_NONNULL_END
