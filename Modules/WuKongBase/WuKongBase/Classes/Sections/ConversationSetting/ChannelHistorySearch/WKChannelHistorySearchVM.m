//
//  WKChannelHistorySearchVM.m
//

#import "WKChannelHistorySearchVM.h"
#import "WKChannelHistorySearchAPI.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKChannelHistorySearchVM ()
@property (nonatomic, strong, readwrite) WKChannel *channel;

@property (nonatomic, assign, readwrite) WKChannelHistorySearchTab tab;
@property (nonatomic, copy, readwrite) NSString *keyword;
@property (nonatomic, copy, readwrite) WKChannelHistorySearchFilter *filter;

@property (nonatomic, copy, readwrite) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign, readwrite) BOOL hasMore;
@property (nonatomic, copy, readwrite, nullable) NSString *nextCursor;

@property (nonatomic, assign, readwrite) BOOL isLoadingFirstPage;
@property (nonatomic, assign, readwrite) BOOL isLoadingNextPage;
@property (nonatomic, copy, readwrite, nullable) NSError *firstPageError;
@property (nonatomic, copy, readwrite, nullable) NSError *nextPageError;
@property (nonatomic, assign, readwrite) BOOL queryStarted;

/// 单调递增请求号。每次发起请求都自增；回包到达后比对，过期回包丢弃。
/// 这种方案比 NSURLSessionDataTask cancel 简单 — 不需要存 task 引用，也能避免乱序覆盖。
@property (nonatomic, assign) NSInteger reqIdCounter;
/// 当前首屏请求的 reqId（0 表示无活跃首屏请求）。
@property (nonatomic, assign) NSInteger firstPageReqId;
/// 当前下一页请求的 reqId。
@property (nonatomic, assign) NSInteger nextPageReqId;

@end

@implementation WKChannelHistorySearchVM

- (instancetype)initWithChannel:(WKChannel *)channel {
    self = [super init];
    if (self) {
        _channel = channel;
        _tab = WKChannelHistorySearchTabAll;
        _keyword = @"";
        _filter = [WKChannelHistorySearchFilter new];
        _items = @[];
        _hasMore = NO;
        _nextCursor = nil;
        _isLoadingFirstPage = NO;
        _isLoadingNextPage = NO;
        _queryStarted = NO;
    }
    return self;
}

#pragma mark - Public

- (BOOL)shouldRunSearch {
    return [WKChannelHistorySearchAPI shouldRunSearchForTab:self.tab
                                                     keyword:self.keyword
                                                   hasFilter:self.filter.hasEffectiveFilters];
}

- (void)setTab:(WKChannelHistorySearchTab)tab {
    if (_tab == tab) return;
    _tab = tab;
    [self refresh];
}

- (void)applyKeyword:(NSString *)keyword {
    BOOL truncated = NO;
    NSString *cleaned = [WKChannelHistorySearchKeywordUtil truncateToDefault:keyword ?: @""
                                                                  didTruncate:&truncated];
    if ([cleaned isEqualToString:self.keyword]) {
        if (truncated) {
            if ([self.delegate respondsToSelector:@selector(channelHistorySearchVMKeywordExceedLimit:)]) {
                [self.delegate channelHistorySearchVMKeywordExceedLimit:self];
            }
        }
        return;
    }
    self.keyword = cleaned;
    if (truncated) {
        if ([self.delegate respondsToSelector:@selector(channelHistorySearchVMKeywordExceedLimit:)]) {
            [self.delegate channelHistorySearchVMKeywordExceedLimit:self];
        }
    }
    [self refresh];
}

- (void)applyFilter:(WKChannelHistorySearchFilter *)filter {
    self.filter = filter ? [filter copy] : [WKChannelHistorySearchFilter new];
    [self refresh];
}

- (void)refresh {
    [self cancelInFlight];
    self.items = @[];
    self.hasMore = NO;
    self.nextCursor = nil;
    self.firstPageError = nil;
    self.nextPageError = nil;

    if (![self shouldRunSearch]) {
        self.isLoadingFirstPage = NO;
        self.queryStarted = NO;
        [self notifyState];
        return;
    }

    self.queryStarted = YES;
    self.isLoadingFirstPage = YES;
    [self notifyState];

    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    self.firstPageReqId = reqId;

    __weak typeof(self) ws = self;
    [WKChannelHistorySearchAPI searchWithTab:self.tab
                                      channel:self.channel
                                      keyword:self.keyword
                                       filter:self.filter
                                       cursor:nil
                                     pageSize:WKChannelHistorySearchDefaultPageSize]
        .then(^(WKChannelHistorySearchPage *page) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (ss.firstPageReqId != reqId) return; // 过期
            ss.firstPageReqId = 0;
            ss.isLoadingFirstPage = NO;
            ss.items = page.items ?: @[];
            ss.hasMore = page.hasMore;
            ss.nextCursor = page.nextCursor;
            ss.firstPageError = nil;
            [ss notifyState];
        })
        .catch(^(NSError *error) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (ss.firstPageReqId != reqId) return;
            ss.firstPageReqId = 0;
            ss.isLoadingFirstPage = NO;
            ss.firstPageError = error;
            [ss notifyState];
        });
}

- (void)loadMore {
    if (self.isLoadingNextPage) return;
    if (!self.hasMore) return;
    if (self.nextCursor.length == 0) return; // 与 web 同款守卫：无 cursor 视为终止
    if (self.isLoadingFirstPage) return;

    self.isLoadingNextPage = YES;
    self.nextPageError = nil;
    [self notifyState];

    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    self.nextPageReqId = reqId;
    NSString *cursor = self.nextCursor;

    __weak typeof(self) ws = self;
    [WKChannelHistorySearchAPI searchWithTab:self.tab
                                      channel:self.channel
                                      keyword:self.keyword
                                       filter:self.filter
                                       cursor:cursor
                                     pageSize:WKChannelHistorySearchDefaultPageSize]
        .then(^(WKChannelHistorySearchPage *page) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (ss.nextPageReqId != reqId) return;
            ss.nextPageReqId = 0;
            ss.isLoadingNextPage = NO;
            // 守卫：next_cursor 不变 / 相同 → 视为终止，避免死循环（与 web 同口径）
            BOOL sameCursor = (page.nextCursor.length > 0) && [page.nextCursor isEqualToString:cursor];
            NSArray *appended = page.items ?: @[];
            if (appended.count > 0) {
                ss.items = [ss.items arrayByAddingObjectsFromArray:appended];
            }
            if (sameCursor) {
                ss.hasMore = NO;
                ss.nextCursor = nil;
            } else {
                ss.hasMore = page.hasMore;
                ss.nextCursor = page.nextCursor;
            }
            ss.nextPageError = nil;
            [ss notifyState];
        })
        .catch(^(NSError *error) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (ss.nextPageReqId != reqId) return;
            ss.nextPageReqId = 0;
            ss.isLoadingNextPage = NO;
            ss.nextPageError = error;
            [ss notifyState];
        });
}

- (void)cancelInFlight {
    // 通过推进 reqId 让所有飞行回包过期。底层 task 仍会跑完但回调被丢弃。
    self.firstPageReqId = 0;
    self.nextPageReqId = 0;
    self.isLoadingFirstPage = NO;
    self.isLoadingNextPage = NO;
}

#pragma mark - Helpers

- (void)notifyState {
    if ([self.delegate respondsToSelector:@selector(channelHistorySearchVMDidChangeState:)]) {
        [self.delegate channelHistorySearchVMDidChangeState:self];
    }
}

@end
