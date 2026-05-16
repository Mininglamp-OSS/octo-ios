//
//  WKChannel.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKChannel.h"
#import "WKConst.h"

@implementation WKChannel

-(instancetype) initWith:(NSString*)channelId channelType:(uint8_t)channelType {
    self = [super init];
    if(self) {
        self.channelId = channelId;
        self.channelType = channelType;
    }
    return self;
}

+ (instancetype)channelID:(NSString *)channelId channelType:(uint8_t)channelType {
    return [[WKChannel alloc] initWith:channelId channelType:channelType];
}

+ (instancetype)groupWithChannelID:(NSString *)channelID {
    return [[WKChannel alloc] initWith:channelID channelType:WK_GROUP];
}

+ (instancetype)personWithChannelID:(NSString *)channelID {
    return [[WKChannel alloc] initWith:channelID channelType:WK_PERSON];
}

-(BOOL) isEqual:(id)obj{
    if(self == obj) {
        return YES;
    }
    WKChannel *cm = (WKChannel*)obj;
    if(self.channelId && [self.channelId isEqual:cm.channelId] &&self.channelType == cm.channelType) {
        return YES;
    }
    
    return NO;
}

- (NSUInteger)hash {
    return [self.channelId hash] ^ self.channelType;
}
- (id)copyWithZone:(NSZone *)zone{
     WKChannel *channel = [WKChannel allocWithZone:zone];
    channel.channelId = self.channelId;
    channel.channelType = self.channelType;
    return channel;
}
- (NSString *)description
{
    return [NSString stringWithFormat:@"channelId: %@ channelType: %d", self.channelId,self.channelType];
}

// 转换为map
-(NSDictionary*) toMap {
    return @{@"channel_id":self.channelId?:@"",@"channel_type":@(self.channelType)};
}
// 从map初始化
+(WKChannel*) fromMap:(NSDictionary*)dict{
    return [[WKChannel alloc] initWith:dict[@"channel_id"] channelType:[dict[@"channel_type"] intValue]];
}

@end
