// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKBotListVM.m
//  WuKongContacts
//

#import "WKBotListVM.h"

@implementation WKBotListVM

- (AnyPromise *)requestBots {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId && spaceId.length > 0) {
        // Space 模式：my_bots + space_bots(status=added) 合并去重
        AnyPromise *myBotsPromise = [[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:@{@"space_id": spaceId}];
        AnyPromise *spaceBotsPromise = [[WKAPIClient sharedClient] GET:@"robot/space_bots" parameters:@{@"space_id": spaceId}];

        return PMKWhen(@[myBotsPromise, spaceBotsPromise]).then(^(NSArray *results) {
            NSMutableArray *bots = [NSMutableArray array];
            NSMutableSet *addedUids = [NSMutableSet set];

            // my_bots
            NSArray *myBots = results.count > 0 ? results[0] : @[];
            if (myBots && [myBots isKindOfClass:[NSArray class]]) {
                for (id item in myBots) {
                    NSDictionary *m = [item isKindOfClass:[NSDictionary class]] ? item : nil;
                    if (!m) continue;
                    WKBotResp *resp = [WKBotResp new];
                    resp.uid = m[@"uid"] ?: @"";
                    resp.name = m[@"name"] ?: @"";
                    resp.desc = m[@"description"] ?: @"";
                    [bots addObject:resp];
                    [addedUids addObject:resp.uid];
                }
            }

            // space_bots：只合并 status=added 的
            NSArray *spaceBots = results.count > 1 ? results[1] : @[];
            if (spaceBots && [spaceBots isKindOfClass:[NSArray class]]) {
                for (id item in spaceBots) {
                    NSDictionary *bot = [item isKindOfClass:[NSDictionary class]] ? item : nil;
                    if (!bot) continue;
                    NSString *uid = bot[@"uid"];
                    if (!uid || [addedUids containsObject:uid]) continue;
                    NSString *status = bot[@"status"];
                    if (![status isEqualToString:@"added"]) continue;
                    WKBotResp *resp = [WKBotResp new];
                    resp.uid = uid;
                    resp.name = bot[@"name"] ?: @"";
                    resp.desc = bot[@"description"] ?: @"";
                    [bots addObject:resp];
                }
            }

            return bots;
        });
    }
    // 非 Space 模式
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
