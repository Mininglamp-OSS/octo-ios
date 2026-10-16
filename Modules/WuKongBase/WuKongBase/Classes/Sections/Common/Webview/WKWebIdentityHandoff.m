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
// 锚定整个首段路径，避免误伤 /reports、/reporting 等相邻路由。
static BOOL WKIsReportPath(NSString *path) {
    return [path.lowercaseString isEqualToString:@"/report"] ||
        [path.lowercaseString hasPrefix:@"/report.html"] ||
        [path.lowercaseString hasPrefix:@"/report/"];
}

static NSString *WKExtractSid(NSURL *URL) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"sid"] && item.value.length > 0) return item.value;
    }
    return nil;
}

// 已有 sid key 无论是否为空都替换为 ios：追加第二个 sid 会导致 web 端
// URLSearchParams.get 取到第一个（空值），与 native 反读的分桶错位。
static NSURL *WKAppendSidParam(NSURL *URL, NSString *sid) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (components == nil) return URL;
    NSMutableArray<NSURLQueryItem *> *items = [components.queryItems mutableCopy] ?: [NSMutableArray array];
    BOOL replaced = NO;
    for (NSUInteger i = 0; i < items.count; i++) {
        if ([items[i].name isEqualToString:@"sid"]) {
            items[i] = [NSURLQueryItem queryItemWithName:@"sid" value:sid];
            replaced = YES;
        }
    }
    if (!replaced) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"sid" value:sid]];
    }
    components.queryItems = items;
    return components.URL;
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
    NSString *apiBaseURL = [WKApp shared].config.apiBaseUrl;

    NSString *sid = WKExtractSid(handoffURL) ?: WKDefaultSid();
    WKLoginInfo *loginInfo = [WKApp shared].loginInfo;
    NSString *token = loginInfo.token ?: @"";
    NSString *uid = loginInfo.uid ?: @"";
    NSString *name = loginInfo.displayName ?: @"";
    if (token.length == 0) return nil;

    // key 在 native 侧拼完整字符串后统一 JSON 序列化，sid 不做裸插值
    // （sid 来自消息 URL，含引号/反斜杠时不能越出字符串字面量）。
    NSString *tokenKey = WKJSONString([NSString stringWithFormat:@"token%@", sid]);
    NSString *uidKey = WKJSONString([NSString stringWithFormat:@"uid%@", sid]);
    NSString *nameKey = WKJSONString([NSString stringWithFormat:@"name%@", sid]);
    NSString *sidJSON = WKJSONString(sid);

    NSMutableString *items = [NSMutableString string];
    [items appendFormat:@"localStorage.setItem(%@,%@);", tokenKey, WKJSONString(token)];
    [items appendFormat:@"localStorage.setItem(%@,%@);", uidKey, WKJSONString(uid)];
    [items appendFormat:@"localStorage.setItem(%@,%@);", nameKey, WKJSONString(name)];
    // Space key 双写：现行 key 按 uid 分桶，legacy 全局 key 会被 web 端迁移标记短路，
    // 只写 legacy 不可靠。key 编码与 web 端 encodeURIComponent(uid) 严格对齐。
    if (uid.length > 0) {
        NSString *spaceKey = [NSString stringWithFormat:@"octo:last-space:%@", WKencodeURIComponent(uid)];
        NSString *spaceKeyJSON = WKJSONString(spaceKey);
        [items appendFormat:@"if(!localStorage.getItem(%@))localStorage.setItem(%@,localStorage.getItem('currentSpaceId')||'');",
            spaceKeyJSON, spaceKeyJSON];
    }
    [items appendFormat:@"sessionStorage.setItem('octo.session.sid',%@);", sidJSON];

    // 运行时 origin 守卫：user script 在本 webview 的所有后续主 frame 导航中都会执行
    // （含外链/重定向离开可信域的场景），必须在任何凭证访问之前校验当前文档
    // 的 origin 与排除路径。native 判定只发生在脚本生成时，挡不住后续导航。
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    NSString *origin = [NSString stringWithFormat:@"%@://%@%@",
        server.scheme.lowercaseString, server.host.lowercaseString,
        server.port ? [NSString stringWithFormat:@":%@", server.port] : @""];
    NSString *originJSON = WKJSONString(origin);

    return [NSString stringWithFormat:
        @"(function(){try{var o=%@;var h=location.protocol+'//'+location.hostname+(location.port?':'+location.port:'');"
        @"if(h!==o)return;var p=(location.pathname||'').toLowerCase();"
        @"if(p==='/report'||p.indexOf('/report.html')===0||p.indexOf('/report/')===0)return;"
        @"var s=%@;%@}catch(e){}})();",
        originJSON, sidJSON, items];
}

@end
