//
//  WKRealnameVerifyManager.h
//  WuKongBase
//
//  OCTO 实名认证前端接入（Aegis OIDC Phase 2c — 账户页直跳）
//
//  流程：
//    1) 用户点击「去认证」 → 用 SFSafariViewController 打开 Aegis 账户页
//       实名认证锚点。URL 的 host 部分由后端 `/v1/common/appconfig` 下发的
//       `oidc_providers[].account_url` 字段给出（按环境不同：
//        im-test 会是 accounts-test.your.server.example.com, im-prod 会是 accounts.your.server.example.com）,
//       path/fragment 固定为 /profile/info?anchor=verification。
//       客户端不再硬编码 Aegis 域名（/ ）。
//    2) 用户在 Aegis 页面完成实名认证 → Aegis return_to 302 回 octo://verified
//    3) AppDelegate 捕获 URL，调用 [WKRealnameVerifyManager handleVerifiedCallback:]
//    4) 本 Manager 从后端重新拉取 profile，更新 WKLoginInfo 并广播 WKNOTIFY_REALNAME_VERIFIED
//
//  老版本兜底：dmworkim `/internal/verify-token` 翻译接口仍在线，会返回按环境下发的
//  Aegis URL，老 App 走旧 verify-token 路径同样可以抵达 Aegis。新版本直接省掉这一跳。
//
//  回跳通道（Round 2 / Jerry-Xin #112 review blocking 2 后定稿）:
//    只走自定义 scheme `octo://verified`, **不走 Universal Link**。
//    Universal Link 要求 Aegis host 在 .entitlements 的 associated-domains
//    applinks:* 列表里, 但 Aegis host 是按环境下发的、未来还会新增（staging 等）,
//    entitlement 静态列表 vs 后端动态下发 在架构上互相冲突; 同时 Aegis 侧还要
//    为每个 host 持有 AASA 文件, 运维成本高, 不符合 「去硬编码」原意。
//    所以 iOS 和 Android / Web 端同样走 app scheme: Aegis return_to=octo://verified.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 实名认证 deep-link（自定义 URL scheme）
/// 与 verify-service 的 return_to 参数一致；
/// 值在运行时从 Info.plist OCTOURLScheme（OctoConfig.xcconfig 注入）读取，
/// 默认 "octo"。需在 Info.plist CFBundleURLSchemes 同步登记。
extern NSString *WKRealnameVerifiedURLScheme;
extern NSString *const WKRealnameVerifiedURLHost;     // @"verified"

@interface WKRealnameVerifyManager : NSObject

+ (instancetype)shared;

/// 判断一个 URL 是否是实名认证回跳：
///   - 仅识别自定义 scheme `octo://verified`
///   - Universal Link (`https://<aegisHost>/verified`) **不识别** —— 参见文件头
///     注释关于 entitlement 与动态下发 host 的架构冲突说明。
///
/// AppDelegate 的 application:openURL:options: 和（为保持兼容）
/// application:continueUserActivity:restorationHandler: 均应先调用这里。
/// 后者现在永远返回 NO, 让系统把 web URL 交给其它模块。
+ (BOOL)isVerifiedCallbackURL:(NSURL *)url;

/// 处理 octo://verified 回跳：
///   - 从后端重新拉取 user/current，更新 loginInfo.realnameVerified / realName
///   - 发送 WKNOTIFY_REALNAME_VERIFIED 通知
+ (void)handleVerifiedCallback:(NSURL *)url;

/// 在指定 VC 上打开实名认证入口。
/// 从 appconfig.oidc_providers 里读 account_url, 拼 Aegis 账户页 URL
/// `<account_url>/profile/info?anchor=verification` 并用 SFSafariViewController 打开。
/// appconfig 未下发可用 account_url 时弹 toast, 不跳任何硬编码域。
/// 用户在 Aegis 页完成认证后通过 octo://verified 回跳本 App。
- (void)startVerificationFromVC:(UIViewController *)fromVC;

/// 内部可测试接口 — 由 accountUrl 拼实名认证 URL 并做 https/host/query/fragment
/// 安全守卫。query / fragment 守卫与 WKOidcProviderConfig.sanitizeHttpsURL: 同步,
/// 是 defense-in-depth（R3 suggestion 1）, 防止外部绕过 parser 直接传
/// 带 query / fragment 的 accountUrl 导致拼出语义歧义 URL。
/// 供单测 WKRealnameVerifyURLBuilderTests 覆盖 URL 拼接合约。
+ (nullable NSURL *)buildVerifyURLFromAccountUrl:(nullable NSString *)accountUrl;

@end

NS_ASSUME_NONNULL_END
