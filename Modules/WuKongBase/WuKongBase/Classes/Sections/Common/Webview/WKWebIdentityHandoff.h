// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 同源 H5 的登录态交接：给 URL 追加 sid、生成 document-start 注入脚本，
/// 把 token/uid/name 写进同 origin 的 localStorage（key 带 sid 分桶，与 web 端
/// SessionScope/LoginInfo 约定一致）。非同源 URL 与 report.html 不注入。
@interface WKWebIdentityHandoff : NSObject

/// 同源且允许注入时返回追加了 ?sid= 的 URL（已有 sid 保留原值），否则返回 nil。
+ (nullable NSURL *)handoffURLForURL:(NSURL *)URL;

/// 与 handoffURLForURL: 配套的 atDocumentStart 注入脚本；URL 未通过判定时返回 nil。
+ (nullable NSString *)identityJavaScriptForURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
