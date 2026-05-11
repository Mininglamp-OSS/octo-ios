//
//  WKOidcProviderConfig.m
//  WuKongBase
//
//  YUJ-396 — 见 .h 注释。
//

#import "WKOidcProviderConfig.h"

@implementation WKOidcProviderConfig

+ (nullable NSString *)sanitizeHttpsURL:(id)value {
    if(![value isKindOfClass:[NSString class]]) return nil;
    NSString *str = (NSString *)value;
    if(str.length == 0) return nil;
    NSURL *u = [NSURL URLWithString:str];
    if(!u) return nil;
    NSString *scheme = u.scheme.lowercaseString;
    // 仅允许 https（http 在此场景下也不可接受：Aegis 账户页涉及密码 / OIDC token,
    // 必须是 TLS）。这里比 Web 端更严; Web 端为兼容 dev localhost 允许 http, 客户端
    // 不跑在 localhost, 直接收紧。
    if(![scheme isEqualToString:@"https"]) return nil;
    // host 必须有值; schemes://emptyhost/... 在构造 NSURL 时可能过掉, 这里兜底。
    if(u.host.length == 0) return nil;
    // YUJ-396 Round 2 / Jerry-Xin #112 suggestion: 拒绝带 query 或 fragment 的
    // base URL。后端下发 `https://accounts.example.com?x=1` 时 buildVerifyURLFromAccountUrl:
    // 会拼成 `https://accounts.example.com?x=1/profile/info?anchor=verification`,
    // query 结构不合法且把 `/profile/info` 吞进 query 参数值里, 浏览器解析歧义,
    // 更安全的做法是 parser 层直接拒收 —— accountUrl 的语义就是「基址 URL」,
    // 带 query / fragment 本身是配置错误。
    NSURLComponents *comp = [NSURLComponents componentsWithString:str];
    if(comp.query != nil || comp.fragment != nil) return nil;
    return str;
}

+ (BOOL)isSafeAuthorizePath:(id)value {
    if(![value isKindOfClass:[NSString class]]) return NO;
    NSString *str = (NSString *)value;
    if(str.length < 2) return NO;
    if(![str hasPrefix:@"/"]) return NO;
    if([str hasPrefix:@"//"]) return NO;   // 阻止 '//evil.com/...' 协议相对 URL 跳站外
    return YES;
}

+ (NSArray<WKOidcProviderConfig *> *)parseArray:(NSArray *)raw {
    if(![raw isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray<WKOidcProviderConfig *> *out = [NSMutableArray array];
    for(id item in raw) {
        if(![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *d = (NSDictionary *)item;

        // id 必填（作为 provider 的标识）; 缺 / 空 → 跳过 entry。
        id idVal = d[@"id"];
        if(![idVal isKindOfClass:[NSString class]] || ((NSString *)idVal).length == 0) continue;

        // authorize_path 必填 + 格式安全守卫; 非法 → 跳过 entry。
        // 与 Web 端 parseOidcProviders 口径一致。
        id pathVal = d[@"authorize_path"];
        if(![self isSafeAuthorizePath:pathVal]) continue;

        // YUJ-396 P-S1 (Jerry-Xin #112 review suggestion 1): name 改为 optional,
        // 缺失 / 空串仍保留 entry（只是 name=nil）, UI 侧 fallback 到 providerId 展示。
        // 原实现 name required-else-skip 与 .h 注释 "可缺" 矛盾; 同时 name 只是
        // 展示字段, 业务上有 account_url 就能用。
        id nameVal = d[@"name"];
        NSString *resolvedName = nil;
        if([nameVal isKindOfClass:[NSString class]] && ((NSString *)nameVal).length > 0) {
            resolvedName = (NSString *)nameVal;
        }

        WKOidcProviderConfig *p = [WKOidcProviderConfig new];
        p.providerId = (NSString *)idVal;
        p.name = resolvedName;
        p.authorizePath = (NSString *)pathVal;
        p.accountUrl = [self sanitizeHttpsURL:d[@"account_url"]];
        p.resetPasswordUrl = [self sanitizeHttpsURL:d[@"reset_password_url"]];
        [out addObject:p];
    }
    return [out copy];
}

// YUJ-420 R1 fix (Jerry-Xin 🔴 Critical): WKLoginView / WKRegisterVC 两处 buildOidcAuthorizeURL 共用 helper。
// 原实现用 URLQueryAllowedCharacterSet + stringByAddingPercentEncodingWithAllowedCharacters 手拼
// query, 该字符集不转义 `&`/`=`/`+` — authcode 或 device_name 出现这些字符时会被
// 截断或注入旁的 query param。
// 用 NSURLComponents + NSURLQueryItem 让系统一方应注 RFC 3986 安全转义；不再打 full URL 日志,
// 仅 host+path debug 日志, authcode/device_* 脱敏。
+ (nullable NSURL *)buildAuthorizeURLForProvider:(WKOidcProviderConfig *)provider
                                         authcode:(NSString *)authcode
                                          apiBase:(NSString *)apiBase
                                         deviceId:(nullable NSString *)deviceId
                                       deviceName:(nullable NSString *)deviceName
                                      deviceModel:(nullable NSString *)deviceModel {
    NSString *path = provider.authorizePath ?: @"";
    NSString *effectiveBase = apiBase ?: @"";
    NSString *baseStr = nil;
    if([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        baseStr = path;
    } else if([path hasPrefix:@"/"]) {
        NSURL *baseURL = [NSURL URLWithString:effectiveBase];
        NSURL *resolved = [NSURL URLWithString:path relativeToURL:baseURL];
        baseStr = resolved.absoluteString;
    } else {
        baseStr = [effectiveBase stringByAppendingString:path];
    }
    if(baseStr.length == 0) return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:baseStr];
    if(!components) return nil;

    // 保留 base URL 自带的 query（罕见但向前兼容）, 追加 auth/device 参数。
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    if(components.queryItems) {
        [items addObjectsFromArray:components.queryItems];
    }
    if(authcode.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"authcode" value:authcode]];
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"flag" value:@"3"]];
    if(deviceId.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"device_id" value:deviceId]];
    }
    if(deviceName.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"device_name" value:deviceName]];
    }
    if(deviceModel.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"device_model" value:deviceModel]];
    }
    components.queryItems = items;

    NSURL *full = components.URL;
    if(!full) return nil;
    // 脱敏日志: 仅打 host + path, 不包含 query (authcode / device 信息)。
    NSString *redactedOrigin = [NSString stringWithFormat:@"%@://%@%@",
                                full.scheme ?: @"",
                                full.host ?: @"",
                                full.path ?: @""];
    NSInteger paramCount = (NSInteger)components.queryItems.count;
    NSLog(@"[OIDC] authorize url host=%@ params=%ld", redactedOrigin, (long)paramCount);
    return full;
}


// YUJ-420 R3 fix (Jerry-Xin Critical): 递归剥 NSNull, 产出 plist-safe 副本。
// 详见 .h 注释。
+ (nullable id)plistSanitize:(nullable id)value {
    if(value == nil) return nil;
    if([value isKindOfClass:[NSNull class]]) return nil;
    if([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for(id item in (NSArray *)value) {
            id sanitized = [self plistSanitize:item];
            if(sanitized != nil) {
                [out addObject:sanitized];
            }
        }
        return [out copy];
    }
    if([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        for(id key in ((NSDictionary *)value).allKeys) {
            // plist key 必须是 NSString
            if(![key isKindOfClass:[NSString class]]) continue;
            id sanitized = [self plistSanitize:((NSDictionary *)value)[key]];
            if(sanitized != nil) {
                out[key] = sanitized;
            }
        }
        return [out copy];
    }
    // plist-native 类型原样放行
    if([value isKindOfClass:[NSString class]] ||
       [value isKindOfClass:[NSNumber class]] ||
       [value isKindOfClass:[NSData class]] ||
       [value isKindOfClass:[NSDate class]]) {
        return value;
    }
    // 其它非 plist 类型（自定义对象等）静默丢弃，避免写盘 crash
    return nil;
}

@end
