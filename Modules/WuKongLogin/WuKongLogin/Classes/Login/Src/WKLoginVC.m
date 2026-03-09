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
        
        [weakSelf.viewModel login:[NSString stringWithFormat:@"%@%@",country,mobile] password:password].then(^(WKLoginResp *resp){
             [weakSelf.view hideHud];
            if(!resp.name || [resp.name isEqualToString:@""]) { // 如果没名字就跳到完善注册资料页面
                [WKLoginVM handleLoginData:resp isSave:NO];
                WKRegisterNextVC *vc = [WKRegisterNextVC new];
                [[WKNavigationManager shared] pushViewController:vc animated:YES];
            }else {
                [WKLoginVM handleLoginData:resp isSave:YES];
                [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
                
               
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

@end
