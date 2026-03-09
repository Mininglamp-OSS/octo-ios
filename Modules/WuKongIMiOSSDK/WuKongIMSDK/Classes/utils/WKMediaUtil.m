//
//  WKMediaUtils.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import "WKMediaUtil.h"

@implementation WKMediaUtil

+(NSString*) getLocalPath:(id<WKMediaProto>)media {
   WKChannel *channel =  media.message.channel;
    return [NSString stringWithFormat:@"%@/%@%@",[self getChannelDir:channel],media.message.clientMsgNo,media.extension?:@""];
}

+(NSString*) getThumbLocalPath:(id<WKMediaProto>)media {
    WKChannel *channel =  media.message.channel;
    return [NSString stringWithFormat:@"%@/%@_thumb%@",[self getChannelDir:channel],media.message.clientMsgNo,media.thumbExtension?:@""];
}

+(NSString*) getChannelDir:(WKChannel*) channel {
    return [NSString stringWithFormat:@"%d/%@",channel.channelType,channel.channelId];
}
@end
