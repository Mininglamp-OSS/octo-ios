//
//  WKRecvackPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import <Foundation/Foundation.h>
#import "WKPacket.h"
#import "WKPacketBodyCoder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKRecvackPacket : WKPacket<WKPacketBodyCoder>

@property(nonatomic,assign) uint64_t messageId;
@property(nonatomic,assign) uint32_t messageSeq;

@end

NS_ASSUME_NONNULL_END
