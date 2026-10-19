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
#import <WebKit/WebKit.h>
@implementation WKWebViewService {
    NSString *_trustedOrigin;
}

- (void)setTrustedOrigin:(NSString *)trustedOrigin {
    _trustedOrigin = trustedOrigin;
}

// 注册带来源守卫的 handler：跨域页面调用直接回错误，不执行真实逻辑。
- (void)registerGuardedHandler:(NSString *)name handler:(WVJBHandler)handler {
    __weak typeof(self) weakSelf = self;
    [self.bridge registerHandler:name handler:^(id data, WVJBResponseCallback responseCallback) {
        if (![weakSelf originAllowed]) {
            responseCallback([WKJsonUtil toJson:@{@"error":@"forbidden"}]);
            return;
        }
        handler(data, responseCallback);
    }];
}

// bridge handler 统一来源守卫：跨域页面（外链/重定向后）调用一律拒绝，
// 原生能力（auth/跳转会话等）不对不可信页面开放。
- (BOOL)originAllowed {
    if (_trustedOrigin.length == 0) return YES;
    WKWebView *webView = self.guardedWebView;
    if (webView.URL.host.length == 0) return NO;
    NSURLComponents *c = [NSURLComponents componentsWithURL:webView.URL resolvingAgainstBaseURL:NO];
    NSURLComponents *t = [NSURLComponents componentsWithString:_trustedOrigin];
    if (c == nil || t == nil) return NO;
    return [c.scheme.lowercaseString isEqualToString:t.scheme.lowercaseString] &&
        [c.host.lowercaseString isEqualToString:t.host.lowercaseString] &&
        (c.port == nil ? t.port == nil : [c.port isEqualToNumber:t.port]);
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
        responseCallback([WKJsonUtil toJson:@{
            @"channel_id": weakSelf.channel && weakSelf.channel.channelId?weakSelf.channel.channelId:@"",
            @"channel_type":@(weakSelf.channel? weakSelf.channel.channelType:0)
        }]);
    }];
    
    // 选择最近会话
    [self registerGuardedHandler:@"chooseConversation" handler:^(id data, WVJBResponseCallback responseCallback) {
        WKForwardSelectVC *vc = [WKForwardSelectVC new];
        vc.title = LLangW(@"选择一个聊天", weakSelf);
        [vc setOnSelect:^(WKChannel * _Nonnull channel) {
            responseCallback([WKJsonUtil toJson:@{
                @"channel_id": channel && channel.channelId?channel.channelId:@"",
                @"channel_type":@(channel? channel.channelType:0)
            }]);
            
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
                    responseCallback([WKJsonUtil toJson:@{@"code":authcode}]);
                    [weakSelf hideUserAuth:authViewWeak];
                    
                }).catch(^(NSError *error){
                    responseCallback([WKJsonUtil toJson:@{@"error":error.domain?:@""}]);
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
