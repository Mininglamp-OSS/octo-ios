//
//  WKPongPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKPongPacket.h"
#import "WKConst.h"
#import "WKSDK.h"
@implementation WKPongPacket

-(WKPacketType) packetType {
    return WK_PONG;
}

- (WKPacket *)decode:(NSData *)body header:(WKHeader *)header {
    
    return nil;
}

- (NSData *)encode:(WKPacket *)packet {
    return nil;
}



- (NSString *)description{
    
    return [NSString stringWithFormat:@"PONG"];
}
@end
