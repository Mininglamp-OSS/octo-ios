// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKOrgMembersListVM.m
//  WuKongContacts
//

#import "WKOrgMembersListVM.h"

@implementation WKOrgMembersListVM

- (AnyPromise *)requestMembers {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (!spaceId || spaceId.length == 0) {
        return [AnyPromise promiseWithValue:@[]];
    }
    NSString *encodedSpaceId = [spaceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *path = [NSString stringWithFormat:@"space/%@/members", encodedSpaceId];
    return [[WKAPIClient sharedClient] GET:path parameters:@{@"page": @"1", @"limit": @"10000"} model:WKOrgMemberResp.class].then(^(NSArray<WKOrgMemberResp*>* allMembers) {
        NSString *currentUID = [WKApp shared].loginInfo.uid;
        NSMutableArray *filtered = [NSMutableArray array];
        for (WKOrgMemberResp *member in allMembers) {
            if (member.robot) continue;
            if ([member.uid isEqualToString:currentUID]) continue;
            [filtered addObject:member];
        }
        return filtered;
    });
}

@end

@implementation WKOrgMemberResp

+ (WKOrgMemberResp *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKOrgMemberResp *resp = [WKOrgMemberResp new];
    resp.uid = dictory[@"uid"];
    resp.name = dictory[@"name"];
    resp.avatar = dictory[@"avatar"];
    resp.role = [dictory[@"role"] integerValue];
    resp.robot = [dictory[@"robot"] integerValue] == 1;
    return resp;
}

@end
