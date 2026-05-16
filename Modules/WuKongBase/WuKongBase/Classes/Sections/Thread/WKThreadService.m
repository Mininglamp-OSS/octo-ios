// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKThreadService.m
//  WuKongBase
//

#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKAPIClient.h"

@implementation WKThreadService

+ (instancetype)shared {
    static WKThreadService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKThreadService alloc] init];
    });
    return instance;
}

#pragma mark - API

- (AnyPromise *)createThread:(NSString *)groupNo
                        name:(NSString *)name
             sourceMessageId:(nullable NSString *)sourceMessageId
        sourceMessagePayload:(nullable NSDictionary *)sourceMessagePayload {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"name"] = name;
    if (sourceMessageId) {
        params[@"source_message_id"] = @([sourceMessageId longLongValue]);
    }
    if (sourceMessagePayload) {
        params[@"source_message_payload"] = sourceMessagePayload;
    }
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads", groupNo];
    return [[WKAPIClient sharedClient] POST:path parameters:params].then(^(NSDictionary *result) {
        return [WKThreadModel fromDict:result];
    });
}

- (AnyPromise *)listThreads:(NSString *)groupNo {
    return [self listThreads:groupNo pageIndex:1 pageSize:100].then(^(NSDictionary *result) {
        return result[@"list"] ?: @[];
    });
}

- (AnyPromise *)listThreads:(NSString *)groupNo pageIndex:(NSInteger)pageIndex pageSize:(NSInteger)pageSize {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads", groupNo];
    NSDictionary *params = @{@"page_index": @(pageIndex), @"page_size": @(pageSize)};
    return [[WKAPIClient sharedClient] GET:path parameters:params].then(^(id result) {
        NSArray *rawList = nil;
        NSInteger count = 0;
        if ([result isKindOfClass:[NSDictionary class]]) {
            rawList = result[@"list"];
            count = [result[@"count"] integerValue];
        } else if ([result isKindOfClass:[NSArray class]]) {
            rawList = result;
            count = ((NSArray *)result).count;
        }
        NSArray<WKThreadModel *> *models = [WKThreadModel fromDictArray:rawList ?: @[]];
        return @{@"count": @(count), @"list": models};
    });
}

- (AnyPromise *)getThread:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@", groupNo, shortId];
    return [[WKAPIClient sharedClient] GET:path parameters:@{}].then(^(NSDictionary *result) {
        return [WKThreadModel fromDict:result];
    });
}

- (AnyPromise *)joinThread:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"threads/%@/join", shortId];
    return [[WKAPIClient sharedClient] POST:path parameters:@{}];
}

- (AnyPromise *)leaveThread:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"threads/%@/leave", shortId];
    return [[WKAPIClient sharedClient] POST:path parameters:@{}];
}

- (AnyPromise *)archiveThread:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@/archive", groupNo, shortId];
    return [[WKAPIClient sharedClient] POST:path parameters:@{}];
}

- (AnyPromise *)unarchiveThread:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@/unarchive", groupNo, shortId];
    return [[WKAPIClient sharedClient] POST:path parameters:@{}];
}

- (AnyPromise *)deleteThread:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@", groupNo, shortId];
    return [[WKAPIClient sharedClient] DELETE:path parameters:@{}];
}

- (AnyPromise *)getThreadMembers:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@/members", groupNo, shortId];
    return [[WKAPIClient sharedClient] GET:path parameters:@{}];
}

@end
