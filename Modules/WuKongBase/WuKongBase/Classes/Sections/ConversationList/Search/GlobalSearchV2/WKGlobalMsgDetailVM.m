//
//  WKGlobalMsgDetailVM.m
//  WuKongBase
//

#import "WKGlobalMsgDetailVM.h"
#import "WKGlobalSearchV2API.h"

@interface WKGlobalMsgDetailVM ()
@property (nonatomic, strong, readwrite) WKGlobalSearchGroupBucket *bucket;
@property (nonatomic, copy, readwrite) NSString *keyword;
@property (nonatomic, copy) WKChannelHistorySearchFilter *filter;

@property (nonatomic, copy, readwrite) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign, readwrite) BOOL hasMore;
@property (nonatomic, copy, readwrite, nullable) NSString *nextCursor;
@property (nonatomic, assign, readwrite) BOOL isLoadingFirstPage;
@property (nonatomic, assign, readwrite) BOOL isLoadingNextPage;
@property (nonatomic, copy, readwrite, nullable) NSError *firstPageError;
@property (nonatomic, copy, readwrite, nullable) NSError *nextPageError;
@property (nonatomic, assign, readwrite) BOOL queryStarted;

@property (nonatomic, assign) NSInteger reqIdCounter;
@property (nonatomic, assign) NSInteger firstPageReqId;
@property (nonatomic, assign) NSInteger nextPageReqId;
@end

@implementation WKGlobalMsgDetailVM

- (instancetype)initWithBucket:(WKGlobalSearchGroupBucket *)bucket
                       keyword:(nullable NSString *)keyword
                        filter:(nullable WKChannelHistorySearchFilter *)filter {
    self = [super init];
    if (self) {
        _bucket = bucket;
        _keyword = keyword ?: @"";
        _filter = filter ? [filter copy] : [WKChannelHistorySearchFilter new];
        _items = @[];
    }
    return self;
}

- (void)refresh {
    [self cancelInFlight];
    self.items = @[];
    self.hasMore = NO;
    self.nextCursor = nil;
    self.firstPageError = nil;
    self.nextPageError = nil;
    self.queryStarted = YES;
    self.isLoadingFirstPage = YES;
    [self notifyState];

    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    self.firstPageReqId = reqId;

    __weak typeof(self) ws = self;
    [WKGlobalSearchV2API searchGlobalMessagesForBucket:self.bucket keyword:self.keyword filter:self.filter cursor:nil]
        .then(^(WKChannelHistorySearchPage *page) {
            __strong typeof(ws) ss = ws;
            if (!ss || ss.firstPageReqId != reqId) return;
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
            if (!ss || ss.firstPageReqId != reqId) return;
            ss.firstPageReqId = 0;
            ss.isLoadingFirstPage = NO;
            ss.firstPageError = error;
            [ss notifyState];
        });
}

- (void)loadMore {
    if (self.isLoadingNextPage || !self.hasMore) return;
    if (self.nextCursor.length == 0) return;
    if (self.isLoadingFirstPage) return;

    self.isLoadingNextPage = YES;
    self.nextPageError = nil;
    [self notifyState];

    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    self.nextPageReqId = reqId;
    NSString *cursor = self.nextCursor;

    __weak typeof(self) ws = self;
    [WKGlobalSearchV2API searchGlobalMessagesForBucket:self.bucket keyword:self.keyword filter:self.filter cursor:cursor]
        .then(^(WKChannelHistorySearchPage *page) {
            __strong typeof(ws) ss = ws;
            if (!ss || ss.nextPageReqId != reqId) return;
            ss.nextPageReqId = 0;
            ss.isLoadingNextPage = NO;
            BOOL sameCursor = (page.nextCursor.length > 0) && [page.nextCursor isEqualToString:cursor];
            NSArray *appended = page.items ?: @[];
            if (appended.count > 0) ss.items = [ss.items arrayByAddingObjectsFromArray:appended];
            if (sameCursor) { ss.hasMore = NO; ss.nextCursor = nil; }
            else { ss.hasMore = page.hasMore; ss.nextCursor = page.nextCursor; }
            ss.nextPageError = nil;
            [ss notifyState];
        })
        .catch(^(NSError *error) {
            __strong typeof(ws) ss = ws;
            if (!ss || ss.nextPageReqId != reqId) return;
            ss.nextPageReqId = 0;
            ss.isLoadingNextPage = NO;
            ss.nextPageError = error;
            [ss notifyState];
        });
}

- (void)cancelInFlight {
    self.firstPageReqId = 0;
    self.nextPageReqId = 0;
    self.isLoadingFirstPage = NO;
    self.isLoadingNextPage = NO;
}

- (void)notifyState {
    if ([self.delegate respondsToSelector:@selector(globalMsgDetailVMDidChangeState:)]) {
        [self.delegate globalMsgDetailVMDidChangeState:self];
    }
}

@end
