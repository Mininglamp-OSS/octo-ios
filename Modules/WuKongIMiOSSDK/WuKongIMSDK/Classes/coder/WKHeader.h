//
//  WKHeader.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKHeader : NSObject

// 剩余长度
@property(nonatomic,assign) uint32_t remainLength;
// 包类型
@property(nonatomic,assign) uint8_t packetType;

// 是否显示未读
@property(nonatomic,assign) BOOL showUnread; // RedDot

// 是否不存储
@property(nonatomic,assign) BOOL noPersist;

// 是否同步一次
@property(nonatomic,assign) BOOL syncOnce;

// 是否存在服务版本（connack包有效）
@property(nonatomic,assign) BOOL hasServerVersion;

@end

NS_ASSUME_NONNULL_END
