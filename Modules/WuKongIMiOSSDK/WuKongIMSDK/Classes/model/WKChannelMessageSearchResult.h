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
// 最新一条命中消息的原始 content（JSON 的 NSData，对应 message 表 content 列/BLOB），
// searchableWord 为空时用于解码出预览片段
@property(nonatomic,copy) NSData *content;
// 最新一条命中消息的内容类型
@property(nonatomic,assign) NSInteger contentType;
// 最新一条命中消息的时间戳（秒）
@property(nonatomic,assign) NSInteger timestamp;

@end

NS_ASSUME_NONNULL_END
