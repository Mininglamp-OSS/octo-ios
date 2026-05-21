// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowService.m
//  WuKongBase
//

#import "WKFollowService.h"
#import "WKAPIClient.h"

@implementation WKFollowSortItem

- (NSDictionary *)toDict {
    return @{
        @"target_type": @(self.target_type),
        @"target_id":   self.target_id ?: @"",
        @"sort":        @(self.sort),
    };
}

@end

@implementation WKFollowService

+ (instancetype)shared {
    static WKFollowService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKFollowService alloc] init];
    });
    return instance;
}

#pragma mark - DM

- (AnyPromise *)followDM:(NSString *)peerUid categoryId:(nullable NSString *)categoryId {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"peer_uid"] = peerUid ?: @"";
    if (categoryId.length > 0) {
        params[@"category_id"] = categoryId;
    }
    return [[WKAPIClient sharedClient] POST:@"follow/dm" parameters:params];
}

- (AnyPromise *)unfollowDM:(NSString *)peerUid {
    NSDictionary *params = @{ @"peer_uid": peerUid ?: @"" };
    return [[WKAPIClient sharedClient] DELETE:@"follow/dm" parameters:params];
}

#pragma mark - Channel (Group)

- (AnyPromise *)unfollowChannel:(NSString *)groupNo {
    NSDictionary *params = @{ @"group_no": groupNo ?: @"" };
    return [[WKAPIClient sharedClient] POST:@"follow/channel/unfollow" parameters:params];
}

- (AnyPromise *)refollowChannel:(NSString *)groupNo {
    NSDictionary *params = @{ @"group_no": groupNo ?: @"" };
    return [[WKAPIClient sharedClient] POST:@"follow/channel/refollow" parameters:params];
}

#pragma mark - Thread

- (AnyPromise *)followThread:(NSString *)threadChannelId {
    NSDictionary *params = @{ @"thread_channel_id": threadChannelId ?: @"" };
    return [[WKAPIClient sharedClient] POST:@"follow/thread" parameters:params];
}

- (AnyPromise *)unfollowThread:(NSString *)threadChannelId {
    NSDictionary *params = @{ @"thread_channel_id": threadChannelId ?: @"" };
    return [[WKAPIClient sharedClient] DELETE:@"follow/thread" parameters:params];
}

#pragma mark - Sort

- (AnyPromise *)sortItems:(NSArray<WKFollowSortItem *> *)items version:(NSInteger)version {
    NSMutableArray<NSDictionary *> *payload = [NSMutableArray arrayWithCapacity:items.count];
    for (WKFollowSortItem *it in items) {
        [payload addObject:[it toDict]];
    }
    NSDictionary *params = @{
        @"items":   payload,
        @"version": @(version),
    };
    return [[WKAPIClient sharedClient] PUT:@"follow/sort" parameters:params];
}

#pragma mark - Error helpers

+ (BOOL)isVersionConflictError:(nullable NSError *)error {
    if (!error) return NO;
    // WKApp errorHandler 把 400 响应转成 NSError，domain = 后端 msg，userInfo = 整个 errorDic
    NSString *msg = error.domain;
    if (msg.length > 0 && [msg rangeOfString:@"version conflict" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    NSDictionary *info = error.userInfo;
    NSString *infoMsg = info[@"msg"];
    if ([infoMsg isKindOfClass:[NSString class]]
        && [infoMsg rangeOfString:@"version conflict" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    return NO;
}

@end
