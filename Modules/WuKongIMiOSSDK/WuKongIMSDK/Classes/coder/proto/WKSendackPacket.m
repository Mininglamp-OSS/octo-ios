//
//  WKSendackPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKSendackPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
@implementation WKSendackPacket

-(WKPacketType) packetType {
    return WK_SENDACK;
}

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header {
    return [self decodeLM:body header:header];
}

-(WKPacket*) decodeLM:(NSData*) body header:(WKHeader*)header {
    WKSendackPacket *packet = [WKSendackPacket new];
    WKDataRead *reader = [[WKDataRead alloc] initWithData:body];
    packet.header = header;
    packet.messageId = [reader readUint64];
    packet.clientSeq = [reader readUint32];
    packet.messageSeq = [reader readUint32];
    packet.reasonCode = [reader readUint8];
    return packet;
}

-(NSData*) encode:(WKSendackPacket*)packet{
    return nil;
}

- (NSString *)description{
    
    return [NSString stringWithFormat:@"SENDACK clientSeq:%u  messageId:%llu messageSeq:%u reasonCode:%i",self.clientSeq,self.messageId,self.messageSeq,self.reasonCode];
}

@end
