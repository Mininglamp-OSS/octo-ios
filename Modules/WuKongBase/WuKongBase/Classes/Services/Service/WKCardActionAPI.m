//
//  WKCardActionAPI.m
//  WuKongBase
//

#import "WKCardActionAPI.h"

@implementation WKCardActionAPI

+ (AnyPromise *)submitCardAction:(NSString *)actionId
                       messageId:(NSString *)messageId
                       channelId:(NSString *)channelId
                     channelType:(uint8_t)channelType
                          inputs:(NSDictionary *)inputs
                     clientToken:(NSString *)clientToken {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"message_id"] = messageId ?: @"";
    params[@"channel_id"] = channelId ?: @"";
    params[@"channel_type"] = @(channelType);
    params[@"action_id"] = actionId ?: @"";
    params[@"inputs"] = inputs ?: @{};
    params[@"client_token"] = clientToken ?: @"";
    // 刻意不传 data —— 服务端从存储帧提取（anti-forgery）
    return [[WKAPIClient sharedClient] POST:@"message/card/action" parameters:params];
}

@end
