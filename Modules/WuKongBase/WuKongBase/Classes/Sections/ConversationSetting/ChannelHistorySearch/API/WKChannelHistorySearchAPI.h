//
//  WKChannelHistorySearchAPI.h
//  WuKongBase
//
//  统一调用 messages/_search_all / _search / _search_media / _search_files。
//  与 web 端 packages/dmworkbase/src/Components/ChannelSearch/apiAdapter.ts 同口径。
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import "WKChannelHistorySearchModels.h"

@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

extern NSInteger const WKChannelHistorySearchDefaultPageSize;

@interface WKChannelHistorySearchAPI : NSObject

/// 单次搜索请求。返回 promise resolve(WKChannelHistorySearchPage*)。
/// keyword 调用方应已经过 truncate；filter 可为 nil。
+ (AnyPromise *)searchWithTab:(WKChannelHistorySearchTab)tab
                      channel:(WKChannel *)channel
                      keyword:(nullable NSString *)keyword
                       filter:(nullable WKChannelHistorySearchFilter *)filter
                       cursor:(nullable NSString *)cursor
                     pageSize:(NSInteger)pageSize;

/// 是否应该发起请求（与 web shouldRunSearch 同口径）：
///   - 全部 / 聊天记录 tab：keyword 非空，或有发送人/日期筛选
///   - 图片视频 / 文件 tab：始终允许
+ (BOOL)shouldRunSearchForTab:(WKChannelHistorySearchTab)tab
                      keyword:(nullable NSString *)keyword
                    hasFilter:(BOOL)hasEffectiveFilter;

/// 当前 tab 是否会把 keyword 传给服务端（false 表示发送时会丢弃 keyword）。
/// 用于 UI 上对图片视频 tab 显示「图片和视频暂不支持按关键词搜索，可按发送人或日期查找」。
+ (BOOL)keywordSupportedForTab:(WKChannelHistorySearchTab)tab;

@end

NS_ASSUME_NONNULL_END
