//
//  WKPinnedMessage.h
//  WuKongIMSDK
//
//  Created by tt on 2024/5/22.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKPinnedMessage : NSObject

@property(nonatomic,assign) uint64_t messageId;
@property(nonatomic,assign)  uint32_t messageSeq; // 消息序列号（用户唯一，有序）

@property(nonatomic,strong) WKChannel *channel; // 频道

@property(nonatomic,assign) BOOL isDeleted; // 消息是否被删除

@property(nonatomic,assign) uint64_t version;



@end

NS_ASSUME_NONNULL_END
