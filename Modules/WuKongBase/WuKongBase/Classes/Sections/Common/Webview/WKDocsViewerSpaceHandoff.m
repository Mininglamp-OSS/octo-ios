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

static NSString *WKViewerRoutePath(NSString *candidatePath, NSString *basePath) {
    NSString *prefix = basePath ?: @"";
    while ([prefix hasSuffix:@"/"]) prefix = [prefix substringToIndex:prefix.length - 1];
    if ([prefix hasSuffix:@"/api/v1"]) {
        prefix = [prefix substringToIndex:prefix.length - [@"/api/v1" length]];
    } else if ([prefix hasSuffix:@"/v1"]) {
        prefix = [prefix substringToIndex:prefix.length - [@"/v1" length]];
    }
    if (prefix.length == 0) return candidatePath;
    if (![candidatePath hasPrefix:prefix]) return nil;
    return [candidatePath substringFromIndex:prefix.length];
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
    return sameOrigin && WKIsDocsViewerPath(WKViewerRoutePath(candidate.percentEncodedPath, server.percentEncodedPath));
}

static NSString *WKJSONString(NSString *value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *arrayJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *valueJSON = arrayJSON.length >= 2 ? [arrayJSON substringWithRange:NSMakeRange(1, arrayJSON.length - 2)] : @"\"\"";
    valueJSON = [valueJSON stringByReplacingOccurrencesOfString:@"<" withString:@"\\u003c"];
    valueJSON = [valueJSON stringByReplacingOccurrencesOfString:@">" withString:@"\\u003e"];
    valueJSON = [valueJSON stringByReplacingOccurrencesOfString:@"&" withString:@"\\u0026"];
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

NSURL *WKViewerHandoffURL(NSURL *URL, NSString *apiBaseURL) {
    if (!URL || apiBaseURL.length == 0) return nil;
    NSURLComponents *candidate = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSURLComponents *server = [NSURLComponents componentsWithString:apiBaseURL];
    if (candidate.user.length || candidate.password.length || candidate.host.length == 0 ||
        server.host.length == 0 ||
        ![@[@"http", @"https"] containsObject:candidate.scheme.lowercaseString] ||
        ![candidate.scheme.lowercaseString isEqualToString:server.scheme.lowercaseString] ||
        ![candidate.host.lowercaseString isEqualToString:server.host.lowercaseString] ||
        ![WKEffectivePort(candidate) isEqualToNumber:WKEffectivePort(server)]) return nil;
    NSString *path = WKViewerRoutePath(candidate.percentEncodedPath ?: @"", server.percentEncodedPath);
    if (path.length == 0) return nil;
    NSRegularExpression *route = [NSRegularExpression regularExpressionWithPattern:
        @"^/(?:s|d)/[A-Za-z0-9_-]{1,128}/?$|^/(?:ppt/d/[A-Za-z0-9_-]{1,128}|docs/[A-Za-z0-9_-]{1,128}/present)/?$"
                                                                        options:0 error:nil];
    if (![route firstMatchInString:path options:0 range:NSMakeRange(0, path.length)]) return nil;
    // Keep non-session query segments encoded exactly as supplied by the link.
    NSString *rawQuery = candidate.percentEncodedQuery;
    NSMutableArray<NSString *> *otherSegments = [NSMutableArray array];
    NSString *selectedSidSegment = nil;
    BOOL firstSidSeen = NO;
    for (NSString *segment in [rawQuery componentsSeparatedByString:@"&"]) {
        NSRange separator = [segment rangeOfString:@"="];
        NSString *rawName = separator.location == NSNotFound ? segment : [segment substringToIndex:separator.location];
        NSString *name = [[rawName stringByReplacingOccurrencesOfString:@"+" withString:@"%20"] stringByRemovingPercentEncoding];
        if ([name isEqualToString:@"sid"]) {
            NSString *rawValue = separator.location == NSNotFound ? @"" : [segment substringFromIndex:separator.location + 1];
            NSString *value = [[rawValue stringByReplacingOccurrencesOfString:@"+" withString:@"%20"] stringByRemovingPercentEncoding];
            if (!firstSidSeen) {
                firstSidSeen = YES;
                if (value.length > 0) return URL;
            }
            if (selectedSidSegment == nil && value.length > 0) selectedSidSegment = segment;
        } else {
            [otherSegments addObject:segment];
        }
    }
    if (!firstSidSeen) {
        candidate.percentEncodedQuery = rawQuery.length > 0
            ? [rawQuery stringByAppendingString:@"&sid=ios"] : @"sid=ios";
    } else {
        [otherSegments addObject:selectedSidSegment ?: @"sid=ios"];
        candidate.percentEncodedQuery = [otherSegments componentsJoinedByString:@"&"];
    }
    return candidate.URL;
}

NSString *WKViewerBootstrapHTML(NSURL *URL, NSString *token, NSString *uid, NSString *name,
                                NSString *spaceId, BOOL isDocsViewer) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    // Query parameters use form decoding: raw '+' is a space, while '%2B' is a plus.
    components.percentEncodedQuery = [components.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%20"];
    NSString *sid = @"ios";
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"sid"]) {
            if (item.value.length > 0) sid = item.value;
            break;
        }
    }
    NSMutableString *script = [NSMutableString stringWithString:@"try{"];
    if (isDocsViewer) {
        if (spaceId.length > 0) [script appendFormat:@"localStorage.setItem('currentSpaceId',%@);", WKJSONString(spaceId)];
        else [script appendString:@"localStorage.removeItem('currentSpaceId');"];
    }
    if (token.length > 0 && uid.length > 0) {
        [script appendFormat:@"var s=%@;localStorage.setItem('token'+s,%@);localStorage.setItem('uid'+s,%@);localStorage.setItem('name'+s,%@);",
            WKJSONString(sid), WKJSONString(token), WKJSONString(uid), WKJSONString(name ?: @"")];
    } else {
        [script appendFormat:@"var s=%@;localStorage.removeItem('token'+s);localStorage.removeItem('uid'+s);localStorage.removeItem('name'+s);",
            WKJSONString(sid)];
    }
    [script appendFormat:@"}catch(e){}window.location.replace(%@);", WKJSONString(URL.absoluteString)];
    return [NSString stringWithFormat:@"<!DOCTYPE html><html><head><meta charset=\"UTF-8\"></head><body><script>(function(){%@})();</script></body></html>", script];
}
