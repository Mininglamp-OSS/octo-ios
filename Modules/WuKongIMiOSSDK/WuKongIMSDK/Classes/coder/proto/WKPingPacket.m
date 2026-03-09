//
//  WKPingPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKPingPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
@implementation WKPingPacket

-(WKPacketType) packetType {
    return WK_PING;
}

- (WKPacket *)decode:(NSData *)body header:(WKHeader *)header {
    return nil;
}

- (NSData *)encode:(WKPingPacket *)packet {
   
    return nil;
}


@end
