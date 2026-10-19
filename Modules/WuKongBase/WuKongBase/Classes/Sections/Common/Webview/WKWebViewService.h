//
//  WKWebViewService.h
//  WuKongBase
//
//  Created by tt on 2023/9/11.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WebKit/WebKit.h>
NS_ASSUME_NONNULL_BEGIN

@class WKWebViewJavascriptBridge;

@interface WKWebViewService : NSObject

@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
@property(nonatomic,strong,nullable) WKChannel *channel;
/// 来源守卫参照的 webview（弱引用，VC 生命周期内有效）。
@property(nonatomic,weak,nullable) WKWebView *guardedWebView;

-(void) registerHandlers;

/// 注册统一来源守卫：仅同源页面的 bridge 调用会执行，其余回错误。
- (void)setTrustedOrigin:(nullable NSString *)trustedOrigin;

@end

NS_ASSUME_NONNULL_END
