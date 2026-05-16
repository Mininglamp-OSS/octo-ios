//
//  WKHeader.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import "WKHeader.h"

@implementation WKHeader

- (NSString *)description{
    
    return [NSString stringWithFormat:@"HEADER remainLength:%u packetType:%hhu showUnread:%u noPersist:%u syncOnce:%u",self.remainLength,self.packetType,self.showUnread,self.noPersist,self.syncOnce];
}

@end
