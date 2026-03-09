//
//  WKDisconnectPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/30.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKDisconnectPacket :  WKPacket<WKPacketBodyCoder>

// 原因代码
@property(nonatomic,assign) uint8_t reasonCode;
// 原因字符串
@property(nonatomic,copy) NSString *reason;

@end

NS_ASSUME_NONNULL_END
