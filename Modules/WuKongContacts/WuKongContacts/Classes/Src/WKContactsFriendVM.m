// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKContactsFriendVM.m
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import "WKContactsFriendVM.h"

@implementation WKContactsFriendVM


-(AnyPromise*) requestMaillist {
    
    return [[WKAPIClient sharedClient] GET:@"user/maillist" parameters:nil model:WKContactsFriendResp.class];
}

-(AnyPromise*) requestUpload:(NSArray<WKContactsFriendModel*>*)friends {
    NSMutableArray *items = [NSMutableArray array];
    if(friends && friends.count>0) {
        for (WKContactsFriendModel *friendModel in friends) {
            [items addObject:@{
                @"name": friendModel.name,
                @"phone": friendModel.phone,
            }];
        }
    }
    return [[WKAPIClient sharedClient] POST:@"user/maillist" parameters:items];
}

-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark vercode:(NSString*)vercode{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{@"to_uid":uid?:@"",@"remark":remark?:@"",@"vercode":vercode?:@""}];
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId.length > 0) {
        params[@"space_id"] = spaceId;
    }
    return [[WKAPIClient sharedClient] POST:@"friend/apply" parameters:params];
}

@end


@implementation WKContactsFriendResp

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKContactsFriendResp *resp = [WKContactsFriendResp new];
    resp.uid = dictory[@"uid"];
    resp.name = dictory[@"name"];
    resp.zone = dictory[@"zone"];
    resp.phone = dictory[@"phone"];
    resp.vercode = dictory[@"vercode"];
    resp.isFriend = [dictory[@"is_friend"] boolValue];
    return resp;
}

@end

