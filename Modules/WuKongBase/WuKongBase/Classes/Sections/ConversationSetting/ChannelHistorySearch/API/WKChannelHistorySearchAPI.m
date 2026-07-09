//
//  WKChannelHistorySearchAPI.m
//

#import "WKChannelHistorySearchAPI.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import "WKAPIClient.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

NSInteger const WKChannelHistorySearchDefaultPageSize = 20;

@implementation WKChannelHistorySearchAPI

+ (NSString *)endpointForTab:(WKChannelHistorySearchTab)tab {
    switch (tab) {
        case WKChannelHistorySearchTabAll:     return @"messages/_search_all";
        case WKChannelHistorySearchTabMessage: return @"messages/_search";
        case WKChannelHistorySearchTabMedia:   return @"messages/_search_media";
        case WKChannelHistorySearchTabFile:    return @"messages/_search_files";
    }
}

+ (BOOL)keywordSupportedForTab:(WKChannelHistorySearchTab)tab {
    // 与 web 一致：media tab 完全不带 keyword；file tab 仅当 keyword 非空时带。
    // "keywordSupported" 这里语义是「该 tab 是否把 keyword 作为搜索条件」。
    // 媒体 tab 视为不支持关键词检索（UI 据此提示）。
    return tab != WKChannelHistorySearchTabMedia;
}

+ (BOOL)shouldRunSearchForTab:(WKChannelHistorySearchTab)tab
                      keyword:(NSString *)keyword
                    hasFilter:(BOOL)hasEffectiveFilter {
    if (tab == WKChannelHistorySearchTabMedia || tab == WKChannelHistorySearchTabFile) return YES;
    NSString *trimmed = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) return YES;
    return hasEffectiveFilter;
}

+ (NSString *)sortStringFromEnum:(WKChannelHistorySearchSort)sort {
    return sort == WKChannelHistorySearchSortTimeAsc ? @"time_asc" : @"time_desc";
}

+ (AnyPromise *)searchWithTab:(WKChannelHistorySearchTab)tab
                      channel:(WKChannel *)channel
                      keyword:(NSString *)keyword
                       filter:(WKChannelHistorySearchFilter *)filter
                       cursor:(NSString *)cursor
                     pageSize:(NSInteger)pageSize {
    NSString *endpoint = [self endpointForTab:tab];
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"channel_id"] = channel.channelId ?: @"";
    body[@"channel_type"] = @(channel.channelType);
    NSDictionary *filterDict = filter ? [filter toApiDict] : @{};
    body[@"filters"] = filterDict;
    body[@"sort"] = [self sortStringFromEnum:filter ? filter.sort : WKChannelHistorySearchSortTimeDesc];
    body[@"page_size"] = @(pageSize > 0 ? pageSize : WKChannelHistorySearchDefaultPageSize);
    body[@"cursor"] = cursor.length > 0 ? cursor : @"";

    // keyword 规则：与 web apiAdapter.toRequestBody 一致
    NSString *trimmed = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    NSString *finalKw = [WKChannelHistorySearchKeywordUtil truncateToDefault:trimmed didTruncate:NULL];
    if (tab == WKChannelHistorySearchTabAll || tab == WKChannelHistorySearchTabMessage) {
        body[@"keyword"] = finalKw;
    } else if (tab == WKChannelHistorySearchTabFile && finalKw.length > 0) {
        body[@"keyword"] = finalKw;
    }
    // media tab 不传 keyword

    NSString *cid = channel.channelId;
    NSInteger ct = channel.channelType;
    return [WKAPIClient.sharedClient POST:endpoint parameters:body].then(^id(id result) {
        return [WKChannelHistorySearchPage pageFromResponse:result tab:tab channelId:cid channelType:ct];
    });
}

@end
