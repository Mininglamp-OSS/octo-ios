// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 同源 H5 的登录态交接：给 URL 追加 sid、生成 document-start 注入脚本，
/// 把 token/uid/name 写进同 origin 的 localStorage（key 带 sid 分桶，与 web 端
/// SessionScope/LoginInfo 约定一致）。非同源 URL 与 report 页面不注入。
@interface WKWebIdentityHandoff : NSObject

/// 同源且允许注入时返回追加了 ?sid= 的 URL（已有 sid 一律替换为 ios），否则返回 nil。
+ (nullable NSURL *)handoffURLForURL:(NSURL *)URL;

/// 与 handoffURLForURL: 配套的 atDocumentStart 注入脚本；URL 未通过判定时返回 nil。
+ (nullable NSString *)identityJavaScriptForURL:(NSURL *)URL;

/// 剥掉 URL 上的 sid 参数，用于链接离开 App 边界（复制/分享/外部浏览器）前清除
/// 内部分桶标记。
+ (NSURL *)sanitizedURLForExternalUse:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
