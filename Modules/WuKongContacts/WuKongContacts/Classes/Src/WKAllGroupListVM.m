// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAllGroupListVM.m
//  WuKongContacts
//

#import "WKAllGroupListVM.h"

@implementation WKAllGroupListVM

- (AnyPromise *)requestGroups {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"page_size": @(1000),
    }];
    if (spaceId && spaceId.length > 0) {
        params[@"space_id"] = spaceId;
    }
    return [[WKAPIClient sharedClient] GET:@"group/my" parameters:params model:WKMyGroupResp.class];
}

@end
