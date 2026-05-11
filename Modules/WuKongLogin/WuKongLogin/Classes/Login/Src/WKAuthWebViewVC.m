//
//  WKAuthWebView.m
//  WuKongLogin
//
//  Created by tt on 2023/6/12.
//

#import "WKAuthWebViewVC.h"
#import "WKLoginVM.h"
#import "WKSpaceGateVC.h"
#import "WKSpaceGateVM.h"
@interface WKAuthWebViewVC ()

@property(nonatomic,strong) NSTimer *timer;

@end

@implementation WKAuthWebViewVC


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self startCheckAuthStatus:self.authcode];
}


-(void) startCheckAuthStatus:(NSString*)authcode {
    __weak typeof(self) weakSelf = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authstatus" parameters:@{
        @"authcode": authcode,
    }].then(^(NSDictionary *resultDict){
       NSInteger status =  [resultDict[@"status"] integerValue];
        if(status == 1) {
            NSDictionary *dataDict = resultDict[@"result"];
            // Diagnose Aegis/OIDC login issues: log which fields backend returned.
            // If `im_token` is missing we fall back to `token` (see WKLoginVM handleLoginData),
            // which on some backends causes IM CONNECT to be closed silently.
            WKLogDebug(@"[OIDC] authstatus result fields: %@", [dataDict.allKeys componentsJoinedByString:@","]);
            [weakSelf login:dataDict];
        }else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf startCheckAuthStatus:authcode];
            });

        }
    }).catch(^(NSError *error){
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

-(void) login:(NSDictionary*)dataDict {
    WKLoginResp *resp = (WKLoginResp*)[WKLoginResp fromMap:dataDict type:ModelMapTypeAPI];
    [WKLoginVM handleLoginData:resp isSave:YES];

    // 冷启动的自动登录判定 (WKApp.m:443-467) 同时要求 currentSpaceId 非空
    // **且** WKSpaceGateCompleted=YES。早先只设了 spaceId 没设 gateCompleted，导致 Aegis
    // 登录后重启 app 会被判"未完成引导"→ 清 loginInfo 踢回登录页。这里两个 key 一起设，
    // 和 WKLoginVC.m checkSpaceBeforeEnter 保持对齐。
    NSString *cachedSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (cachedSpaceId && ![cachedSpaceId isEqualToString:@""]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WKSpaceGateCompleted"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
        return;
    }
    WKSpaceGateVM *spaceVM = [WKSpaceGateVM new];
    [spaceVM getMySpaces].then(^(NSArray *spaces){
        if (spaces && spaces.count > 0) {
            NSDictionary *firstSpace = spaces[0];
            NSString *spaceId = firstSpace[@"space_id"];
            if (spaceId && ![spaceId isEqualToString:@""]) {
                [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WKSpaceGateCompleted"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
        } else {
            WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
            [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
        }
    }).catch(^(NSError *error){
        WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
        [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
    });
}


@end
