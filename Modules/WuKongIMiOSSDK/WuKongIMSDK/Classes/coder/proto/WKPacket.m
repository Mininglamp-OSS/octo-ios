//
//  WKPacket.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKPacket.h"
#import "WKConst.h"
@implementation WKPacket


-(WKPacketType) packetType {
    return 0;
}

-(WKHeader*) header {
    if(_header) {
        return _header;
    }
    _header = [WKHeader new];
    _header.packetType = [self packetType];
    return _header;
}



@end
