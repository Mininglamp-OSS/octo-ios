// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKSidebarItemEntity.m
//  WuKongBase
//

#import "WKSidebarItemEntity.h"

static NSString *wkSidebarSafeString(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    return [NSString stringWithFormat:@"%@", value];
}

static NSString *_Nullable wkSidebarOptionalString(id value) {
    if (!value || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *s = value;
        return s;
    }
    return [NSString stringWithFormat:@"%@", value];
}

@implementation WKSidebarItemEntity

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKSidebarItemEntity *e = [[WKSidebarItemEntity alloc] init];
    e.target_type  = (WKFollowTargetType)[dict[@"target_type"] integerValue];
    e.target_id    = wkSidebarSafeString(dict[@"target_id"]);
    e.channel_type = [dict[@"channel_type"] integerValue];
    e.channel_id   = wkSidebarSafeString(dict[@"channel_id"]);
    e.timestamp    = [dict[@"timestamp"] longLongValue];
    e.unread       = [dict[@"unread"] integerValue];
    e.is_pinned    = [dict[@"is_pinned"] boolValue];
    e.is_followed  = [dict[@"is_followed"] boolValue];
    e.category_id  = wkSidebarOptionalString(dict[@"category_id"]);

    e.category_sort = [dict[@"category_sort"] integerValue];
    // follow_sort 不存在或 null 时用 NSIntegerMax 兜底，保证客户端重排时排到末尾
    id rawFollowSort = dict[@"follow_sort"];
    if (!rawFollowSort || [rawFollowSort isKindOfClass:[NSNull class]]) {
        e.follow_sort = NSIntegerMax;
    } else {
        e.follow_sort = [rawFollowSort integerValue];
    }

    e.parent_channel_id = wkSidebarOptionalString(dict[@"parent_channel_id"]);
    return e;
}

+ (NSArray<WKSidebarItemEntity *> *)fromDictArray:(NSArray *)array {
    NSMutableArray<WKSidebarItemEntity *> *result = [NSMutableArray array];
    for (NSDictionary *dict in array) {
        if ([dict isKindOfClass:[NSDictionary class]]) {
            [result addObject:[WKSidebarItemEntity fromDict:dict]];
        }
    }
    return result;
}

- (NSDictionary *)toDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"target_type"]   = @(self.target_type);
    dict[@"target_id"]     = self.target_id ?: @"";
    dict[@"channel_type"]  = @(self.channel_type);
    dict[@"channel_id"]    = self.channel_id ?: @"";
    dict[@"timestamp"]     = @(self.timestamp);
    dict[@"unread"]        = @(self.unread);
    dict[@"is_pinned"]     = @(self.is_pinned);
    dict[@"is_followed"]   = @(self.is_followed);
    dict[@"category_sort"] = @(self.category_sort);
    if (self.category_id) dict[@"category_id"] = self.category_id;
    if (self.parent_channel_id) dict[@"parent_channel_id"] = self.parent_channel_id;
    // NSIntegerMax 是"服务端没给 follow_sort"的哨兵，不序列化 —— 回读时 fromDict:
    // 会重新兜底成 NSIntegerMax，语义一致且不会把哨兵当真实值写进缓存文件。
    if (self.follow_sort != NSIntegerMax) dict[@"follow_sort"] = @(self.follow_sort);
    return dict;
}

- (NSString *)followKey {
    return [NSString stringWithFormat:@"%ld::%@", (long)self.target_type, self.target_id ?: @""];
}

@end
