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

- (NSString *)followKey {
    return [NSString stringWithFormat:@"%ld::%@", (long)self.target_type, self.target_id ?: @""];
}

@end
