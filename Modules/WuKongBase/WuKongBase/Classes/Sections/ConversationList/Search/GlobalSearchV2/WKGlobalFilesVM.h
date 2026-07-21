//
//  WKGlobalFilesVM.h
//  WuKongBase
//
//  全局搜索「文件」tab 逻辑。POST _search_global_files，cursor 翻页。
//  行为与 WKChannelHistorySearchVM 一致（reqId 竞态丢弃 + cursor 守卫）。
//

#import <Foundation/Foundation.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@class WKGlobalFilesVM;

@protocol WKGlobalFilesVMDelegate <NSObject>
- (void)globalFilesVMDidChangeState:(WKGlobalFilesVM *)vm;
@optional
- (void)globalFilesVMKeywordExceedLimit:(WKGlobalFilesVM *)vm;
- (void)globalFilesVM:(WKGlobalFilesVM *)vm shouldFallbackToLocalWithError:(NSError *)error;
@end

@interface WKGlobalFilesVM : NSObject

@property (nonatomic, weak, nullable) id<WKGlobalFilesVMDelegate> delegate;

@property (nonatomic, copy, readonly) NSString *keyword;
@property (nonatomic, copy, readonly) WKChannelHistorySearchFilter *filter;

@property (nonatomic, copy, readonly) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign, readonly) BOOL hasMore;
@property (nonatomic, copy, readonly, nullable) NSString *nextCursor;

@property (nonatomic, assign, readonly) BOOL isLoadingFirstPage;
@property (nonatomic, assign, readonly) BOOL isLoadingNextPage;
@property (nonatomic, copy, readonly, nullable) NSError *firstPageError;
@property (nonatomic, copy, readonly, nullable) NSError *nextPageError;
@property (nonatomic, assign, readonly) BOOL queryStarted;
@property (nonatomic, assign, readonly) BOOL shouldRunSearch;

- (void)applyKeyword:(nullable NSString *)keyword;
- (void)applyFilter:(nullable WKChannelHistorySearchFilter *)filter;
- (void)refresh;
- (void)loadMore;
- (void)cancelInFlight;

@end

NS_ASSUME_NONNULL_END
