//
//  WKLoginModule.m
//  WuKongLogin
//
//  Created by tt on 2019/12/1.
//

#import "WKLoginModule.h"
#import "WKLoginVC.h"
#import "WKGrantLoginVC.h"
#import "WKThirdLoginVC.h"
#import "WKLoginSettingVC.h"
#import "WKSpaceGateVC.h"
#import "WKSpaceGateVM.h"
@WKModule(WKLoginModule)
@implementation WKLoginModule

-(NSString*) moduleId {
    return @"WuKongLogin";
}

- (void)moduleInit:(WKModuleContext*)context{
    NSLog(@"【WuKongLogin】模块初始化！");
    
    [WKLoginSettingVC setAppConfigIfNeed];
    
    // 显示登录页面
    [self setMethod:WKPOINT_LOGIN_SHOW handler:^id _Nullable(id  _Nonnull param) {
         WKLoginVC *loginVC = [WKLoginVC new]; // 手机号登录UI
//        WKThirdLoginVC *loginVC = [WKThirdLoginVC new]; // 第三方授权登录UI
        [[WKNavigationManager shared] resetRootViewController:loginVC];
        return nil;
    }];
    
    // 显示空间引导页
    [self setMethod:WKPOINT_SPACEGATE_SHOW handler:^id _Nullable(id  _Nonnull param) {
        WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
        [[WKNavigationManager shared] resetRootViewController:spaceGateVC];
        return nil;
    }];

    // 授权登录UI
    [self setMethod:WKPOINT_SCAN_HANDLER_GRANTLOGIN handler:^id _Nullable(id  _Nonnull param) {
           return [WKScanHandler handle:^BOOL(WKScanResult * _Nonnull result, void (^ _Nonnull reScanBlock)(void)) {
               if(![result.type isEqualToString:@"loginConfirm"]) {
                   return false;
               }
               WKGrantLoginVC *vc = [WKGrantLoginVC new];
               vc.authCode = result.data[@"auth_code"];
               vc.pubkeyBase64Enc = result.data[@"pub_key"];
               vc.modalPresentationStyle = UIModalPresentationFullScreen;
               [[WKNavigationManager shared] replacePresentViewController:vc animated:YES];
               return true;
           }];
       } category:WKPOINT_CATEGORY_SCAN_HANDLER];
}

#pragma mark - Universal Links

-(BOOL) moduleContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    if (![userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        return NO;
    }

    NSURL *url = userActivity.webpageURL;
    if (!url) {
        return NO;
    }

    // 从 URL 提取 invite 参数
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *inviteCode = nil;
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"invite"]) {
            inviteCode = item.value;
            break;
        }
    }

    if (!inviteCode || inviteCode.length == 0) {
        return NO;
    }

    if ([[WKApp shared] isLogined]) {
        // 已登录：直接调用 joinSpace API
        [self handleInviteCodeForLoggedInUser:inviteCode];
    } else {
        // 未登录：暂存邀请码，等登录后自动消费
        [[NSUserDefaults standardUserDefaults] setObject:inviteCode forKey:@"WKPendingInviteCode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    return YES;
}

- (void)handleInviteCodeForLoggedInUser:(NSString *)inviteCode {
    WKSpaceGateVM *vm = [WKSpaceGateVM new];
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }

    [keyWindow showHUD:LLang(@"正在加入空间...")];

    [vm joinSpace:inviteCode].then(^(id result) {
        [keyWindow switchHUDSuccess:LLang(@"已成功加入空间")];
        // 获取空间列表并切换到新空间
        [vm getMySpaces].then(^(NSArray *spaces) {
            if (spaces && spaces.count > 0) {
                // 找到最新加入的空间（取第一个）
                NSDictionary *firstSpace = spaces[0];
                NSString *spaceId = firstSpace[@"space_id"];
                if (spaceId && spaceId.length > 0) {
                    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
                    if (![spaceId isEqualToString:currentSpaceId]) {
                        [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        // 通知刷新，重新进入主界面以切换空间
                        [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
                    }
                }
            }
        });
    }).catch(^(NSError *error) {
        NSString *msg = error.domain ?: @"";
        if ([msg containsString:@"已加入"] || [msg containsString:@"ALREADY_JOINED"] || [msg containsString:@"already"]) {
            [keyWindow switchHUDSuccess:LLang(@"已在该空间中")];
        } else if ([msg containsString:@"已满"] || [msg containsString:@"SPACE_FULL"]) {
            [keyWindow switchHUDError:LLang(@"空间已满，无法加入")];
        } else {
            [keyWindow switchHUDError:LLang(@"邀请码无效或已过期")];
        }
    });
}

@end
