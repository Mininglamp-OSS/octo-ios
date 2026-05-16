//
//  WKConnackPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/26.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConnackPacket : WKPacket<WKPacketBodyCoder>

// 服务端版本
@property(nonatomic,assign) uint8_t serverVersion;
// 通过客户端的RSA公钥加密的服务端DH公钥
@property(nonatomic,copy) NSString *serverKey;
// 安全吗
@property(nonatomic,copy) NSString *salt;
// 客户端与服务器的时间差值
@property(nonatomic,assign) int64_t timeDiff;

// 连接返回原因代号
@property(nonatomic,assign) uint8_t reasonCode;

@end

NS_ASSUME_NONNULL_END
