// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 默认端口归一：未显式写端口时按 scheme 补 443/80；非 HTTP(S) 返回 nil。
/// 返回 nil 属正常分支（非 HTTP(S) 无默认端口概念），调用方按"不同源"处理。
/// 这是本模块内同源判断的唯一端口口径 —— WKSameOrigin / bridge 来源守卫 /
/// 注入 JS 运行时守卫都必须经它比较端口，禁止各处裸比 port 原始值
/// （否则 https://a.com 与 https://a.com:443 会被误判为不同源）。
static inline NSNumber * _Nullable WKEffectivePort(NSURLComponents *components) {
    if (components.port != nil) return components.port;
    NSString *scheme = components.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"]) return @443;
    if ([scheme isEqualToString:@"http"]) return @80;
    return nil;
}

/// 同源判断（scheme + host + 归一端口）。注意：非 HTTP(S) 的 origin 端口均为
/// nil，objc 对 nil 消息返回 NO，即非 HTTP(S) 一律判不同源 —— 有意 fail-closed。
static inline BOOL WKSameOrigin(NSURLComponents *a, NSURLComponents *b) {
    return [a.scheme.lowercaseString isEqualToString:b.scheme.lowercaseString] &&
        [a.host.lowercaseString isEqualToString:b.host.lowercaseString] &&
        [WKEffectivePort(a) isEqualToNumber:WKEffectivePort(b)];
}

/// 同源 H5 的登录态交接：给 URL 追加 sid、生成 document-start 注入脚本，
/// 把 token/uid/name 写进同 origin 的 localStorage（key 带 sid 分桶，与 web 端
/// SessionScope/LoginInfo 约定一致）。非同源 URL 与 report 页面不注入。
@interface WKWebIdentityHandoff : NSObject

/// 同源且允许注入时返回追加了 ?sid= 的 URL（已有 sid 一律替换为 ios），否则返回 nil。
+ (nullable NSURL *)handoffURLForURL:(NSURL *)URL;

/// 与 handoffURLForURL: 配套的 atDocumentStart 注入脚本；URL 未通过判定时返回 nil。
+ (nullable NSString *)identityJavaScriptForURL:(NSURL *)URL;

/// 链接离开 App 边界（复制/分享/外部浏览器）前清除内部分桶标记：仅对
/// 「同源 + 免登路由白名单」的 URL 剥 sid（这种 URL 上的 sid 必然是 native
/// 注入的）；其它 URL 原样返回，不碰第三方页面自带的同名业务参数。
+ (NSURL *)sanitizedURLForExternalUse:(NSURL *)URL;

/// 可信 origin（apiBaseUrl 的 scheme://host:port 归一形态）；配置缺失时返回 nil。
+ (nullable NSString *)trustedOrigin;

/// 容器路由判定（与身份注入解耦）：URL 是否同源 http(s)。同源即可进容器，
/// 免登注入范围由 handoffURLForURL: 的白名单单独决定（评审 P1：两个概念
/// 共用一个判定会把同源白名单外页面挤到外部浏览器）。配置缺失返回 NO。
+ (BOOL)isSameOriginAsAPIBase:(NSURL *)URL;

/// JS 值/键的安全嵌入：NSJSONSerialization 序列化单个字符串（含引号、反斜杠、
/// 换行、U+2028/U+2029 转义），保证任意值不越出 JS 字符串字面量。
/// 暴露给测试：注入脚本的所有插值都经它，转义契约需要直接断言（Octo-Q 评审
/// 指出经 sid 替换路径测转义是"恒绿的测试"——恶意值在进转义前已被换成 ios）。
+ (NSString *)JSONString:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
