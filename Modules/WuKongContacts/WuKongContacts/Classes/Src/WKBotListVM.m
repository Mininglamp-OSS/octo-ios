//
//  WKBotListVM.m
//  WuKongContacts
//

#import "WKBotListVM.h"

@implementation WKBotListVM

- (AnyPromise *)requestBots {
    return [[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:nil model:WKBotResp.class];
}

@end

@implementation WKBotResp

+ (WKBotResp *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKBotResp *resp = [WKBotResp new];
    resp.uid = dictory[@"uid"];
    resp.name = dictory[@"name"];
    resp.desc = dictory[@"description"] ?: @"";
    return resp;
}

@end
