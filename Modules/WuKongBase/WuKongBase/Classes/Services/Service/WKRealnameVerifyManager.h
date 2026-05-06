//
//  WKRealnameVerifyManager.h
//  WuKongBase
//
//  OCTO 实名认证前端接入（方案 J v3）
//
//  流程：
//    1) 用户点击「去认证」 → POST /v1/internal/verify-token 拿到 verify_url
//    2) 用 SFSafariViewController 打开 verify_url，return_to = octo://verified
//    3) Safari 完成实名认证后 302 回 octo://verified
//    4) AppDelegate 捕获 URL，调用 [WKRealnameVerifyManager handleVerifiedCallback:]
//    5) 本 Manager 从后端重新拉取 profile，更新 WKLoginInfo 并广播 WKNOTIFY_REALNAME_VERIFIED
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
/// 成功：内部会 present 一个 SFSafariViewController 到 verify_url。
/// 失败：在 fromVC.view 上 Toast 错误。
- (void)startVerificationFromVC:(UIViewController *)fromVC;

@end

NS_ASSUME_NONNULL_END
