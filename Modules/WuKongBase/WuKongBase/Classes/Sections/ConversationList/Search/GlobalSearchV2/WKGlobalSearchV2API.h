//
//  WKGlobalSearchV2API.h
//  WuKongBase
//
//  全局搜索服务端 API（对齐 web）。四条路径：
//   L1 群/子区/私聊聚合总览   POST messages/_search_global_groups   → WKGlobalSearchGroupsResult
//   L2 某会话内消息（drill）    POST messages/_search_global_messages → WKChannelHistorySearchPage
//   文件                      POST messages/_search_global_files    → WKChannelHistorySearchPage
//   联系人+群组               POST search/global?space_id=          → 原始 {friends,groups} dict
//
//  通用：header token 由 publicHeaderBLock 注入；_search_global_* 额外注入 X-Space-Id；
//  错误 wire HTTP 恒 400，语义见 WKGlobalSearchError。
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import "WKChannelHistorySearchModels.h"
#import "WKGlobalSearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchV2API : NSObject

/// L1 聚合总览。resolve WKGlobalSearchGroupsResult。
+ (AnyPromise *)searchGlobalGroupsWithKeyword:(nullable NSString *)keyword
                                       filter:(nullable WKChannelHistorySearchFilter *)filter
                                     sequence:(NSInteger)sequence;

/// L2 某会话（群/子区/私聊）内消息。resolve WKChannelHistorySearchPage。
+ (AnyPromise *)searchGlobalMessagesForBucket:(WKGlobalSearchGroupBucket *)bucket
                                      keyword:(nullable NSString *)keyword
                                       filter:(nullable WKChannelHistorySearchFilter *)filter
                                       cursor:(nullable NSString *)cursor;

/// 全局文件。resolve WKChannelHistorySearchPage（file items）。
+ (AnyPromise *)searchGlobalFilesWithKeyword:(nullable NSString *)keyword
                                      filter:(nullable WKChannelHistorySearchFilter *)filter
                                      cursor:(nullable NSString *)cursor;

/// 联系人 + 群组（legacy 聚合端点）。resolve 原始 {friends:[...],groups:[...],messages:[...]}。
+ (AnyPromise *)searchContactsAndGroupsWithKeyword:(nullable NSString *)keyword
                                              page:(NSInteger)page;

/// L1 触发门（与服务端一致）：keyword 或 sender/成员/指定频道 至少一项非空。
/// sent_at / content_types 单独存在不触发。
+ (BOOL)shouldRunGroupsSearchWithKeyword:(nullable NSString *)keyword
                                  filter:(nullable WKChannelHistorySearchFilter *)filter;

@end

NS_ASSUME_NONNULL_END
