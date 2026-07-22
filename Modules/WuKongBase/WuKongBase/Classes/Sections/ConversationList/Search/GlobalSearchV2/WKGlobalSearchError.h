//
//  WKGlobalSearchError.h
//  WuKongBase
//
//  把服务端搜索错误（messages_search 模块 wire HTTP 恒 400，真实语义在 body
//  error.{code,http_status,message}）映射成前端可决策的枚举。依赖 WKApp.m 的 errorHandler
//  把 400 body 解析进 NSError.userInfo（键 "error" 下）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKGlobalSearchErrorCode) {
    WKGlobalSearchErrorUnknown = 0,
    WKGlobalSearchErrorValidation,      // VALIDATION_ERROR：静默（多为触发门/参数瞬时不满足）
    WKGlobalSearchErrorRateLimited,     // RATE_LIMITED：toast，保留当前结果
    WKGlobalSearchErrorSearchDisabled,  // SEARCH_DISABLED：运行时回落本地搜索
    WKGlobalSearchErrorNotFound,        // NOT_FOUND：空态
    WKGlobalSearchErrorUpstream,        // UPSTREAM_UNAVAILABLE / INTERNAL_ERROR：错误态 + 重试
    WKGlobalSearchErrorDepthExceeded,   // DEPTH_EXCEEDED：翻页过深
    WKGlobalSearchErrorNetwork,         // 本地网络错误（无 body / 断网）
};

@interface WKGlobalSearchError : NSObject

/// 从 NSError 解析出语义码。
+ (WKGlobalSearchErrorCode)codeFromError:(nullable NSError *)error;

/// 该错误是否应触发运行时回落到本地搜索（SEARCH_DISABLED）。
+ (BOOL)shouldFallbackToLocal:(nullable NSError *)error;

/// 该错误是否只需 toast 且保留当前结果（RATE_LIMITED / DEPTH_EXCEEDED）。
+ (BOOL)shouldToastKeepingResults:(nullable NSError *)error;

/// 面向用户的提示文案（nil 表示不提示）。
+ (nullable NSString *)userMessageForError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
