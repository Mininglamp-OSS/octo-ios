//
//  WKPinnedMessageDB.h
//  WuKongIMSDK
//
//  Created by tt on 2024/5/22.
//

#import <Foundation/Foundation.h>
#import "WKPinnedMessage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKPinnedMessageDB : NSObject

+ (WKPinnedMessageDB *)shared;


// 通过频道获取置顶的消息集合
-(NSArray<WKPinnedMessage*>*) getPinnedMessagesByChannel:(WKChannel*)channel;

// 获取某个频道的最大version
-(uint64_t) getMaxVersion:(WKChannel*)channel;

// 删除某个频道的所有置顶
-(void) deletePinnedByChannel:(WKChannel*)channel;

// 删除某条消息的置顶
-(void) deletePinnedByMessageId:(uint64_t)messageId;

// 获取某条置顶消息
-(WKPinnedMessage*) getPinnedMessageByMessageId:(uint64_t)messageId;

// 添加或更新置顶消息
-(void) addOrUpdatePinnedMessages:(NSArray<WKPinnedMessage*>*)messages;

// 根据消息id查询是否置顶
-(BOOL) hasPinned:(uint64_t)messageId;

@end

NS_ASSUME_NONNULL_END
