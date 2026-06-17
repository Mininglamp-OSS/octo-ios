//
//  WKIncomingWebhook.m
//  WuKongBase
//

#import "WKIncomingWebhook.h"

NSString * const WKIncomingWebhookUidPrefix = @"iwh_";

static id _safeStringOrEmpty(id v) {
    if (!v || v == [NSNull null]) return @"";
    if ([v isKindOfClass:[NSString class]]) return v;
    return [NSString stringWithFormat:@"%@", v];
}

@implementation WKIncomingWebhook

+ (instancetype)fromDict:(NSDictionary *)dict {
    WKIncomingWebhook *h = [WKIncomingWebhook new];
    if (![dict isKindOfClass:[NSDictionary class]]) return h;
    h.webhookId  = _safeStringOrEmpty(dict[@"webhook_id"]);
    h.groupNo    = _safeStringOrEmpty(dict[@"group_no"]);
    h.name       = _safeStringOrEmpty(dict[@"name"]);
    h.avatar     = _safeStringOrEmpty(dict[@"avatar"]);
    h.creatorUid = _safeStringOrEmpty(dict[@"creator_uid"]);
    h.status     = (WKIncomingWebhookStatus)[dict[@"status"] integerValue];
    h.lastUsedAt = [dict[@"last_used_at"] doubleValue];
    h.callCount  = [dict[@"call_count"] integerValue];
    h.createdAt  = [dict[@"created_at"] doubleValue];

    id token = dict[@"token"];
    if ([token isKindOfClass:[NSString class]] && [token length] > 0) {
        h.token = token;
    }
    id url = dict[@"url"];
    if ([url isKindOfClass:[NSString class]] && [url length] > 0) {
        h.url = url;
    }
    id urls = dict[@"urls"];
    if ([urls isKindOfClass:[NSDictionary class]]) {
        NSDictionary *u = urls;
        if ([u[@"native"] isKindOfClass:[NSString class]]) h.urlNative = u[@"native"];
        if ([u[@"github"] isKindOfClass:[NSString class]]) h.urlGithub = u[@"github"];
        if ([u[@"wecom"]  isKindOfClass:[NSString class]]) h.urlWecom  = u[@"wecom"];
    }
    return h;
}

- (BOOL)canManageByCurrentUser:(BOOL)isManagerOrCreator {
    if (isManagerOrCreator) return YES;
    return self.creatorUid.length > 0;
}

- (BOOL)canTest {
    return self.status == WKIncomingWebhookStatusEnabled;
}

@end

NSString * WKIncomingWebhookAbsoluteURL(NSString *relativeUrl, NSString *apiBaseUrl) {
    if (relativeUrl.length == 0) return @"";
    NSString *lower = [relativeUrl lowercaseString];
    if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) {
        return relativeUrl;
    }
    if (apiBaseUrl.length == 0) return @"";

    // apiBaseUrl 形如 `https://im.example.com/api/v1/`；服务端相对路径自带
    // `/v1` 段，直接拼会出现 `/api/v1/v1/...`，先剥掉 base 末尾的 `/v1[/]`。
    NSURL *baseUrl = [NSURL URLWithString:apiBaseUrl];
    if (!baseUrl) return @"";
    NSString *path = baseUrl.path ?: @"";
    // 去掉末尾 `/`
    while ([path hasSuffix:@"/"]) path = [path substringToIndex:path.length - 1];
    // 再去掉末尾 `/v1`
    if ([path hasSuffix:@"/v1"]) path = [path substringToIndex:path.length - 3];

    NSString *rel = [relativeUrl hasPrefix:@"/"] ? relativeUrl : [@"/" stringByAppendingString:relativeUrl];
    NSString *scheme = baseUrl.scheme ?: @"https";
    NSString *host = baseUrl.host ?: @"";
    NSString *portSeg = (baseUrl.port && baseUrl.port.integerValue > 0) ? [NSString stringWithFormat:@":%@", baseUrl.port] : @"";
    return [NSString stringWithFormat:@"%@://%@%@%@%@", scheme, host, portSeg, path, rel];
}
