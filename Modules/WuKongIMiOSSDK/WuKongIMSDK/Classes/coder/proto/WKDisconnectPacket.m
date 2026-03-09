//
//  WKDisconnectPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/30.
//

#import "WKDisconnectPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
@implementation WKDisconnectPacket



-(WKPacketType) packetType {
    return WK_DISCONNECT;
}

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header {
    return [self decodeLM:body header:header];
}

-(WKPacket*) decodeLM:(NSData*) body header:(WKHeader*)header {
    WKDisconnectPacket *packet = [WKDisconnectPacket new];
    WKDataRead *reader = [[WKDataRead alloc] initWithData:body];
    packet.reasonCode = [reader readUint8];
    packet.reason = [reader readString];
    return packet;
}

-(WKPacket*) decodeMOS:(NSData*) body header:(WKHeader*)header {
    WKDisconnectPacket *packet = [WKDisconnectPacket new];
    WKDataRead *reader = [[WKDataRead alloc] initWithData:body];
    [reader readUint8]; // login_type
    [reader readUint64]; // from_cust_id
    uint32_t status = [reader readUint32];
    if(status == 200 || status == 0) {
        packet.reasonCode = WK_REASON_SUCCESS;
    }else{
        packet.reasonCode = WK_REASON_AUTHFAIL;
    }
    
    packet.reason = @"";
    return packet;
}

-(NSData*) encode:(WKDisconnectPacket*)packet{
    return nil;
}

- (NSString *)description{
    
    return [NSString stringWithFormat:@"reasonCode:%hhu reason:%@",self.reasonCode,self.reason];
}


@end
