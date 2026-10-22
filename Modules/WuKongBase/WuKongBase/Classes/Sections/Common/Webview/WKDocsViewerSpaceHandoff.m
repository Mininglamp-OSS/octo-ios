// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import "WKDocsViewerSpaceHandoff.h"
#import "WKWebOrigin.h"

// WKEffectivePort / WKSameOrigin / WKJSONStringForJS 统一取自 WKWebOrigin.h
//（评审 P2：同源与转义口径单一真值来源，不再各留一份 static 拷贝）。

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

    return WKSameOrigin(candidate, server) && WKIsDocsViewerPath(candidate.percentEncodedPath);
}

NSString *WKDocsViewerSpaceJavaScript(NSString *currentSpaceId, NSString *apiBaseURL) {
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    NSString *scheme = server.scheme.lowercaseString ?: @"";
    NSString *host = server.host.lowercaseString ?: @"";
    NSNumber *port = WKEffectivePort(server);
    NSString *action = currentSpaceId.length > 0
        ? [NSString stringWithFormat:@"localStorage.setItem('currentSpaceId',%@);", WKJSONStringForJS(currentSpaceId)]
        : @"localStorage.removeItem('currentSpaceId');";
    return [NSString stringWithFormat:
        @"(function(){try{var p=location.protocol.slice(0,-1).toLowerCase(),h=location.hostname.toLowerCase(),n=location.port?Number(location.port):(p==='https'?443:(p==='http'?80:0)),r=/^\\/(?:d\\/[^/]+|ppt\\/d\\/[^/]+|docs\\/[^/]+\\/present)\\/?$/;if(p===%@&&h===%@&&n===%@&&r.test(location.pathname)){%@}}catch(e){}})();",
        WKJSONStringForJS(scheme), WKJSONStringForJS(host), port ?: @0, action];
}
