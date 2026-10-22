// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

// WebView 域的统一 origin / scheme 口径（评审 P2：同源判断此前在
// WKWebIdentityHandoff / WKDocsViewerSpaceHandoff / WKWebViewService 各写一份、
// scheme 归一在三处调用点各补一刀，任一份漏改就静默劈开安全口径——本头文件
// 是唯一的真值来源，四类消费方一律经这里，禁止再手写 scheme/host/port 比较）。
//
// 消费方与职责：
// - WKWebIdentityHandoff   凭证注入（严格 WKSameOrigin）+ 容器分级
// - WKWebViewService       bridge 来源守卫（严格 WKSameOrigin）
// - WKWebViewVC            scheme 缺失兜底（WKFallbackSchemeForConfig）
// - 链接/卡片入口          裸域名补 scheme（同上；跟随 httpsOn 而非硬编码）

#import <Foundation/Foundation.h>
#import "WuKongBase.h"

NS_ASSUME_NONNULL_BEGIN

// WKServerConfig（httpsOn）经 umbrella header 引入；WuKongBase.h 自身也
// 引用本域的若干头，依赖方向稳定。

/// 默认端口归一：未显式写端口时按 scheme 补 443/80；非 HTTP(S) 返回 nil。
/// 返回 nil 属正常分支（非 HTTP(S) 无默认端口概念），调用方按"不同源"处理。
static inline NSNumber * _Nullable WKEffectivePort(NSURLComponents *components) {
    if (components.port != nil) return components.port;
    NSString *scheme = components.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"]) return @443;
    if ([scheme isEqualToString:@"http"]) return @80;
    return nil;
}

/// 同源判断（scheme + host + 归一端口），安全控件的唯一口径。注意：非 HTTP(S)
/// 的 origin 端口均为 nil，objc 对 nil 消息返回 NO，即非 HTTP(S) 一律判不同源
/// —— 有意 fail-closed。
static inline BOOL WKSameOrigin(NSURLComponents *a, NSURLComponents *b) {
    return [a.scheme.lowercaseString isEqualToString:b.scheme.lowercaseString] &&
        [a.host.lowercaseString isEqualToString:b.host.lowercaseString] &&
        [WKEffectivePort(a) isEqualToNumber:WKEffectivePort(b)];
}

/// JS 字符串字面量的安全嵌入：NSJSONSerialization 序列化单个字符串（含引号、
/// 反斜杠、换行、U+2028/U+2029 转义），保证任意值不越出 JS 字符串字面量。
/// 供注入脚本与 WKDocsViewerSpaceHandoff 共用；转义契约有直接断言测试。
static inline NSString *WKJSONStringForJS(NSString * _Nullable value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value ?: @""] options:0 error:nil];
    NSString *arrayJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *valueJSON = arrayJSON.length >= 2 ? [arrayJSON substringWithRange:NSMakeRange(1, arrayJSON.length - 2)] : @"\"\"";
    valueJSON = [valueJSON stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2028]
                                                     withString:@"\\u2028"];
    return [valueJSON stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", (unichar)0x2029]
                                                withString:@"\\u2029"];
}

/// scheme 缺失时的兜底 scheme：跟随部署配置（httpsOn 一等公民开关），不硬编码。
/// 评审 P1：硬编码 https:// 会让 HTTP 部署对纯 http 端口做 TLS 握手白屏、
/// 且 origin 与 bridge 守卫的 trustedOrigin 失配导致 handler 全 forbidden。
/// 评审 P2：上游裸域名硬编码 http:// 同理劈开 https 部署的容器/注入判定。
static inline NSString *WKFallbackSchemeForConfig(void) {
    return [WKServerConfig httpsOn] ? @"https" : @"http";
}

/// 裸域名/无 scheme 字符串补全为绝对 URL；已有 scheme（大小写不敏感）原样返回。
/// 统一供三处入口（WKWebViewVC 兜底、链接卡片、didLinkClick）调用。
static inline NSString *WKURLStringWithFallbackScheme(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    // 大小写不敏感：HTTPS:// 也视为已带 scheme，避免被误拼成 http://HTTPS://…。
    if ([urlString.lowercaseString hasPrefix:@"http"]) return urlString;
    return [NSString stringWithFormat:@"%@://%@", WKFallbackSchemeForConfig(), urlString];
}

NS_ASSUME_NONNULL_END
