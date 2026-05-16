//
//  WKSendackPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSendackPacket :  WKPacket<WKPacketBodyCoder>
// 客户端序列号 (客户端提供，服务端原样返回)
@property(nonatomic,assign) uint32_t clientSeq;
// 消息ID（全局唯一）
@property(nonatomic,assign) uint64_t messageId;
// 消息序列号（用户唯一，有序）
@property(nonatomic,assign) uint32_t messageSeq;
// 原因代码
@property(nonatomic,assign) uint8_t reasonCode;

@end

NS_ASSUME_NONNULL_END
