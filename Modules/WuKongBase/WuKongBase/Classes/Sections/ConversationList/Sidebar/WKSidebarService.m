// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKSidebarService.m
//  WuKongBase
//

#import "WKSidebarService.h"
#import "WKSidebarItemEntity.h"
#import "WKAPIClient.h"

@implementation WKSidebarSyncResponse

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKSidebarSyncResponse *r = [[WKSidebarSyncResponse alloc] init];
    NSArray *raw = dict[@"items"];
    r.items = [raw isKindOfClass:[NSArray class]] ? [WKSidebarItemEntity fromDictArray:raw] : @[];
    r.version = [dict[@"version"] longLongValue];
    r.follow_version = [dict[@"follow_version"] integerValue];
    return r;
}

@end

@implementation WKSidebarService

+ (instancetype)shared {
    static WKSidebarService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKSidebarService alloc] init];
    });
    return instance;
}

- (AnyPromise *)syncWithTab:(WKSidebarTab)tab
                    version:(int64_t)version
               lastMsgSeqs:(NSString *)lastMsgSeqs
                 deviceUUID:(NSString *)deviceUUID {
    NSDictionary *params = @{
        @"tab":            tab == WKSidebarTabFollow ? @"follow" : @"recent",
        @"version":        @(version),
        @"last_msg_seqs":  lastMsgSeqs ?: @"",
        @"msg_count":      @1,
        @"device_uuid":    deviceUUID ?: @"",
    };
    return [[WKAPIClient sharedClient] POST:@"sidebar/sync" parameters:params].then(^(id result) {
        if ([result isKindOfClass:[NSDictionary class]]) {
            return [WKSidebarSyncResponse fromDict:result];
        }
        return [WKSidebarSyncResponse fromDict:@{}];
    });
}

@end
