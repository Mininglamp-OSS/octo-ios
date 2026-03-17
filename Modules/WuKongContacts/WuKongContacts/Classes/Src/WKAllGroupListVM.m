//
//  WKAllGroupListVM.m
//  WuKongContacts
//

#import "WKAllGroupListVM.h"

@implementation WKAllGroupListVM

- (AnyPromise *)requestGroups {
    return [[WKAPIClient sharedClient] GET:@"group/my" parameters:@{
        @"page_size": @(1000),
    } model:WKMyGroupResp.class];
}

@end
