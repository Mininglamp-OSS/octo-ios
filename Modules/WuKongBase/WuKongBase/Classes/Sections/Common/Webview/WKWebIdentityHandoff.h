// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>
#import "WKWebOrigin.h"

NS_ASSUME_NONNULL_BEGIN

// 同源/端口口径（WKEffectivePort / WKSameOrigin）与 JS 转义（WKJSONStringForJS）
// 收敛在 WKWebOrigin.h 单一真值来源（评审 P2：多份手写实现会静默劈开安全口径）。

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

/// 凭证容器准入：同源 + 命中免登路由白名单。只有这类 URL 的容器实例才使用
/// 默认 data store（localStorage 里会有注入的 token）。与 handoffURLForURL:
/// 的区别：本判定不依赖登录态（未登录时 handoffURLForURL: 也返回 nil，
/// 不能作为容器分级依据）。
+ (BOOL)isCredentialContainerURL:(nullable NSURL *)URL;

/// 不可信同源内容：同源但路径落在 API 子树内（apiBaseUrl 的路径前缀下，
/// 如 {api}/file/preview/... 的用户上传 HTML）。这些内容与 API 同源却由
/// 用户产生，一旦在持凭证容器内渲染（含 iframe），可读同源 localStorage
/// 里的 token（评审 P1 WebKit 探针已实测）。此类 URL 不得进容器、不得在
/// 容器内导航到达，应外跳。免登白名单路径优先于本判定（API base 挂根的
/// 部署下无法按路径区分上传内容，此时不启用子树排除，避免误杀 H5 路由）。
+ (BOOL)isUntrustedSameOriginContentURL:(nullable NSURL *)URL;

/// JS 值/键的安全嵌入：经 WKWebOrigin.h 的 WKJSONStringForJS（NSJSONSerialization
/// 序列化单个字符串，含引号、反斜杠、换行、U+2028/U+2029 转义），保证任意值
/// 不越出 JS 字符串字面量。
/// 暴露给测试：注入脚本的所有插值都经它，转义契约需要直接断言（Octo-Q 评审
/// 指出经 sid 替换路径测转义是"恒绿的测试"——恶意值在进转义前已被换成 ios）。
+ (nullable NSString *)JSONString:(nullable NSString *)value;

@end

NS_ASSUME_NONNULL_END
