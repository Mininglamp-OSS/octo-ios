// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKDocsViewerSpaceHandoff.h"

static NSNumber *WKEffectivePort(NSURLComponents *components) {
    if (components.port != nil) return components.port;
    NSString *scheme = components.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"]) return @443;
    if ([scheme isEqualToString:@"http"]) return @80;
    return nil;
}

static BOOL WKIsDocsViewerPath(NSString *path) {
    if (path.length == 0) return NO;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^/(?:d/[^/]+|ppt/d/[^/]+|docs/[^/]+/present)/?$"
                                                                                  options:0
                                                                                    error:nil];
    return [expression firstMatchInString:path options:0 range:NSMakeRange(0, path.length)] != nil;
}

BOOL WKIsTrustedDocsViewerURL(NSURL *URL, NSString *apiBaseURL) {
    if (URL == nil || apiBaseURL.length == 0) return NO;

    NSURLComponents *candidate = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    if (candidate.scheme.length == 0 || candidate.host.length == 0 ||
        server.scheme.length == 0 || server.host.length == 0) return NO;

    BOOL sameOrigin = [candidate.scheme.lowercaseString isEqualToString:server.scheme.lowercaseString] &&
        [candidate.host.lowercaseString isEqualToString:server.host.lowercaseString] &&
        [WKEffectivePort(candidate) isEqualToNumber:WKEffectivePort(server)];
    return sameOrigin && WKIsDocsViewerPath(candidate.percentEncodedPath);
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

NSString *WKDocsViewerSpaceJavaScript(NSString *currentSpaceId, NSString *apiBaseURL) {
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    NSString *scheme = server.scheme.lowercaseString ?: @"";
    NSString *host = server.host.lowercaseString ?: @"";
    NSNumber *port = WKEffectivePort(server);
    NSString *action = currentSpaceId.length > 0
        ? [NSString stringWithFormat:@"localStorage.setItem('currentSpaceId',%@);", WKJSONString(currentSpaceId)]
        : @"localStorage.removeItem('currentSpaceId');";
    return [NSString stringWithFormat:
        @"(function(){try{var p=location.protocol.slice(0,-1).toLowerCase(),h=location.hostname.toLowerCase(),n=location.port?Number(location.port):(p==='https'?443:(p==='http'?80:0)),r=/^\\/(?:d\\/[^/]+|ppt\\/d\\/[^/]+|docs\\/[^/]+\\/present)\\/?$/;if(p===%@&&h===%@&&n===%@&&r.test(location.pathname)){%@}}catch(e){}})();",
        WKJSONString(scheme), WKJSONString(host), port ?: @0, action];
}
