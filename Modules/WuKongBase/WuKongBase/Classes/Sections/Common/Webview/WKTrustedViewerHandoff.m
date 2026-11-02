// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKTrustedViewerHandoff.h"

static NSString *const WKViewerSid = @"ios-viewer";
NSNotificationName const WKTrustedViewerSessionDidChangeNotification = @"WKTrustedViewerSessionDidChangeNotification";

static NSRegularExpression *WKViewerPathPattern(void) {
    static NSRegularExpression *pattern;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pattern = [NSRegularExpression regularExpressionWithPattern:@"^/(?:s/[A-Za-z0-9_-]{1,128}|d/[A-Za-z0-9_-]{1,128}|ppt/d/[A-Za-z0-9_-]{1,128}|docs/[A-Za-z0-9_-]{1,128}/present)/?$"
                                                               options:0 error:nil];
    });
    return pattern;
}

static NSNumber *WKViewerPort(NSURLComponents *components) {
    if (components.port) return components.port;
    if ([components.scheme.lowercaseString isEqualToString:@"https"]) return @443;
    if ([components.scheme.lowercaseString isEqualToString:@"http"]) return @80;
    return nil;
}

static BOOL WKViewerSameOrigin(NSURLComponents *candidate, NSString *baseURL) {
    NSURLComponents *base = [NSURLComponents componentsWithString:baseURL];
    if (base.host.length == 0 || base.scheme.length == 0) return NO;
    return [candidate.scheme.lowercaseString isEqualToString:base.scheme.lowercaseString]
        && [candidate.host.lowercaseString isEqualToString:base.host.lowercaseString]
        && [WKViewerPort(candidate) isEqualToNumber:WKViewerPort(base)];
}

BOOL WKIsSameViewerOriginURL(NSURL *URL, NSURL *referenceURL) {
    if (!URL || !referenceURL) return NO;
    NSURLComponents *candidate = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    return WKViewerSameOrigin(candidate, referenceURL.absoluteString);
}

BOOL WKIsTrustedViewerURL(NSURL *URL, NSString *apiBaseURL) {
    if (!URL) return NO;
    NSURLComponents *candidate = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSString *scheme = candidate.scheme.lowercaseString;
    NSString *path = candidate.percentEncodedPath;
    if ((![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        || candidate.host.length == 0 || candidate.user.length > 0 || candidate.password.length > 0
        || ![WKViewerPathPattern() firstMatchInString:path ?: @"" options:0 range:NSMakeRange(0, path.length)]) return NO;
    return WKViewerSameOrigin(candidate, apiBaseURL);
}

NSURL *WKTrustedViewerHandoffURL(NSURL *URL, NSString *apiBaseURL) {
    if (!WKIsTrustedViewerURL(URL, apiBaseURL)) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![item.name isEqualToString:@"sid"]) [items addObject:item];
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"sid" value:WKViewerSid]];
    components.queryItems = items;
    return components.URL;
}

static NSString *WKViewerJSONString(NSString *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *array = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (array.length < 2) return @"\"\"";
    NSString *escaped = [array substringWithRange:NSMakeRange(1, array.length - 2)];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"\\u003c"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"\\u003e"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"&" withString:@"\\u0026"];
    escaped = [escaped stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2028] withString:@"\\u2028"];
    return [escaped stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2029] withString:@"\\u2029"];
}

NSString *WKTrustedViewerIdentityScript(NSURL *URL, NSString *token, NSString *uid, NSString *name, NSString *spaceId) {
    if (!URL || token.length == 0 || uid.length == 0) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSString *spaceAction = spaceId.length > 0
        ? [NSString stringWithFormat:@"localStorage.setItem('currentSpaceId',%@);localStorage.setItem('octo:last-space:'+encodeURIComponent(%@),%@);",
            WKViewerJSONString(spaceId), WKViewerJSONString(uid), WKViewerJSONString(spaceId)]
        : @"localStorage.removeItem('currentSpaceId');";
    return [NSString stringWithFormat:
        @"(function(){try{var p=location.protocol.slice(0,-1).toLowerCase(),h=location.hostname.toLowerCase(),n=location.port?Number(location.port):(p==='https'?443:80);if(p!==%@||h!==%@||n!==%@||!/^\\/(?:s\\/[A-Za-z0-9_-]{1,128}|d\\/[A-Za-z0-9_-]{1,128}|ppt\\/d\\/[A-Za-z0-9_-]{1,128}|docs\\/[A-Za-z0-9_-]{1,128}\\/present)\\/?$/.test(location.pathname))return;localStorage.setItem('token'+%@,%@);localStorage.setItem('uid'+%@,%@);localStorage.setItem('name'+%@,%@);sessionStorage.setItem('octo.session.sid',%@);%@}catch(e){}})();",
        WKViewerJSONString(components.scheme.lowercaseString), WKViewerJSONString(components.host.lowercaseString), WKViewerPort(components),
        WKViewerJSONString(WKViewerSid), WKViewerJSONString(token),
        WKViewerJSONString(WKViewerSid), WKViewerJSONString(uid),
        WKViewerJSONString(WKViewerSid), WKViewerJSONString(name ?: @""),
        WKViewerJSONString(WKViewerSid), spaceAction];
}
