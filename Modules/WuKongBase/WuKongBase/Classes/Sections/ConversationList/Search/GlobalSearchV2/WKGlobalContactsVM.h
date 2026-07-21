//
//  WKGlobalContactsVM.h
//  WuKongBase
//
//  全局搜索「联系人」+「群组」共享逻辑。一次 POST /search/global 同时返回
//  friends[] + groups[]，两个 tab 切片复用同一份结果，避免重复请求（与 web 一致）。
//  点击行为保留：联系人→名片(WKPOINT_USER_INFO)，群组→进会话(pushConversation)。
//

#import <Foundation/Foundation.h>

@class WKSearchContactsModel;
@class WKGlobalContactsVM;

NS_ASSUME_NONNULL_BEGIN

@protocol WKGlobalContactsVMDelegate <NSObject>
- (void)globalContactsVMDidChangeState:(WKGlobalContactsVM *)vm;
@optional
- (void)globalContactsVMKeywordExceedLimit:(WKGlobalContactsVM *)vm;
@end

@interface WKGlobalContactsVM : NSObject

@property (nonatomic, weak, nullable) id<WKGlobalContactsVMDelegate> delegate;

@property (nonatomic, copy, readonly) NSString *keyword;
@property (nonatomic, copy, readonly) NSArray<WKSearchContactsModel *> *friendModels;
@property (nonatomic, copy, readonly) NSArray<WKSearchContactsModel *> *groupModels;

@property (nonatomic, assign, readonly) BOOL isLoading;
@property (nonatomic, copy, readonly, nullable) NSError *error;
@property (nonatomic, assign, readonly) BOOL queryStarted;
@property (nonatomic, assign, readonly) BOOL shouldRunSearch;

- (void)applyKeyword:(nullable NSString *)keyword;
- (void)refresh;
- (void)cancelInFlight;

@end

NS_ASSUME_NONNULL_END
