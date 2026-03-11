//
//  WKLoginVC.m
//  WuKongLogin
//
//  Created by tt on 2019/12/1.
//

#import "WKLoginVC.h"
#import "WKLoginView.h"
#import "WKRegisterNextVC.h"
#import "WKLoginPhoneCheckStartVC.h"
#import "WKSpaceGateVC.h"
#import "WKSpaceGateVM.h"
@interface WKLoginVC ()
 
@property(nonatomic,strong) WKLoginView  *loginView;

@end

@implementation WKLoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.hidden= YES;
    [self fillZoneAndPhone];
}

- (NSString *)langTitle {
    return LLang(@"登录");
}

- (WKBaseVM *)viewModel {
    return [WKLoginVM new];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
   
}

-(void) loadView {
    //[super loadView];

    self.loginView = [[WKLoginView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, WKScreenHeight)];
   
     __weak typeof(self) weakSelf = self;
    
    self.loginView.onLogin = ^(NSString * _Nonnull mobile, NSString * _Nonnull password,NSString *country) {
        [weakSelf.view showHUD:LLangW(@"登录中",weakSelf)];

        // 根据是否有区号判断：有区号表示是手机号，无区号表示是用户名
        NSString *username;
        if (country && ![country isEqualToString:@""]) {
            // 手机号登录，拼接区号
            username = [NSString stringWithFormat:@"%@%@",country,mobile];
        } else {
            // 用户名登录，直接使用输入值
            username = mobile;
        }

        [weakSelf.viewModel login:username password:password].then(^(WKLoginResp *resp){
            [weakSelf.view hideHud];
            if(!resp.name || [resp.name isEqualToString:@""]) { // 如果没名字就跳到完善注册资料页面
                [WKLoginVM handleLoginData:resp isSave:NO];
                WKRegisterNextVC *vc = [WKRegisterNextVC new];
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }else {
                [WKLoginVM handleLoginData:resp isSave:YES];
                // 登录成功后检查是否有空间
                [weakSelf checkSpaceBeforeEnter];
            }

        }).catch(^(NSError *error){
            NSDictionary *userInfo = error.userInfo;
            if(userInfo &&  userInfo[@"status"]) {
               NSInteger status =  [userInfo[@"status"] integerValue];
                if(status == 110) {
                    [weakSelf.view hideHud];

                    WKLoginPhoneCheckStartVC *vc = [WKLoginPhoneCheckStartVC new];
                    vc.phone = userInfo[@"phone"]?:@"";
                    vc.uid = userInfo[@"uid"]?:@"";
                    [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    return;
                }
            }
            [weakSelf.view switchHUDError:error.domain];
        });
    };
    self.view = self.loginView;
}

-(void) fillZoneAndPhone {
    NSString *currentMobile = [WKApp shared].loginInfo.extra[@"phone"];
       NSString *currentCountry = [WKApp shared].loginInfo.extra[@"zone"];
       if(currentMobile && ![currentMobile isEqualToString:@""]) {
           self.loginView.mobile = currentMobile;
       }
       if(currentCountry && ![currentCountry isEqualToString:@""]) {
           self.loginView.country = [currentCountry stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@""];
       }
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [self.loginView viewConfigChange:type];
}

- (void)checkSpaceBeforeEnter {
    // 检查缓存的空间ID
    NSString *cachedSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if(cachedSpaceId && ![cachedSpaceId isEqualToString:@""]) {
        // 有缓存的空间ID，直接进入
        [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
        return;
    }

    // 没有缓存，检查服务器上是否有空间
    __weak typeof(self) weakSelf = self;
    WKSpaceGateVM *spaceVM = [WKSpaceGateVM new];
    [spaceVM getMySpaces].then(^(NSArray *spaces){
        if(spaces && spaces.count > 0) {
            // 有空间，保存第一个空间ID并进入
            NSDictionary *firstSpace = spaces[0];
            NSString *spaceId = firstSpace[@"space_id"];
            if(spaceId && ![spaceId isEqualToString:@""]) {
                [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
        } else {
            // 没有空间，显示SpaceGate引导页
            WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
            [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
        }
    }).catch(^(NSError *error){
        // 出错也显示SpaceGate引导页
        WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
        [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
    });
}

@end
