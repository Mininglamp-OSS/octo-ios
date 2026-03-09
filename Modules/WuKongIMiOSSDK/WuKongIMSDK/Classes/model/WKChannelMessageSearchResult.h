//
//  WKMessageSearchResult.h
//  WuKongIMSDK
//
//  Created by tt on 2020/5/10.
//

#import <Foundation/Foundation.h>
#import "WKChannelInfo.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelMessageSearchResult : NSObject

// 频道信息
@property(nonatomic,strong) WKChannel *channel;

// 消息数量
@property(nonatomic,assign) NSInteger messageCount;
// 客户端序列号
@property(nonatomic,assign) uint32_t orderSeq;
// 消息可搜索内容
@property(nonatomic,copy) NSString *searchableWord;

@end

NS_ASSUME_NONNULL_END
