//
//  WKChannelHistorySearchVM.h
//  WuKongBase
//
//  搜索逻辑（关键词 / tab / 筛选 / 分页 / 取消旧请求）。视图无关。
//

#import <Foundation/Foundation.h>
#import "WKChannelHistorySearchModels.h"

@class WKChannel;
@class WKChannelHistorySearchVM;

NS_ASSUME_NONNULL_BEGIN

@protocol WKChannelHistorySearchVMDelegate <NSObject>

/// 通用状态变化：items / loading / error / cursor 任意一项发生变化时调用。
/// UI 负责按需 reload。
- (void)channelHistorySearchVMDidChangeState:(WKChannelHistorySearchVM *)vm;

@optional
/// 关键词超过 64 runes，已被截断。UI 弹一次 toast 提示。
- (void)channelHistorySearchVMKeywordExceedLimit:(WKChannelHistorySearchVM *)vm;

@end

@interface WKChannelHistorySearchVM : NSObject

- (instancetype)initWithChannel:(WKChannel *)channel;

@property (nonatomic, weak, nullable) id<WKChannelHistorySearchVMDelegate> delegate;
@property (nonatomic, strong, readonly) WKChannel *channel;

@property (nonatomic, assign, readonly) WKChannelHistorySearchTab tab;
@property (nonatomic, copy, readonly) NSString *keyword;
@property (nonatomic, copy, readonly) WKChannelHistorySearchFilter *filter;

@property (nonatomic, copy, readonly) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign, readonly) BOOL hasMore;
@property (nonatomic, copy, readonly, nullable) NSString *nextCursor;

@property (nonatomic, assign, readonly) BOOL isLoadingFirstPage;
@property (nonatomic, assign, readonly) BOOL isLoadingNextPage;

@property (nonatomic, copy, readonly, nullable) NSError *firstPageError;
@property (nonatomic, copy, readonly, nullable) NSError *nextPageError;

/// 是否有过一次"已发起请求"的搜索（用于区分 emptyHint vs noResults）。
@property (nonatomic, assign, readonly) BOOL queryStarted;

/// 当前 keyword/filter 组合是否允许发请求（与 web shouldRunSearch 一致）。
@property (nonatomic, assign, readonly) BOOL shouldRunSearch;

#pragma mark 用户操作入口

/// 切换 tab：自动 reset cursor + 触发首屏拉取（若 shouldRunSearch）。
- (void)setTab:(WKChannelHistorySearchTab)tab;

/// 应用 keyword（含 64 runes 截断 + 超限通知 delegate）。
/// 不做防抖 — UI 层先用 perform 防抖再调本方法。
- (void)applyKeyword:(nullable NSString *)keyword;

/// 应用筛选条件。会触发一次首屏刷新。
- (void)applyFilter:(nullable WKChannelHistorySearchFilter *)filter;

/// 首屏刷新（reset cursor）。
- (void)refresh;

/// 加载下一页。无 nextCursor 或 hasMore == NO 时直接返回。
- (void)loadMore;

/// 取消所有飞行中请求（页面离开时调用）。
- (void)cancelInFlight;

@end

NS_ASSUME_NONNULL_END
