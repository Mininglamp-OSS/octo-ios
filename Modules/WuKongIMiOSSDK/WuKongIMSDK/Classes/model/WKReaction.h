//
//  WKReaction.h
//  WuKongIMSDK
//
//  Created by tt on 2021/9/13.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKReaction : NSObject

@property(nonatomic,strong) WKChannel *channel;

// 消息ID（全局唯一）
@property(nonatomic,assign) uint64_t messageId;
// 回应uid
@property(nonatomic,copy) NSString *uid;

// 回应的emoji
@property(nonatomic,copy) NSString *emoji;

@property(nonatomic,assign) uint64_t version;

// 回应时间
@property(nonatomic,copy) NSString *createdAt;

@property(nonatomic,assign) NSInteger isDeleted;
@end

NS_ASSUME_NONNULL_END
