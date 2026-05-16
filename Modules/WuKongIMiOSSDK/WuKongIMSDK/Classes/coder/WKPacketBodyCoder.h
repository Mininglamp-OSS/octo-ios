//
//  WKPacketBodyCoder.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//
#import "WKPacket.h"

@protocol WKPacketBodyCoder <NSObject>

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header;

-(NSData*) encode:(WKPacket*)packet;

@end
