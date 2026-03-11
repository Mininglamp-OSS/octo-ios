//
//  WKSpaceGateVM.m
//  WuKongLogin
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceGateVM.h"

@implementation WKSpace
@end

@implementation WKSpaceCreateResp
@end

@implementation WKInviteResp
@end

@implementation WKSpaceGateVM

- (AnyPromise *)getMySpaces {
    return [[WKAPIClient sharedClient] GET:@"space/my" parameters:nil];
}

- (AnyPromise *)createSpace:(NSString *)name description:(NSString *)description {
    return [[WKAPIClient sharedClient] POST:@"space/create" parameters:@{@"name":name?:@"",@"description":description?:@""}];
}

- (AnyPromise *)joinSpace:(NSString *)inviteCode {
    return [[WKAPIClient sharedClient] POST:@"space/join" parameters:@{@"invite_code":inviteCode?:@""}];
}

- (AnyPromise *)createInvite:(NSString *)spaceId {
    return [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"space/%@/invite",spaceId] parameters:@{}];
}

@end
