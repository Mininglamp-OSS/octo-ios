//
//  WKPakcetBodyManager.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKPakcetBodyCoderManager.h"
#import "WKConnectPacket.h"
#import "WKConnackPacket.h"
#import "WKSendPacket.h"
#import "WKSendackPacket.h"
#import "WKRecvPacket.h"
#import "WKRecvackPacket.h"
#import "WKDisconnectPacket.h"
#import "WKPingPacket.h"
#import "WKPongPacket.h"
@interface WKPakcetBodyCoderManager ()

@property(nonatomic,strong) NSMutableDictionary *bodyCoderDic;
@end



@implementation WKPakcetBodyCoderManager

-(instancetype) init {
    self = [super init];
    if(self) {
        self.bodyCoderDic = [[NSMutableDictionary alloc] init];
        // 注册连接包
        WKConnectPacket *connectPacket = [WKConnectPacket new];
        [self registerBodyCoder:[connectPacket header].packetType bodyCoder:connectPacket];
        // 连接回执
        WKConnackPacket *connackPacket = [WKConnackPacket new];
        [self registerBodyCoder:[connackPacket header].packetType bodyCoder:connackPacket];
        // 发送消息
        WKSendPacket *sendPacket = [WKSendPacket new];
        [self registerBodyCoder:[sendPacket header].packetType bodyCoder:sendPacket];
        // 收消息
        WKRecvPacket *recvPacket = [WKRecvPacket new];
        [self registerBodyCoder:[recvPacket header].packetType bodyCoder:recvPacket];
        // 发送消息回执
        WKSendackPacket *sendackPacket = [WKSendackPacket new];
        [self registerBodyCoder:[sendackPacket header].packetType bodyCoder:sendackPacket];
        // 收取消息回执
        WKRecvackPacket *recvackPacket = [WKRecvackPacket new];
        [self registerBodyCoder:[recvackPacket header].packetType bodyCoder:recvackPacket];
        // 断开连接
        WKDisconnectPacket *disconnectPacket = [WKDisconnectPacket new];
        [self registerBodyCoder:[disconnectPacket header].packetType bodyCoder:disconnectPacket];
        // ping
        WKPingPacket *pingPacket = [WKPingPacket new];
        [self registerBodyCoder:[pingPacket header].packetType bodyCoder:pingPacket];
        // pong
        WKPongPacket *pongPacket = [WKPongPacket new];
        [self registerBodyCoder:[pongPacket header].packetType bodyCoder:pongPacket];
    }
    return self;
}

-(void) registerBodyCoder:(WKPacketType)packetType bodyCoder:(id<WKPacketBodyCoder>)bodyCoder{
    [self.bodyCoderDic setObject:bodyCoder forKey:[NSString stringWithFormat:@"%i",packetType]];
}

-(id<WKPacketBodyCoder>) getBodyCoder:(WKPacketType)packetType{
    
    return [self.bodyCoderDic objectForKey:[NSString stringWithFormat:@"%i",packetType]];
}

@end
