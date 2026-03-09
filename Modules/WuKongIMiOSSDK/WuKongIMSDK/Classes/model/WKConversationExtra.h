//
//  WKConversationExtra.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/23.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationExtra : NSObject

@property (nonatomic, strong) WKChannel *channel;
//@property (nonatomic, assign) uint32_t browseTo;  // 预览位置 预览到的位置，与会话保持位置不同的是 预览到的位置是用户读到的最大的messageSeq。跟未读消息数量有关系
@property (nonatomic, assign) uint32_t keepMessageSeq; // 保持的位置的messageSeq
@property (nonatomic, assign) NSInteger keepOffsetY;  //  保持的位置Y的偏移量
@property (nonatomic, copy) NSString *draft;  // 草稿
@property (nonatomic, assign) int64_t version; // 数据版本

@end

NS_ASSUME_NONNULL_END
