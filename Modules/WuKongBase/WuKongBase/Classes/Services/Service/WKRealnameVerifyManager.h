//
//  WKRealnameVerifyManager.h
//  WuKongBase
//
//  OCTO 实名认证前端接入（Aegis OIDC Phase 2c — 账户页直跳）
//
//  流程：
//    1) 用户点击「去认证」 → 直接用 SFSafariViewController 打开 Aegis 账户页
//       （https://accounts.example.com/profile/info?anchor=verification）
//    2) 用户在 Aegis 页面完成实名认证 → Aegis return_to 302 回 octo://verified
//    3) AppDelegate 捕获 URL，调用 [WKRealnameVerifyManager handleVerifiedCallback:]
//    4) 本 Manager 从后端重新拉取 profile，更新 WKLoginInfo 并广播 WKNOTIFY_REALNAME_VERIFIED
//
//  老版本兜底：dmworkim `/internal/verify-token` 翻译接口仍在线，会返回 Aegis URL，
//  老 App 走旧 verify-token 路径同样可以抵达 Aegis。新版本直接省掉这一跳。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 实名认证 deep-link（Universal Link scheme）
/// 与 verify-service 的 return_to 参数一致；
/// 同时必须在 TangSengDaoDao/Info.plist CFBundleURLSchemes 登记 "dmwork"。
extern NSString *const WKRealnameVerifiedURLScheme;   // @"dmwork"
extern NSString *const WKRealnameVerifiedURLHost;     // @"verified"

@interface WKRealnameVerifyManager : NSObject

+ (instancetype)shared;

/// 判断一个 URL 是否是实名认证回跳（octo://verified）
/// AppDelegate 的 application:openURL:options: 和
/// application:continueUserActivity:restorationHandler: 均应先调用这里。
+ (BOOL)isVerifiedCallbackURL:(NSURL *)url;

/// 处理 octo://verified 回跳：
///   - 从后端重新拉取 user/current，更新 loginInfo.realnameVerified / realName
///   - 发送 WKNOTIFY_REALNAME_VERIFIED 通知
+ (void)handleVerifiedCallback:(NSURL *)url;

/// 在指定 VC 上打开实名认证入口。
/// 直接 present 一个 SFSafariViewController 打开 Aegis 账户页
/// （https://accounts.example.com/profile/info?anchor=verification），不再经过
/// 后端 /internal/verify-token 翻译。用户在 Aegis 页完成认证后通过
/// octo://verified 兜底 scheme 回跳本 App。
- (void)startVerificationFromVC:(UIViewController *)fromVC;

@end

NS_ASSUME_NONNULL_END
