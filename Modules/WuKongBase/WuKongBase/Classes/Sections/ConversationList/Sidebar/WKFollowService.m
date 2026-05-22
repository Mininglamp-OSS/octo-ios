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

/// URL query 单个 value 的转义。URLQueryAllowedCharacterSet 还允许 & = ? # 等
/// query 分隔符通过，单值场景必须移除这些防止参数被截断或污染相邻参数。
- (NSString *)queryEncode:(NSString *)raw {
    NSString *s = raw ?: @"";
    static NSCharacterSet *valueAllowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *cs = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        // 关键：剔掉 query 分隔符
        [cs removeCharactersInString:@"&=?#+"];
        valueAllowed = [cs copy];
    });
    return [s stringByAddingPercentEncodingWithAllowedCharacters:valueAllowed] ?: s;
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
    // WKAPIClient 的 requestSerializer 是 JSON, 且 HTTPMethodsEncodingParametersInURI
    // 只含 GET/HEAD —— DELETE 会把 parameters 当 JSON body 发，但 server 是
    // c.Query("peer_uid") 只读 URL query。所以这里手动把参数拼进 path,
    // parameters 传 nil 避免 body。
    NSString *encoded = [self queryEncode:peerUid];
    NSString *path = [NSString stringWithFormat:@"follow/dm?peer_uid=%@", encoded];
    return [[WKAPIClient sharedClient] DELETE:path parameters:nil];
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
    // 同 unfollowDM:，server 是 c.Query 只读 query string，不能放 JSON body
    NSString *encoded = [self queryEncode:threadChannelId];
    NSString *path = [NSString stringWithFormat:@"follow/thread?thread_channel_id=%@", encoded];
    return [[WKAPIClient sharedClient] DELETE:path parameters:nil];
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
