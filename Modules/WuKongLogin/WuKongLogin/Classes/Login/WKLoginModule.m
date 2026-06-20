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
    // Phase 2: 接受 param @{@"mode": @"push"} — 从扫码/邀请命中
    // need_space 的运行时路径拉起 Space Gate，需要保留当前栈（加 Space 后 pop
    // 回主列表重放扫码 handler 重试入群）。默认行为仍是 resetRootViewController
    // （登录后首次引导的场景）。
    [self setMethod:WKPOINT_SPACEGATE_SHOW handler:^id _Nullable(id  _Nonnull param) {
        WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
        NSDictionary *paramDict = [param isKindOfClass:[NSDictionary class]] ? (NSDictionary *)param : nil;
        NSString *mode = paramDict[@"mode"];
        if ([mode isEqualToString:@"push"]) {
            [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
        } else {
            [[WKNavigationManager shared] resetRootViewController:spaceGateVC];
        }
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
        // R4 fix (Jerry): 抽 joinSpace API 返回的 space_id 当 just-joined intent。pickJoinedSpace
        // 的 preferred (= 上次空间快照) 在用户已登录、已有 currentSpaceId 时会赢过本次刚加入的
        // 新空间, 用户被邀请加入后却被路回旧空间。优先用 API 返回的 space_id, 没拿到再回退原 picker。
        NSString *joinedSpaceIdHint = nil;
        if ([result isKindOfClass:[NSDictionary class]]) {
            id sid = ((NSDictionary*)result)[@"space_id"];
            if ([sid isKindOfClass:[NSString class]] && ((NSString*)sid).length > 0) {
                joinedSpaceIdHint = sid;
            }
        }
        // 获取空间列表并切换到新空间
        [vm getMySpaces].then(^(NSArray *spaces) {
            // 仅在 role>0 的成员 Space 里挑。joinSpace 成功后用户必定是新加入
            // 空间的成员，所以应能命中；命中不到说明服务端列表还没刷新，保持
            // 当前 currentSpaceId 不动即可。
            NSDictionary *joinedSpace = nil;
            if (joinedSpaceIdHint.length > 0 && [spaces isKindOfClass:[NSArray class]]) {
                for (id item in spaces) {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    NSDictionary *s = (NSDictionary*)item;
                    if ([s[@"space_id"] isEqualToString:joinedSpaceIdHint]) {
                        joinedSpace = s;
                        break;
                    }
                }
            }
            if (!joinedSpace) {
                joinedSpace = [WKSpaceGateVM pickJoinedSpace:spaces];
            }
            if (joinedSpace) {
                NSString *spaceId = joinedSpace[@"space_id"];
                NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
                if (![spaceId isEqualToString:currentSpaceId]) {
                    [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    // 通知刷新，重新进入主界面以切换空间
                    [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
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
