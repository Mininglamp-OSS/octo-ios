// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKWebIdentityHandoff.h"
#import "WuKongBase.h"

static NSString *WKDefaultSid(void) {
    return @"ios";
}

// WKEffectivePort / WKSameOrigin 已上移至 WKWebIdentityHandoff.h（static inline），
// 供 bridge 来源守卫（WKWebViewService）等处复用，保证全仓同源判断单一口径。

// 免登注入的路径白名单（对齐安卓 DocsViewerUrlPolicy.VIEWER_PATH 的「上下文
// 跟随路由」模型，并覆盖服务端 summaryDeepLink 的 /s/{task_no} 形状）：
// token 是长期全账号凭证，同 origin 上的文件服务/第三方组件（部署上与 API
// 同 host，见 octo-server configs/tsdd.yaml 对 upload host 与 web origin 的
// 说明）不应仅因 origin 相同就拿到它——只对确实需要免登的 H5 路由注入：
//   /s/{task_no}          总结文档（服务端 summary-notify-card deep-link）
//   /d/{docId}            文档查看器
//   /ppt/d/{docId}        PPT 预览
//   /docs/{docId}/present 文档演示
// id 形态对齐安卓：[A-Za-z0-9_-]{1,128}，整段精确匹配（不前缀匹配），
// 末尾至多一个 /。report 页不需要白名单排除——不在名单内天然不注入。
static BOOL WKIsHandoffPath(NSString *path) {
    static NSRegularExpression *re;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *idPart = @"[A-Za-z0-9_-]{1,128}";
        re = [NSRegularExpression regularExpressionWithPattern:
            [NSString stringWithFormat:@"^/(?:s/%@|d/%@|ppt/d/%@|docs/%@/present)/?$",
                idPart, idPart, idPart, idPart]
            options:0 error:nil];
    });
    return re && [re firstMatchInString:path options:0 range:NSMakeRange(0, path.length)] != nil;
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
// 直接在 percentEncodedQuery 上做字符串级替换，不经过 queryItems 往返：
// queryItems getter/setter 会把整条 query 先解码再重编码，原 URL 里合法的
// %2B 会被改写成 +（form-urlencoded 语义下变成空格）、%3A 变 :，签名类/
// base64 类参数被静默变义（本仓 WKAppConfig 对 + 的编码语义是明确在意的）。
static NSString *WKencodeURIComponent(NSString *value);
static NSURL *WKAppendSidParam(NSURL *URL, NSString *sid) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (components == nil) return URL;
    NSString *pair = [NSString stringWithFormat:@"sid=%@", WKencodeURIComponent(sid)];
    NSString *query = components.percentEncodedQuery;
    if (query.length == 0) {
        components.percentEncodedQuery = pair;
        return components.URL;
    }
    // 按已有 item 边界逐段处理：第一个 sid 替换为 ios，其余 sid 直接删除
    // （只替换不删除会残留第二个 sid，web 端 URLSearchParams.get 取第一个
    // 之外的场景仍会错位）。其余参数字节级原样保留。
    NSMutableArray<NSString *> *parts = [[query componentsSeparatedByString:@"&"] mutableCopy];
    BOOL replaced = NO;
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *part in parts) {
        NSString *name = part;
        NSUInteger eq = [name rangeOfString:@"="].location;
        if (eq != NSNotFound) name = [name substringToIndex:eq];
        // percentEncodedQuery 里的名字可能带百分号编码，但 "sid" 全为
        // unreserved 字符，不会出现编码变体，直接比较安全。
        if ([name isEqualToString:@"sid"]) {
            if (!replaced) {
                [kept addObject:pair];
                replaced = YES;
            }
            continue;
        }
        [kept addObject:part];
    }
    if (!replaced) [kept addObject:pair];
    components.percentEncodedQuery = [kept componentsJoinedByString:@"&"];
    return components.URL ?: URL;
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

// 测试入口：转义契约直接断言（见 .h 注释）。
+ (NSString *)JSONString:(NSString *)value {
    return WKJSONString(value);
}

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
    // 正向路径白名单：只对确实需要免登的 H5 路由注入凭证（见 WKIsHandoffPath
    // 注释）。report 页不在名单内天然排除，无需单独 denylist。
    if (!WKIsHandoffPath(candidate.path)) return nil;

    return WKAppendSidParam(URL, WKDefaultSid());
}

+ (NSURL *)sanitizedURLForExternalUse:(NSURL *)URL {
    if (URL == nil) return URL;
    // 只剥「我们注入的」sid：sid 只会被写到同源 + 免登路由白名单的 URL 上，
    // 因此仅当 URL 同源且路径命中白名单时才剥（此时 sid 恒为 ios，必然是
    // native 写的）。其它 URL（第三方页面自带的 sid=vendor-session 等）原样
    // 返回——全量剥 sid 会误伤外链自身的业务参数（评审 P1 的修法收窄，
    // 保留「复制/转发出去的 URL 不带内部 sid」的已确认语义）。
    NSURLComponents *scope = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (scope == nil || scope.scheme.length == 0 || scope.host.length == 0) return URL;
    NSString *apiBaseURL = [WKApp shared].config.apiBaseUrl;
    if (apiBaseURL.length == 0) return URL;
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    if (server.scheme.length == 0 || server.host.length == 0) return URL;
    if (!WKSameOrigin(scope, server)) return URL;
    if (!WKIsHandoffPath(scope.path)) return URL;
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (components == nil || components.percentEncodedQuery.length == 0) return URL;
    // 与 WKAppendSidParam 同口径：在 percentEncodedQuery 上做字符串级拼接，
    // 不经过 queryItems 往返（会把 %2B 改写成 +，外链参数被静默变义）。
    // 逐段保留未删 item 的原始编码字节；sid 全部删除后不再写空 query，
    // 避免留下孤立 "?"。
    NSMutableArray<NSString *> *parts =
        [[components.percentEncodedQuery componentsSeparatedByString:@"&"] mutableCopy];
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *part in parts) {
        NSString *name = part;
        NSUInteger eq = [name rangeOfString:@"="].location;
        if (eq != NSNotFound) name = [name substringToIndex:eq];
        if (![name isEqualToString:@"sid"]) [kept addObject:part];
    }
    if (kept.count == parts.count) return URL;
    if (kept.count == 0) {
        components.percentEncodedQuery = nil; // 置空后 URL 不再带孤立 "?"
        return components.URL ?: URL;
    }
    components.percentEncodedQuery = [kept componentsJoinedByString:@"&"];
    return components.URL ?: URL;
}

+ (nullable NSString *)trustedOrigin {
    NSString *apiBaseURL = [WKApp shared].config.apiBaseUrl;
    if (apiBaseURL.length == 0) return nil;
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    if (server.scheme.length == 0 || server.host.length == 0) return nil;
    NSNumber *port = WKEffectivePort(server) ?: @0;
    return [NSString stringWithFormat:@"%@://%@:%@",
        server.scheme.lowercaseString, server.host.lowercaseString, port];
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
    // 种子取 native 当前 space（NSUserDefaults currentSpaceId）而非页面 localStorage：
    // /s/ 总结路由上没有任何脚本写过 currentSpaceId，从页面取恒为空，双写等于没写
    // （Octo-Q 评审 P2）。无 space 时不写键（对齐 WKDocsViewerSpaceHandoff 的
    // removeItem 约定：「没有就不留键」），避免空串占位短路 web 端的迁移/默认
    // space 判定。
    if (uid.length > 0) {
        NSString *nativeSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        if (nativeSpaceId.length > 0) {
            NSString *spaceKey = [NSString stringWithFormat:@"octo:last-space:%@", WKencodeURIComponent(uid)];
            NSString *spaceKeyJSON = WKJSONString(spaceKey);
            [items appendFormat:@"localStorage.setItem(%@,%@);",
                spaceKeyJSON, WKJSONString(nativeSpaceId)];
        }
    }
    [items appendFormat:@"sessionStorage.setItem('octo.session.sid',%@);", sidJSON];

    // 可信 origin 串只在这一处构造：+trustedOrigin 与注入 JS 共用，
    // 两处各写一份会在未来改动时静默失配（评审 Nit）。
    NSString *origin = [self trustedOrigin];
    if (origin.length == 0) return nil;
    NSString *originJSON = WKJSONString(origin);

    // 运行时路径白名单与 native WKIsHandoffPath 同口径：/s/、/d/、/ppt/d/、
    // /docs/*/present 之外的路由（含 report 页、外链、重定向落点）一律不写
    // 凭证。正则的 id 部分与 native 完全一致。
    NSString *runtimePathCheck =
        @"var m=p.match(/^\\/(?:s\\/[A-Za-z0-9_-]{1,128}|d\\/[A-Za-z0-9_-]{1,128}"
        @"|ppt\\/d\\/[A-Za-z0-9_-]{1,128}|docs\\/[A-Za-z0-9_-]{1,128}\\/present)\\/?$/);"
        @"if(!m)return;";

    return [NSString stringWithFormat:
        @"(function(){try{var o=%@;var p0=location.protocol.slice(0,-1).toLowerCase(),"
        @"n=location.port?Number(location.port):(p0==='https'?443:(p0==='http'?80:0));"
        @"var h=p0+'://'+location.hostname.toLowerCase()+':'+n;"
        @"if(h!==o)return;var p=(location.pathname||'').toLowerCase();"
        @"%@var s=%@;%@}catch(e){}})();",
        originJSON, runtimePathCheck, sidJSON, items];
}

@end
