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

- (AnyPromise *)listAllThreads:(NSString *)groupNo maxPages:(NSInteger)maxPages {
    if (maxPages <= 0) maxPages = 10;
    return [self listAllThreads:groupNo pageIndex:1 maxPages:maxPages accumulated:@[]];
}

- (AnyPromise *)listAllThreadsWithCompleteness:(NSString *)groupNo maxPages:(NSInteger)maxPages {
    if (maxPages <= 0) maxPages = 10;
    return [self listAllThreadsRich:groupNo pageIndex:1 maxPages:maxPages accumulated:@[]];
}

// 递归翻页：拿到 page 后若 accumulated.count < server count 且未到 maxPages，继续下一页。
// 用 accumulated 串起来，避免在外层维护可变状态。
- (AnyPromise *)listAllThreads:(NSString *)groupNo pageIndex:(NSInteger)pageIndex maxPages:(NSInteger)maxPages accumulated:(NSArray<WKThreadModel *> *)accumulated {
    return [self listThreads:groupNo pageIndex:pageIndex pageSize:100].then(^(NSDictionary *result) {
        NSInteger totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *page = result[@"list"] ?: @[];
        NSArray<WKThreadModel *> *combined = [accumulated arrayByAddingObjectsFromArray:page];
        BOOL done = (combined.count >= totalCount) || (page.count == 0) || (pageIndex >= maxPages);
        if (done) return (id)combined;
        return (id)[self listAllThreads:groupNo pageIndex:pageIndex + 1 maxPages:maxPages accumulated:combined];
    });
}

// 带 completeness 信号的递归翻页：only `complete=NO` when 因 maxPages 截断
// （combined.count < totalCount 且 pageIndex 已到顶）。其它两个 done 分支
// （combined ≥ total / 空页）都意味着拿全了 → complete=YES。
- (AnyPromise *)listAllThreadsRich:(NSString *)groupNo pageIndex:(NSInteger)pageIndex maxPages:(NSInteger)maxPages accumulated:(NSArray<WKThreadModel *> *)accumulated {
    return [self listThreads:groupNo pageIndex:pageIndex pageSize:100].then(^(NSDictionary *result) {
        NSInteger totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *page = result[@"list"] ?: @[];
        NSArray<WKThreadModel *> *combined = [accumulated arrayByAddingObjectsFromArray:page];
        BOOL exhaustedServer = (combined.count >= totalCount) || (page.count == 0);
        BOOL hitMaxPages = (pageIndex >= maxPages);
        if (exhaustedServer || hitMaxPages) {
            BOOL complete = exhaustedServer; // 走到上限但还没拿全 → 截断
            return (id)@{@"threads": combined, @"complete": @(complete)};
        }
        return (id)[self listAllThreadsRich:groupNo pageIndex:pageIndex + 1 maxPages:maxPages accumulated:combined];
    });
}

- (AnyPromise *)getThread:(NSString *)groupNo shortId:(NSString *)shortId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@", groupNo, shortId];
    return [[WKAPIClient sharedClient] GET:path parameters:@{}].then(^(NSDictionary *result) {
        return [WKThreadModel fromDict:result];
    });
}

- (AnyPromise *)updateThread:(NSString *)groupNo shortId:(NSString *)shortId name:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"groups/%@/threads/%@", groupNo, shortId];
    return [[WKAPIClient sharedClient] PUT:path parameters:@{@"name": name ?: @""}];
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
