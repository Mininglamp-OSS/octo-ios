// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKWebIdentityHandoff.h"
#import "WuKongBase.h"

static NSString *WKDefaultSid(void) {
    return @"ios";
}

static NSNumber *WKEffectivePort(NSURLComponents *components) {
    if (components.port != nil) return components.port;
    NSString *scheme = components.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"]) return @443;
    if ([scheme isEqualToString:@"http"]) return @80;
    return nil;
}

static BOOL WKSameOrigin(NSURLComponents *a, NSURLComponents *b) {
    return [a.scheme.lowercaseString isEqualToString:b.scheme.lowercaseString] &&
        [a.host.lowercaseString isEqualToString:b.host.lowercaseString] &&
        [WKEffectivePort(a) isEqualToNumber:WKEffectivePort(b)];
}

// report.html 走后端一次性 ?session= 握手，注入无效且不必要。
static BOOL WKIsReportPath(NSString *path) {
    return [path.lowercaseString hasPrefix:@"/report"];
}

static NSString *WKExtractSid(NSURL *URL) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"sid"] && item.value.length > 0) return item.value;
    }
    return nil;
}

// 与 web 端 encodeURIComponent 对齐（不转义 A-Z a-z 0-9 - _ . ! ~ * ' ( )）。
static NSString *WKencodeURIComponent(NSString *value) {
    static NSCharacterSet *allowed;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
        [set addCharactersInString:@"-_.!~*'()"];
        allowed = set;
    });
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

static NSURL *WKAppendSidParam(NSURL *URL, NSString *sid) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (components == nil) return URL;
    NSMutableArray<NSURLQueryItem *> *items = [components.queryItems mutableCopy] ?: [NSMutableArray array];
    for (NSURLQueryItem *item in items) {
        // 已有非空 sid 保留原值不覆盖（URL 可能来自 web 端带 ?sid=web 的深链）。
        // 空 sid 视为缺失继续追加：web 端 getSidFromSearch 对空串照单全收，
        // 若这里不补会与我们反读的默认 sid 分桶错位。
        if ([item.name isEqualToString:@"sid"] && item.value.length > 0) return URL;
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"sid" value:sid]];
    components.queryItems = items;
    return components.URL;
}

static NSString *WKJSONString(NSString *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *arrayJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *valueJSON = arrayJSON.length >= 2 ? [arrayJSON substringWithRange:NSMakeRange(1, arrayJSON.length - 2)] : @"\"\"";
    valueJSON = [valueJSON stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2028]
                                                     withString:@"\\u2028"];
    return [valueJSON stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2029]
                                                withString:@"\\u2029"];
}

@implementation WKWebIdentityHandoff

+ (nullable NSURL *)handoffURLForURL:(NSURL *)URL {
    return [self trustedHandoffURLForURL:URL];
}

+ (nullable NSURL *)trustedHandoffURLForURL:(NSURL *)URL {
    if (URL == nil) return nil;
    NSString *apiBaseURL = [WKApp shared].config.apiBaseUrl;
    if (apiBaseURL.length == 0) return nil;

    NSURLComponents *candidate = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    if (candidate.scheme.length == 0 || candidate.host.length == 0 ||
        server.scheme.length == 0 || server.host.length == 0) return nil;
    if ([candidate.user length] > 0 || [candidate.password length] > 0) return nil;
    if (!WKSameOrigin(candidate, server)) return nil;
    if (WKIsReportPath(candidate.percentEncodedPath)) return nil;

    return WKAppendSidParam(URL, WKDefaultSid());
}

+ (nullable NSString *)identityJavaScriptForURL:(NSURL *)URL {
    NSURL *handoffURL = [self trustedHandoffURLForURL:URL];
    if (handoffURL == nil) return nil;

    NSString *sid = WKExtractSid(handoffURL) ?: WKDefaultSid();
    WKLoginInfo *loginInfo = [WKApp shared].loginInfo;
    NSString *token = loginInfo.token ?: @"";
    NSString *uid = loginInfo.uid ?: @"";
    NSString *name = loginInfo.displayName ?: @"";
    if (token.length == 0) return nil;

    NSMutableString *items = [NSMutableString string];
    [items appendFormat:@"localStorage.setItem('token%@',%@);", sid, WKJSONString(token)];
    [items appendFormat:@"localStorage.setItem('uid%@',%@);", sid, WKJSONString(uid)];
    [items appendFormat:@"localStorage.setItem('name%@',%@);", sid, WKJSONString(name)];
    // Space key 双写：现行 key 按 uid 分桶，legacy 全局 key 会被 web 端迁移标记短路，
    // 只写 legacy 不可靠。key 编码与 web 端 encodeURIComponent(uid) 严格对齐。
    if (uid.length > 0) {
        NSString *spaceKey = [NSString stringWithFormat:@"octo:last-space:%@", WKencodeURIComponent(uid)];
        [items appendFormat:@"localStorage.setItem(%@,localStorage.getItem(%@)||localStorage.getItem('currentSpaceId')||'');",
            WKJSONString(spaceKey), WKJSONString(spaceKey)];
    }
    [items appendFormat:@"sessionStorage.setItem('octo.session.sid',%@);", WKJSONString(sid)];

    return [NSString stringWithFormat:
        @"(function(){try{if(!localStorage.getItem('token%@')){%@}}catch(e){}})();", sid, items];
}

@end
