//
//  WKGlobalSearchModels.m
//  WuKongBase
//

#import "WKGlobalSearchModels.h"

#pragma mark - 解析助手

static NSString * _Nullable WKGS_String(id _Nullable v) {
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return nil;
}

static NSInteger WKGS_Int(id _Nullable v) {
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v integerValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString *)v integerValue];
    return 0;
}

static BOOL WKGS_Bool(id _Nullable v) {
    if ([v respondsToSelector:@selector(boolValue)]) return [v boolValue];
    return NO;
}

static NSArray * _Nullable WKGS_Array(id _Nullable v) {
    return [v isKindOfClass:[NSArray class]] ? (NSArray *)v : nil;
}

static NSDictionary * _Nullable WKGS_Dict(id _Nullable v) {
    return [v isKindOfClass:[NSDictionary class]] ? (NSDictionary *)v : nil;
}

/// latest_at 通常是 ISO8601（可能带时区/毫秒），兼容纯数字（秒/毫秒）。
static NSTimeInterval WKGS_ParseTimestamp(id _Nullable v) {
    if (!v || v == [NSNull null]) return 0;
    if ([v isKindOfClass:[NSNumber class]]) {
        double n = [(NSNumber *)v doubleValue];
        return n >= 1e12 ? n / 1000.0 : n;
    }
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)v;
        if (s.length == 0) return 0;
        BOOL allDigits = YES;
        for (NSUInteger i = 0; i < s.length; i++) {
            unichar c = [s characterAtIndex:i];
            if (!((c >= '0' && c <= '9') || c == '.')) { allDigits = NO; break; }
        }
        if (allDigits) {
            double n = [s doubleValue];
            return n >= 1e12 ? n / 1000.0 : n;
        }
        static NSISO8601DateFormatter *fmt = nil;
        static NSISO8601DateFormatter *fmt2 = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            fmt = [NSISO8601DateFormatter new];
            fmt.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
            fmt2 = [NSISO8601DateFormatter new];
            fmt2.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        });
        NSDate *d = [fmt dateFromString:s] ?: [fmt2 dateFromString:s];
        return d ? d.timeIntervalSince1970 : 0;
    }
    return 0;
}

#pragma mark - Bucket

@implementation WKGlobalSearchGroupBucket

+ (nullable instancetype)bucketFromDict:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    WKGlobalSearchGroupBucket *b = [WKGlobalSearchGroupBucket new];
    b.channelId = WKGS_String(dict[@"channel_id"]);
    b.channelType = WKGS_Int(dict[@"channel_type"]);
    b.parentGroupNo = WKGS_String(dict[@"parent_group_no"]);
    b.groupName = WKGS_String(dict[@"group_name"]);
    b.threadId = WKGS_String(dict[@"thread_id"]);
    b.threadName = WKGS_String(dict[@"thread_name"]);
    b.matchCount = WKGS_Int(dict[@"match_count"]);
    b.matchCountApprox = dict[@"match_count_approx"] ? WKGS_Bool(dict[@"match_count_approx"]) : YES;
    b.latestAtRaw = WKGS_String(dict[@"latest_at"]);
    b.latestAt = WKGS_ParseTimestamp(dict[@"latest_at"]);

    NSArray *rawPreview = WKGS_Array(dict[@"preview"]);
    NSMutableArray<WKChannelHistorySearchItem *> *items = [NSMutableArray array];
    for (NSDictionary *hit in rawPreview) {
        if (![hit isKindOfClass:[NSDictionary class]]) continue;
        // preview[] 元素复用 MessageHit 结构。既可能是裸 message dict，也可能带 result_type 信封。
        WKChannelHistorySearchItem *it = nil;
        if (hit[@"result_type"]) {
            it = [WKChannelHistorySearchItem combinedItemFromDict:hit
                                                fallbackChannelId:b.channelId
                                              fallbackChannelType:b.channelType];
        } else {
            it = [WKChannelHistorySearchItem messageItemFromDict:hit
                                               fallbackChannelId:b.channelId
                                             fallbackChannelType:b.channelType];
        }
        if (it) [items addObject:it];
    }
    b.preview = items;
    return b;
}

- (BOOL)isThread { return self.channelType == 5; }
- (BOOL)isDM { return self.channelType == 1; }

- (NSString *)displayTitle {
    if (self.isThread) {
        NSString *g = self.groupName.length > 0 ? self.groupName : @"";
        NSString *t = self.threadName.length > 0 ? self.threadName : @"子区";
        if (g.length > 0) return [NSString stringWithFormat:@"%@ · %@", g, t];
        return t;
    }
    if (self.groupName.length > 0) return self.groupName;
    return self.channelId ?: @"";
}

- (NSDictionary *)l2ChannelIdentity {
    // 群(2)→自动展开群+子区；子区(5)→只搜该子区；私聊(1)→与对端 DM。
    return @{ @"channel_id": self.channelId ?: @"",
              @"channel_type": @(self.channelType) };
}

@end

#pragma mark - Result

@implementation WKGlobalSearchGroupsResult

+ (instancetype)resultFromResponse:(id)response {
    WKGlobalSearchGroupsResult *r = [WKGlobalSearchGroupsResult new];
    r.buckets = @[];
    r.totalGroups = 0;
    r.totalGroupsApprox = YES;
    r.hasMore = NO;
    r.sequence = 0;

    NSDictionary *root = WKGS_Dict(response);
    if (!root) return r;

    NSDictionary *data = WKGS_Dict(root[@"data"]);
    if (data) {
        r.sequence = WKGS_Int(data[@"sequence"]);
        r.totalGroups = WKGS_Int(data[@"total_groups"]);
        r.totalGroupsApprox = data[@"total_groups_approx"] ? WKGS_Bool(data[@"total_groups_approx"]) : YES;
        NSArray *rawGroups = WKGS_Array(data[@"groups"]);
        NSMutableArray<WKGlobalSearchGroupBucket *> *buckets = [NSMutableArray array];
        for (NSDictionary *g in rawGroups) {
            WKGlobalSearchGroupBucket *b = [WKGlobalSearchGroupBucket bucketFromDict:g];
            if (b) [buckets addObject:b];
        }
        r.buckets = buckets;
    }

    NSDictionary *pg = WKGS_Dict(root[@"pagination"]);
    if (pg) r.hasMore = WKGS_Bool(pg[@"has_more"]);
    return r;
}

@end
