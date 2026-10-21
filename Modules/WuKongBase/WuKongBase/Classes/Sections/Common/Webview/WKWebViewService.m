//
//  WKWebViewService.m
//  WuKongBase
//
//  Created by tt on 2023/9/11.
//

#import "WKWebViewService.h"
#import "WuKongBase.h"
#import "WKForwardSelectVC.h"
#import "WKUserAuthView.h"
#import "WKWebViewJavascriptBridge.h"
#import "WKWebIdentityHandoff.h"
#import <WebKit/WebKit.h>
@implementation WKWebViewService {
    NSString *_trustedOrigin;
}

- (void)setTrustedOrigin:(NSString *)trustedOrigin {
    _trustedOrigin = trustedOrigin;
}

// 注册带来源守卫的 handler：跨域页面调用直接回错误，不执行真实逻辑。
// responseCallback 可能为 NULL：vendored bridge 对未带 callback 的调用
// （如无回包约定的 quit/showConversation）传的是 NULL 而非 no-op block
// （WebViewJavascriptBridgeBase.m 只在 callbackId 存在时才赋值），
// 回包前必须判空，否则守卫拒绝路径直接 EXC_BAD_ACCESS。
- (void)registerGuardedHandler:(NSString *)name handler:(WVJBHandler)handler {
    __weak typeof(self) weakSelf = self;
    [self.bridge registerHandler:name handler:^(id data, WVJBResponseCallback responseCallback) {
        if (![weakSelf originAllowed]) {
            if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"error":@"forbidden"}]);
            return;
        }
        handler(data, responseCallback);
    }];
}

// bridge handler 统一来源守卫：跨域页面（外链/重定向后）调用一律拒绝，
// 原生能力（auth/跳转会话等）不对不可信页面开放。
// fail-closed：trustedOrigin 未配置（nil/空）时一律拒绝 —— 免登入口由
// WKWebViewVC 按 handoffURL 配置 trustedOrigin，非免登入口（纯外链/老入口）
// 本就不应开放原生能力；若未来某入口确需在非同源页面开放 bridge，必须在该
// 入口显式配置 trustedOrigin，不允许回退到"默认信任"。
- (BOOL)originAllowed {
    if (_trustedOrigin.length == 0) return NO;
    // guardedWebView 是 weak 引用，VC 释放后为 nil —— nil 时无 URL 可判，
    // 保持 fail-closed（走 isOriginAllowedForURL: 的空 URL 分支返回 NO）。
    return [self isOriginAllowedForURL:self.guardedWebView.URL];
}

// 可测的纯判定：给定"当前页面 URL + trustedOrigin"输出是否放行。
// 测试直接喂 URL，不需要真 WKWebView（见 WKWebViewServiceOriginTests）。
- (BOOL)isOriginAllowedForURL:(NSURL *)URL {
    if (_trustedOrigin.length == 0) return NO;
    if (URL.host.length == 0) return NO;
    NSURLComponents *c = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSURLComponents *t = [NSURLComponents componentsWithString:_trustedOrigin];
    if (c == nil || t == nil) return NO;
    // 端口必须经 WKEffectivePort 归一（与 WKSameOrigin 同口径）：trustedOrigin
    // 总是显式带 :443/:80，页面 URL 通常省略默认端口，裸比原始值会误拒全部合法页面。
    return [c.scheme.lowercaseString isEqualToString:t.scheme.lowercaseString] &&
        [c.host.lowercaseString isEqualToString:t.host.lowercaseString] &&
        [WKEffectivePort(c) isEqualToNumber:WKEffectivePort(t)];
}

- (void)registerHandlers {
    __weak typeof(self) weakSelf = self;

    // 统一包裹：先过来源守卫再进真实 handler。
    [self registerGuardedHandler:@"quit" handler:^(id data, WVJBResponseCallback responseCallback) {
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }];

//    // 提交投诉
//    [self.bridge
//        registerHandler:@"commitReports"
//                handler:^(id data, WVJBResponseCallback responseCallback) {
//                    if ([data isKindOfClass:[NSDictionary class]]) {
//
//                    }
//     }];
    
    // 获取当前频道
    [self registerGuardedHandler:@"getChannel" handler:^(id data, WVJBResponseCallback responseCallback) {
        // 页面可能不带回调调 getChannel（与 quit/showConversation 同类调用方），
        // 与守卫拒绝路径同理：回包前必须判空，否则 NULL block 调用直接崩溃。
        if (responseCallback) responseCallback([WKJsonUtil toJson:@{
            @"channel_id": weakSelf.channel && weakSelf.channel.channelId?weakSelf.channel.channelId:@"",
            @"channel_type":@(weakSelf.channel? weakSelf.channel.channelType:0)
        }]);
    }];
    
    // 选择最近会话
    [self registerGuardedHandler:@"chooseConversation" handler:^(id data, WVJBResponseCallback responseCallback) {
        WKForwardSelectVC *vc = [WKForwardSelectVC new];
        vc.title = LLangW(@"选择一个聊天", weakSelf);
        [vc setOnSelect:^(WKChannel * _Nonnull channel) {
            // 异步窗口二次校验：选择器弹出期间页面可能已导航到跨域页面
            // （外链/重定向），channel 数据不得交给导航后的不可信页面。
            // 与 auth 的异步二次校验同型（评审 P1：回调只回包未复查来源）。
            if (![weakSelf originAllowed]) {
                if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"error":@"forbidden"}]);
            } else {
                // onSelect 回包同样判空：chooseConversation 可被无回调调用，
                // 选完会话时 responseCallback 已是 NULL。
                if (responseCallback) responseCallback([WKJsonUtil toJson:@{
                    @"channel_id": channel && channel.channelId?channel.channelId:@"",
                    @"channel_type":@(channel? channel.channelType:0)
                }]);
            }

            [[WKNavigationManager shared] popViewControllerAnimated:YES];


        }];
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }];
    
    // 显示最近会话
    [self registerGuardedHandler:@"showConversation" handler:^(id data, WVJBResponseCallback responseCallback) {
        if(!data) {
            return;
        }
        
        WKConversationVC *conversationVC =  [WKConversationVC new];
        conversationVC.channel = [WKChannel channelID:data[@"channel_id"] channelType:[data[@"channel_type"] intValue]];
        if(data[@"forward"] && [data[@"forward"] isEqualToString:@"replace"]) {
            [[WKNavigationManager shared] replacePushViewController:conversationVC animated:YES];
        }else{
            [[WKNavigationManager shared] pushViewController:conversationVC animated:YES];
        }
    }];
    
    [self registerGuardedHandler:@"auth" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"auth......");
        
        NSString *appID = data[@"app_id"];
        if(!appID || [appID isEqualToString:@""]) {
            [WKNavigationManager.shared.topViewController.view showHUDWithHide:LLang(@"app_id不能为空！")];
            return;
        }
        UIView *topView = WKNavigationManager.shared.topViewController.view;
        [topView showHUD];
        [WKAPIClient.sharedClient GET:[NSString stringWithFormat:@"apps/%@",appID] parameters:nil].then(^(NSDictionary *resultDict){
            [topView hideHud];
            WKUserAuthView *authView = [weakSelf showUserAuth:resultDict];
            __weak typeof(authView) authViewWeak = authView;
            [authView setOnAllow:^{
                [weakSelf getAuthCode:appID].then(^(NSString*authcode){
                    // 异步窗口二次校验：入口检查后页面可能已导航到跨域页面
                    // （外链/重定向），authcode 不得交给导航后的不可信页面。
                    // responseCallback 判空同 registerGuardedHandler 注释。
                    if (![weakSelf originAllowed]) {
                        if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"error":@"forbidden"}]);
                    } else {
                        if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"code":authcode}]);
                    }
                    [weakSelf hideUserAuth:authViewWeak];

                }).catch(^(NSError *error){
                    // 失败分支同样二次校验：错误信息也不可泄漏给跨域页面。
                    if (![weakSelf originAllowed]) {
                        if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"error":@"forbidden"}]);
                    } else {
                        if (responseCallback) responseCallback([WKJsonUtil toJson:@{@"error":error.domain?:@""}]);
                    }
                });
            }];
        }).catch(^(NSError *error){
            [topView switchHUDError:error.domain];
        });
        
    
    }];
}

-(AnyPromise*) getAuthCode:(NSString*)appID{
    
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolver) {
        [WKAPIClient.sharedClient GET:@"openapi/authcode" parameters:@{@"app_id":appID}].then(^(NSDictionary *resultDic){
            NSString *authcode = resultDic[@"authcode"];
            resolver(authcode);
        }).catch(^(NSError *error){
            resolver(error);
        });
    }];
    
}

-(WKUserAuthView*) showUserAuth:(NSDictionary*)resultDict {
    NSString *appName = resultDict[@"app_name"]?:@"";
    NSString *appLogo = resultDict[@"app_logo"]?:@"";
    __weak typeof(self) weakSelf = self;
    WKUserAuthView *authView = [[WKUserAuthView alloc] init];
    authView.appName = appName;
    authView.appLogo = appLogo;
    authView.alpha = 0.0f;
    __weak typeof(authView) authViewWeak = authView;
    authView.onClose = ^{
        [weakSelf hideUserAuth:authViewWeak];
    };
   
    UIWindow *wd = [WKApp.shared findWindow];
    [wd addSubview:authView];
    [UIView animateWithDuration:0.25f animations:^{
        authView.show = true;
        authView.alpha = 1.0f;
        [authView layoutSubviews];
    }];
    
    return authView;
    
}

-(void) hideUserAuth:(WKUserAuthView*)authView {
    authView.alpha = 1.0f;
    [UIView animateWithDuration:0.25f animations:^{
        authView.show = false;
        authView.alpha = 0.0f;
        [authView layoutSubviews];
    } completion:^(BOOL finished) {
        [authView removeFromSuperview];
    }];
}

@end
