//
//  WKGlobalMsgGroupsVM.h
//  WuKongBase
//
//  全局搜索「聊天记录」tab 的 L1 聚合总览逻辑。视图无关。
//  一次 POST _search_global_groups → 命中的群/子区/私聊桶（按 latest_at 倒序）。
//  无逐条翻页；用递增 sequence 丢弃过期响应（与 web useGlobalChatSearch 同口径）。
//

#import <Foundation/Foundation.h>
#import "WKGlobalSearchModels.h"
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@class WKGlobalMsgGroupsVM;

@protocol WKGlobalMsgGroupsVMDelegate <NSObject>
- (void)globalMsgGroupsVMDidChangeState:(WKGlobalMsgGroupsVM *)vm;
@optional
- (void)globalMsgGroupsVMKeywordExceedLimit:(WKGlobalMsgGroupsVM *)vm;
/// SEARCH_DISABLED：请求方应运行时回落到本地搜索。
- (void)globalMsgGroupsVM:(WKGlobalMsgGroupsVM *)vm shouldFallbackToLocalWithError:(NSError *)error;
@end

@interface WKGlobalMsgGroupsVM : NSObject

@property (nonatomic, weak, nullable) id<WKGlobalMsgGroupsVMDelegate> delegate;

@property (nonatomic, copy, readonly) NSString *keyword;
@property (nonatomic, copy, readonly) WKChannelHistorySearchFilter *filter;

@property (nonatomic, copy, readonly) NSArray<WKGlobalSearchGroupBucket *> *buckets;
@property (nonatomic, assign, readonly) NSInteger totalGroups;
@property (nonatomic, assign, readonly) BOOL totalGroupsApprox;
/// 命中群超桶上限（仅返回最活跃前 N），UI 提示「缩小范围」。
@property (nonatomic, assign, readonly) BOOL hasMore;

@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, copy, readonly, nullable) NSError *error;
@property (nonatomic, assign, readonly) BOOL queryStarted;
@property (nonatomic, assign, readonly) BOOL shouldRunSearch;

- (void)applyKeyword:(nullable NSString *)keyword;
- (void)applyFilter:(nullable WKChannelHistorySearchFilter *)filter;
- (void)refresh;
- (void)cancelInFlight;

@end

NS_ASSUME_NONNULL_END
