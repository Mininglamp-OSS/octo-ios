//
//  WKSendPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKSendPacket.h"
#import "WKConst.h"
#import "WKData.h"
#import "WKSDK.h"
#import "WKSecurityManager.h"
@implementation WKSendPacket


- (WKSetting *)setting {
    if(!_setting) {
        _setting = [WKSetting new];
    }
    return  _setting;
}

-(WKPacketType) packetType {
    return WK_SEND;
}

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header {
    
    return nil;
}
-(NSData*) encode:(WKSendPacket*)packet {
    return [self encodeLM:packet];
}

-(NSData*) encodeLM:(WKSendPacket*)packet{
    WKDataWrite  *writer = [[WKDataWrite alloc] init];
    
    uint8_t setting = [packet.setting toUint8];
    [writer writeUint8:setting];
    
    NSString *payloadStr = [[NSString alloc] initWithData:packet.payload encoding:NSUTF8StringEncoding];
    NSString *payloadEnc = [[WKSecurityManager shared] encryption:payloadStr];
    
    packet.payload = [payloadEnc dataUsingEncoding:NSUTF8StringEncoding];
    
    
    // 消息序列号(客户端维护)
    [writer writeUint32:packet.clientSeq];
    // 客户端唯一消息编号
    [writer writeVariableString:packet.clientMsgNo];
    //  频道ID
    [writer writeVariableString:packet.channelId];
    // 频道类型
    [writer writeUint8:packet.channelType];
    if(WKSDK.shared.options.protoVersion>=3) {
        // expire
        [writer writeUint32:(uint32_t)packet.expire];
    }
   
    NSString *signStr = [packet veritifyString];
    NSString *msgKey = [[WKSecurityManager shared] encryption:signStr];
    [writer writeVariableString:[[WKSecurityManager shared] md5:msgKey]];
    
    
    if(packet.setting.topic) {
        [writer writeVariableString:packet.topic?:@""];
    }
    // 消息内容
    [writer writeData:packet.payload];
   
    
    return [writer toData];
}


-(NSString*) veritifyString {
    NSString *payloadStr = [[NSString alloc] initWithData:self.payload encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"%d%@%@%d%@",self.clientSeq,self.clientMsgNo?:@"",self.channelId?:@"",self.channelType,payloadStr?:@""];
}

@end
