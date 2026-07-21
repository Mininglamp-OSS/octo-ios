//
//  WKGlobalSearchV2API.m
//  WuKongBase
//

#import "WKGlobalSearchV2API.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import "WKAPIClient.h"

NSInteger const WKGlobalSearchV2DefaultPageSize = 20;

@implementation WKGlobalSearchV2API

#pragma mark - 通用

/// 当前 Space id（与 legacy requestSearch: 同源）。
+ (nullable NSString *)currentSpaceId {
    NSString *sid = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    return sid.length > 0 ? sid : nil;
}

/// _search_global_* 需要的 X-Space-Id header（无 space 时返回空 dict）。
+ (NSDictionary<NSString *, NSString *> *)spaceHeaders {
    NSString *sid = [self currentSpaceId];
    return sid ? @{ @"X-Space-Id": sid } : @{};
}

/// 清洗 + 截断 keyword（64 rune，与会话内搜索/ web 同口径）。
+ (NSString *)cleanKeyword:(nullable NSString *)keyword {
    NSString *trimmed = [(keyword ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [WKChannelHistorySearchKeywordUtil truncateToDefault:trimmed didTruncate:NULL] ?: @"";
}

#pragma mark - L1 groups

+ (BOOL)shouldRunGroupsSearchWithKeyword:(nullable NSString *)keyword
                                  filter:(nullable WKChannelHistorySearchFilter *)filter {
    NSString *kw = [self cleanKeyword:keyword];
    if (kw.length > 0) return YES;
    if (filter.senderUids.count > 0) return YES;
    if (filter.memberUids.count > 0) return YES;
    if (filter.channels.count > 0) return YES;
    // 注意：channel_types / content_types / sent_at 单独存在不触发（§2.3）。
    return NO;
}

+ (AnyPromise *)searchGlobalGroupsWithKeyword:(nullable NSString *)keyword
                                       filter:(nullable WKChannelHistorySearchFilter *)filter
                                     sequence:(NSInteger)sequence {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"keyword"] = [self cleanKeyword:keyword];
    body[@"sequence"] = @(sequence);
    body[@"filters"] = filter ? [filter toApiDict] : @{};

    return [WKAPIClient.sharedClient POST:@"messages/_search_global_groups"
                              parameters:body
                                 headers:[self spaceHeaders]].then(^id(id result) {
        return [WKGlobalSearchGroupsResult resultFromResponse:result];
    });
}

#pragma mark - L2 messages

+ (AnyPromise *)searchGlobalMessagesForBucket:(WKGlobalSearchGroupBucket *)bucket
                                      keyword:(nullable NSString *)keyword
                                       filter:(nullable WKChannelHistorySearchFilter *)filter
                                       cursor:(nullable NSString *)cursor {
    NSMutableDictionary *filters = [NSMutableDictionary dictionaryWithDictionary:(filter ? [filter toApiDict] : @{})];
    if (bucket) filters[@"channel_ids"] = @[ [bucket l2ChannelIdentity] ];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"keyword"] = [self cleanKeyword:keyword];
    body[@"sort"] = (filter && filter.sort == WKChannelHistorySearchSortTimeAsc) ? @"time_asc" : @"time_desc";
    body[@"page_size"] = @(WKGlobalSearchV2DefaultPageSize);
    body[@"cursor"] = cursor.length > 0 ? cursor : @"";
    body[@"filters"] = filters;

    return [WKAPIClient.sharedClient POST:@"messages/_search_global_messages"
                              parameters:body
                                 headers:[self spaceHeaders]].then(^id(id result) {
        // data[] = SearchAllHit（result_type=message|file）扁平流 → tab=All 走 combinedItemFromDict:
        return [WKChannelHistorySearchPage pageFromResponse:result
                                                        tab:WKChannelHistorySearchTabAll
                                                  channelId:nil
                                                channelType:0];
    });
}

#pragma mark - Files

+ (AnyPromise *)searchGlobalFilesWithKeyword:(nullable NSString *)keyword
                                      filter:(nullable WKChannelHistorySearchFilter *)filter
                                      cursor:(nullable NSString *)cursor {
    NSMutableDictionary *filters = [NSMutableDictionary dictionaryWithDictionary:(filter ? [filter toApiDict] : @{})];

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    NSString *kw = [self cleanKeyword:keyword];
    if (kw.length > 0) body[@"keyword"] = kw; // 文件 tab keyword 可空（浏览态）
    body[@"page_size"] = @(WKGlobalSearchV2DefaultPageSize);
    body[@"cursor"] = cursor.length > 0 ? cursor : @"";
    body[@"filters"] = filters;

    return [WKAPIClient.sharedClient POST:@"messages/_search_global_files"
                              parameters:body
                                 headers:[self spaceHeaders]].then(^id(id result) {
        return [WKChannelHistorySearchPage pageFromResponse:result
                                                        tab:WKChannelHistorySearchTabFile
                                                  channelId:nil
                                                channelType:0];
    });
}

#pragma mark - Contacts + Groups (legacy /search/global)

+ (AnyPromise *)searchContactsAndGroupsWithKeyword:(nullable NSString *)keyword
                                              page:(NSInteger)page {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"keyword"] = [self cleanKeyword:keyword];
    body[@"page"] = @(page > 0 ? page : 1);
    body[@"limit"] = @(WKGlobalSearchV2DefaultPageSize);

    // 与 legacy requestSearch: 一致：space_id 走 URL query 参数。
    NSString *path = @"search/global";
    NSString *sid = [self currentSpaceId];
    if (sid) {
        NSString *encoded = [sid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        path = [NSString stringWithFormat:@"search/global?space_id=%@", encoded];
    }
    return [WKAPIClient.sharedClient POST:path parameters:body];
}

@end
