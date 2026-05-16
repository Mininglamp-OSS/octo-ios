//
//  WKUserOnlineResp.m
//  WuKongBase
//
//  Created by tt on 2023/1/3.
//

#import "WKUserOnlineResp.h"

@implementation WKUserOnlineResp

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKUserOnlineResp *resp = [WKUserOnlineResp new];
    resp.uid = dictory[@"uid"]?:@"";
    resp.deviceFlag = [dictory[@"device_flag"] integerValue];
    resp.lastOnline = [dictory[@"last_online"] integerValue];
    resp.lastOffline = [dictory[@"last_offline"] integerValue];
    resp.online = [dictory[@"online"] boolValue];
    
    return resp;
}

@end
