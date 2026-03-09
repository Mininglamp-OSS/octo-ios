//
//  WKRecvackPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import "WKRecvackPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
@implementation WKRecvackPacket

-(WKPacketType) packetType {
    return WK_RECVACK;
}

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header {
    
    return nil;
}

-(NSData*) encode:(WKRecvackPacket*)packet{
    return [self encodeLM:packet];
}

-(NSData*) encodeLM:(WKRecvackPacket*)packet{
    WKDataWrite  *writer = [[WKDataWrite alloc] init];
    // 消息ID
    [writer writeUint64:packet.messageId];
    //  消息序号
    [writer writeUint32:packet.messageSeq];
    return [writer toData];
}


@end
