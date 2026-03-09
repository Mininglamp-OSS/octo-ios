//
//  WKCoder.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKCoder.h"
#import "WKSDK.h"
#import "WKData.h"
#import "WKPongPacket.h"
#import "WKSendPacket.h"
@implementation WKCoder

-(NSData*) encode:(WKPacket*)packet {
    return [self encodeLM:packet];
}

-(WKPacket*) decode:(NSData*)data {
    return [self decodeLM:data];
}


// 编码(lmproto)
-(NSData*) encodeLM:(WKPacket*)packet {
    NSMutableData  *bufferData = [[NSMutableData alloc] init];
    // 编码头部
    uint8_t packetType = packet.header.packetType<<4;
    uint8_t flag = packet.header.syncOnce << 2 | packet.header.showUnread << 1 |   packet.header.noPersist;
    uint8_t fixHeader = (packetType | flag);
    [bufferData appendBytes:&fixHeader length:1];
    if(packetType == WK_PING) {
        return  bufferData;
    }
    // 编码body
    NSData *bodyBytes =  [[[WKSDK shared].bodyCoderManager getBodyCoder:packet.header.packetType] encode:packet];
    // 编码剩余长度并组合
    [bufferData appendData:[self encodeLength:(u_int32_t)bodyBytes.length]];
    // 组合body
    [bufferData appendData:bodyBytes];
    return bufferData;
}

// 解码(lmproto)
-(WKPacket*) decodeLM:(NSData*)data {
    WKDataRead *reader = [[WKDataRead alloc] initWithData:data];
    uint8_t flag =  [reader readUint8];
    uint8_t packetType = flag >> 4;
    if(packetType == WK_PONG) {
        return [WKPongPacket new];
    }
   uint32_t remainingLength =  [reader readLenth];
    
    WKHeader *header = [WKHeader new];
    header.remainLength = remainingLength;
    header.packetType = packetType;
    header.noPersist = (flag & 0x01) > 0;
    header.showUnread = ((flag >> 1) & 0x01) > 0;
    header.syncOnce = ((flag >> 2) & 0x01) > 0;
    if(packetType == WK_CONNACK) {
        header.hasServerVersion = (flag & 0x01) > 0;
    }
    
   return  [[[WKSDK shared].bodyCoderManager getBodyCoder:packetType] decode:reader.remainingData header:header];
}

-(NSData*) encodeLength:(u_int32_t) length {
    NSMutableData  *bufferData = [[NSMutableData alloc] init];
    while (length>0) {
       u_int32_t digit = length%0x80;
        length /= 0x80;
        if (length > 0) {
            digit |= 0x80;
        }
        [bufferData appendBytes:&digit length:1];
    }
    return bufferData;
}

unsigned long getMsgCheckCode(const char* buffer,unsigned long buffer_len) {
    unsigned char tmp[4]={0,0,0,0};
    unsigned long dest=0;
    unsigned long len = 0;
    unsigned long offset = 0;
    unsigned long i;
    while(len < buffer_len){
        if(len + 4 > buffer_len)
        {
            offset = buffer_len - len;
        }
        else
        {
            offset = 4;
        }
        
        
        for(i=0;i<offset;i++)
        {
            //NSLog(@"buffer is %02x",buffer[len + i]);
            tmp[i] ^= buffer[len + i];
            //NSLog(@"tmp is %02x",tmp[i]);
        }
        
        len += 4;
    }
    memcpy(&dest,tmp,4);
     return dest;
}

@end
