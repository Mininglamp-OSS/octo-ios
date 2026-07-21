//
//  WKGlobalMsgDetailVM.h
//  WuKongBase
//
//  全局搜索「聊天记录」L1 点某桶 → L2 详情：该会话/群/子区/私聊内消息扁平流。
//  POST _search_global_messages（filters.channel_ids = 该桶身份），cursor 翻页。
//  逻辑与 WKChannelHistorySearchVM 一致（reqId 竞态丢弃 + cursor 守卫）。
//

#import <Foundation/Foundation.h>
#import "WKGlobalSearchModels.h"
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@class WKGlobalMsgDetailVM;

@protocol WKGlobalMsgDetailVMDelegate <NSObject>
- (void)globalMsgDetailVMDidChangeState:(WKGlobalMsgDetailVM *)vm;
@end

@interface WKGlobalMsgDetailVM : NSObject

- (instancetype)initWithBucket:(WKGlobalSearchGroupBucket *)bucket
                       keyword:(nullable NSString *)keyword
                        filter:(nullable WKChannelHistorySearchFilter *)filter;

@property (nonatomic, weak, nullable) id<WKGlobalMsgDetailVMDelegate> delegate;
@property (nonatomic, strong, readonly) WKGlobalSearchGroupBucket *bucket;
@property (nonatomic, copy, readonly) NSString *keyword;

@property (nonatomic, copy, readonly) NSArray<WKChannelHistorySearchItem *> *items;
@property (nonatomic, assign, readonly) BOOL hasMore;
@property (nonatomic, copy, readonly, nullable) NSString *nextCursor;

@property (nonatomic, assign, readonly) BOOL isLoadingFirstPage;
@property (nonatomic, assign, readonly) BOOL isLoadingNextPage;
@property (nonatomic, copy, readonly, nullable) NSError *firstPageError;
@property (nonatomic, copy, readonly, nullable) NSError *nextPageError;
@property (nonatomic, assign, readonly) BOOL queryStarted;

- (void)refresh;
- (void)loadMore;
- (void)cancelInFlight;

@end

NS_ASSUME_NONNULL_END
