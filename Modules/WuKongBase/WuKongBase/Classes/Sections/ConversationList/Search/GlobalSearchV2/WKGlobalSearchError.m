//
//  WKGlobalSearchError.m
//  WuKongBase
//

#import "WKGlobalSearchError.h"
#import "WuKongBase.h"

@implementation WKGlobalSearchError

/// 从 NSError.userInfo 里取出 body error.code 字符串（WKApp errorHandler 把整个 400 body 存进
/// userInfo，键结构 { "error": { "code", "http_status", "message" } }）。
+ (nullable NSString *)codeStringFromError:(nullable NSError *)error {
    if (!error) return nil;
    NSDictionary *info = error.userInfo;
    id errObj = info[@"error"];
    if ([errObj isKindOfClass:[NSDictionary class]]) {
        id code = ((NSDictionary *)errObj)[@"code"];
        if ([code isKindOfClass:[NSString class]]) return (NSString *)code;
    }
    // 兜底：有的实现把 code 平铺在外层
    id code = info[@"code"];
    if ([code isKindOfClass:[NSString class]]) return (NSString *)code;
    return nil;
}

+ (WKGlobalSearchErrorCode)codeFromError:(nullable NSError *)error {
    if (!error) return WKGlobalSearchErrorUnknown;
    NSString *code = [self codeStringFromError:error];
    if (code.length == 0) {
        // 没有可解析 body → 视作网络层错误（断网 / 超时 / 非 JSON）
        return WKGlobalSearchErrorNetwork;
    }
    if ([code isEqualToString:@"VALIDATION_ERROR"]) return WKGlobalSearchErrorValidation;
    if ([code isEqualToString:@"RATE_LIMITED"]) return WKGlobalSearchErrorRateLimited;
    if ([code isEqualToString:@"SEARCH_DISABLED"]) return WKGlobalSearchErrorSearchDisabled;
    if ([code isEqualToString:@"NOT_FOUND"]) return WKGlobalSearchErrorNotFound;
    if ([code isEqualToString:@"UPSTREAM_UNAVAILABLE"]) return WKGlobalSearchErrorUpstream;
    if ([code isEqualToString:@"INTERNAL_ERROR"]) return WKGlobalSearchErrorUpstream;
    if ([code isEqualToString:@"DEPTH_EXCEEDED"]) return WKGlobalSearchErrorDepthExceeded;
    return WKGlobalSearchErrorUnknown;
}

+ (BOOL)shouldFallbackToLocal:(nullable NSError *)error {
    return [self codeFromError:error] == WKGlobalSearchErrorSearchDisabled;
}

+ (BOOL)shouldToastKeepingResults:(nullable NSError *)error {
    WKGlobalSearchErrorCode c = [self codeFromError:error];
    return c == WKGlobalSearchErrorRateLimited || c == WKGlobalSearchErrorDepthExceeded;
}

+ (nullable NSString *)userMessageForError:(nullable NSError *)error {
    switch ([self codeFromError:error]) {
        case WKGlobalSearchErrorRateLimited:   return LLang(@"搜索太频繁，请稍后再试");
        case WKGlobalSearchErrorDepthExceeded: return LLang(@"结果太多，请缩小搜索范围");
        case WKGlobalSearchErrorUpstream:      return LLang(@"搜索服务暂时不可用，请稍后重试");
        case WKGlobalSearchErrorNetwork:       return LLang(@"当前网络不可用，请检查网络后重试");
        case WKGlobalSearchErrorValidation:    return nil; // 静默
        case WKGlobalSearchErrorNotFound:      return nil; // 走空态
        case WKGlobalSearchErrorSearchDisabled:return nil; // 走回落
        case WKGlobalSearchErrorUnknown:       return nil;
    }
    return nil;
}

@end
