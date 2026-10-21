//
//  WKWebViewService.h
//  WuKongBase
//
//  Created by tt on 2023/9/11.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@class WKWebViewJavascriptBridge;
@class WKWebView;

@interface WKWebViewService : NSObject

@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
@property(nonatomic,strong,nullable) WKChannel *channel;
/// 来源守卫参照的 webview（弱引用，VC 生命周期内有效）。
@property(nonatomic,weak,nullable) WKWebView *guardedWebView;

-(void) registerHandlers;

/// 注册统一来源守卫：仅同源页面的 bridge 调用会执行，其余回错误。
/// fail-closed：trustedOrigin 未配置时一律拒绝（非免登入口不开放原生能力）。
- (void)setTrustedOrigin:(nullable NSString *)trustedOrigin;

/// 可测的来源判定纯函数：当前页面 URL + trustedOrigin → 是否放行。
/// trustedOrigin 为空、URL 无 host、组件解析失败、跨域、scheme 或端口
/// （经 WKEffectivePort 默认端口归一）不一致 → NO。测试直接喂 URL，
/// 无需真 WKWebView。
- (BOOL)isOriginAllowedForURL:(nullable NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
