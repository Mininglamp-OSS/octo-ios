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

@end
