//
//  WKGlobalMsgGroupsVM.m
//  WuKongBase
//

#import "WKGlobalMsgGroupsVM.h"
#import "WKGlobalSearchV2API.h"
#import "WKGlobalSearchError.h"
#import "WKChannelHistorySearchKeywordUtil.h"

@interface WKGlobalMsgGroupsVM ()
@property (nonatomic, copy, readwrite) NSString *keyword;
@property (nonatomic, copy, readwrite) WKChannelHistorySearchFilter *filter;
@property (nonatomic, copy, readwrite) NSArray<WKGlobalSearchGroupBucket *> *buckets;
@property (nonatomic, assign, readwrite) NSInteger totalGroups;
@property (nonatomic, assign, readwrite) BOOL totalGroupsApprox;
@property (nonatomic, assign, readwrite) BOOL hasMore;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, copy, readwrite, nullable) NSError *error;
@property (nonatomic, assign, readwrite) BOOL queryStarted;

/// 递增序号：既作为请求内 sequence 传给后端，也作本地过期判定。
@property (nonatomic, assign) NSInteger sequenceCounter;
@property (nonatomic, assign) NSInteger activeSequence; // 0 = 无活跃请求
@end

@implementation WKGlobalMsgGroupsVM

- (instancetype)init {
    self = [super init];
    if (self) {
        _keyword = @"";
        _filter = [WKChannelHistorySearchFilter new];
        _buckets = @[];
        _totalGroupsApprox = YES;
    }
    return self;
}

- (BOOL)shouldRunSearch {
    return [WKGlobalSearchV2API shouldRunGroupsSearchWithKeyword:self.keyword filter:self.filter];
}

- (void)applyKeyword:(nullable NSString *)keyword {
    BOOL truncated = NO;
    NSString *cleaned = [WKChannelHistorySearchKeywordUtil truncateToDefault:keyword ?: @"" didTruncate:&truncated];
    if (truncated && [self.delegate respondsToSelector:@selector(globalMsgGroupsVMKeywordExceedLimit:)]) {
        [self.delegate globalMsgGroupsVMKeywordExceedLimit:self];
    }
    if ([cleaned isEqualToString:self.keyword]) return;
    self.keyword = cleaned;
    [self refresh];
}

- (void)applyFilter:(nullable WKChannelHistorySearchFilter *)filter {
    self.filter = filter ? [filter copy] : [WKChannelHistorySearchFilter new];
    [self refresh];
}

- (void)refresh {
    [self cancelInFlight];
    self.buckets = @[];
    self.totalGroups = 0;
    self.hasMore = NO;
    self.error = nil;

    if (![self shouldRunSearch]) {
        self.isLoading = NO;
        self.queryStarted = NO;
        [self notifyState];
        return;
    }

    self.queryStarted = YES;
    self.isLoading = YES;
    [self notifyState];

    self.sequenceCounter += 1;
    NSInteger seq = self.sequenceCounter;
    self.activeSequence = seq;

    __weak typeof(self) ws = self;
    [WKGlobalSearchV2API searchGlobalGroupsWithKeyword:self.keyword filter:self.filter sequence:seq]
        .then(^(WKGlobalSearchGroupsResult *result) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            // 双匹配：本地 activeSequence + 后端回带 sequence（后端回带 0 时只看本地）。
            if (ss.activeSequence != seq) return;
            if (result.sequence != 0 && result.sequence != seq) return;
            ss.activeSequence = 0;
            ss.isLoading = NO;
            ss.buckets = result.buckets ?: @[];
            ss.totalGroups = result.totalGroups;
            ss.totalGroupsApprox = result.totalGroupsApprox;
            ss.hasMore = result.hasMore;
            ss.error = nil;
            [ss notifyState];
        })
        .catch(^(NSError *error) {
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (ss.activeSequence != seq) return;
            ss.activeSequence = 0;
            ss.isLoading = NO;
            if ([WKGlobalSearchError shouldFallbackToLocal:error]) {
                if ([ss.delegate respondsToSelector:@selector(globalMsgGroupsVM:shouldFallbackToLocalWithError:)]) {
                    [ss.delegate globalMsgGroupsVM:ss shouldFallbackToLocalWithError:error];
                }
                return;
            }
            ss.error = error;
            [ss notifyState];
        });
}

- (void)cancelInFlight {
    self.activeSequence = 0;
    self.isLoading = NO;
}

- (void)notifyState {
    if ([self.delegate respondsToSelector:@selector(globalMsgGroupsVMDidChangeState:)]) {
        [self.delegate globalMsgGroupsVMDidChangeState:self];
    }
}

@end
