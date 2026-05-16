//
//  WKConnectPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKConnectPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
@implementation WKConnectPacket

-(WKPacketType) packetType {
    return WK_CONNECT;
}

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header {
    
    return nil;
}

-(NSData*) encode:(WKConnectPacket*)packet{
    return [self encodeLM:packet];
}

//将data改成固定长度data
- (NSData*)dataToLengthData:(NSData*)data Length:(int)length
{
    NSMutableData *tempData = [NSMutableData data];
    unsigned long long a = 0;
    for (int i=0; i<(int)((length-data.length)/sizeof(a)); i++) {
        [tempData appendBytes:&a length:sizeof(a)];
    }
    
    [tempData appendBytes:&a length:(length-data.length)%sizeof(a)];
    [tempData appendData:data];
    return tempData;
    
}

-(NSData*) encodeLM:(WKConnectPacket*)packet {
    WKDataWrite  *writer = [[WKDataWrite alloc] init];
     // 协议版本
    [writer writeUint8:packet.version];
     // 设备标示符 0.表示APP
    [writer writeUint8:packet.deviceFlag];
     // 设备唯一ID
    [writer writeVariableString:packet.deviceId];
     // 用户uid
    [writer writeVariableString:packet.uid];
     // 用户token
    [writer writeVariableString:packet.token];
    // 客户端时间戳
    [writer writeUint64:packet.clientTimestamp];
    // clientKey
    [writer writeVariableString:packet.clientKey];
     
     return [writer toData];
}

@end
