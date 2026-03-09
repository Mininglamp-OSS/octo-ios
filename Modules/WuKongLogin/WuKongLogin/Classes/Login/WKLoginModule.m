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



@end
