//
//  WKWebViewService.m
//  WuKongBase
//
//  Created by tt on 2023/9/11.
//

#import "WKWebViewService.h"
#import "WuKongBase.h"
#import "WKConversationListSelectVC.h"
#import "WKUserAuthView.h"
#import "WKWebViewJavascriptBridge.h"
@implementation WKWebViewService

- (void)registerHandlers {
    __weak typeof(self) weakSelf = self;
    
//    // 提交投诉
//    [self.bridge
//        registerHandler:@"commitReports"
//                handler:^(id data, WVJBResponseCallback responseCallback) {
//                    if ([data isKindOfClass:[NSDictionary class]]) {
//
//                    }
//     }];
    
    // 退出webview
    [self.bridge registerHandler:@"quit" handler:^(id data, WVJBResponseCallback responseCallback) {
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }];
    
    // 获取当前频道
    [self.bridge registerHandler:@"getChannel" handler:^(id data, WVJBResponseCallback responseCallback) {
        responseCallback([WKJsonUtil toJson:@{
            @"channel_id": weakSelf.channel && weakSelf.channel.channelId?weakSelf.channel.channelId:@"",
            @"channel_type":@(weakSelf.channel? weakSelf.channel.channelType:0)
        }]);
    }];
    
    // 选择最近会话
    [self.bridge registerHandler:@"chooseConversation" handler:^(id data, WVJBResponseCallback responseCallback) {
        WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
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
    [self.bridge registerHandler:@"showConversation" handler:^(id data, WVJBResponseCallback responseCallback) {
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
    
    [self.bridge registerHandler:@"auth" handler:^(id data, WVJBResponseCallback responseCallback) {
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
