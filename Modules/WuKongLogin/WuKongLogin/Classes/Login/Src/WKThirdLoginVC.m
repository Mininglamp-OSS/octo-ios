//
//  WKThirdLoginVC.m
//  WuKongLogin
//
//  Created by tt on 2023/6/25.
//

#import "WKThirdLoginVC.h"
#import "WKAuthWebViewVC.h"
#import "WKLoginVC.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "WKLoginSettingVC.h"

API_AVAILABLE(ios(13.0))
@interface WKThirdLoginVC ()

@property(nonatomic,strong) UIImageView *bgImgView;

@property(nonatomic,strong) UILabel *titleLbl;

@property(nonatomic,strong) UILabel *tipLbl;

@property(nonatomic,strong) UIButton *giteeBtn;
@property(nonatomic,strong) UIButton *githubBtn;

//@property(nonatomic,strong) UIButton *settingBtn; // 服务器设置

@end

@implementation WKThirdLoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.bgImgView];
    [self.view addSubview:self.titleLbl];
    [self.view addSubview:self.tipLbl];
    [self.view addSubview:self.giteeBtn];
    [self.view addSubview:self.githubBtn];
//    [self.view addSubview:self.settingBtn];
    
    
    [self layout];
}

-(void) layout {
    self.titleLbl.lim_top = 138.0f;
    self.titleLbl.lim_centerX_parent = self.view;
    
    self.tipLbl.lim_top = self.titleLbl.lim_bottom + 250.0f;
    self.tipLbl.lim_centerX_parent = self.view;
    
    self.giteeBtn.lim_top = self.tipLbl.lim_bottom + 40.0f;
    self.githubBtn.lim_top = self.giteeBtn.lim_top;
    
    CGFloat btw = 80.0f;
    
    CGFloat contentWidth = self.giteeBtn.lim_width + btw + self.githubBtn.lim_width;
    self.giteeBtn.lim_left = self.view.lim_width/2.0f - contentWidth/2.0f;
    self.githubBtn.lim_left= self.giteeBtn.lim_right + btw;


}

- (UIImageView *)bgImgView {
    if(!_bgImgView) {
        _bgImgView = [[UIImageView alloc] initWithImage:[self image:@"ThirdLogin"]];
        _bgImgView.lim_size = self.view.lim_size;
    }
    return _bgImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [WKApp.shared.config appFontOfSizeMedium:30.0f];
        _titleLbl.text = [NSString stringWithFormat:@"欢迎登录%@",WKApp.shared.config.appName];
        _titleLbl.textColor = [UIColor whiteColor];
        [_titleLbl sizeToFit];
        
        _titleLbl.userInteractionEnabled = YES;
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(titleLongPressed:)];
        
        [_titleLbl addGestureRecognizer:longPress];
    }
    return _titleLbl;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.font = [WKApp.shared.config appFontOfSize:14.0f];
        _tipLbl.text = @"—  第三方登录  —";
        _tipLbl.textColor = [UIColor whiteColor];
        [_tipLbl sizeToFit];
    }
    return _tipLbl;
}

-(UIButton*) giteeBtn {
    if(!_giteeBtn) {
        _giteeBtn = [[UIButton alloc] init];
        [_giteeBtn setImage:[self image:@"gitee"] forState:UIControlStateNormal];
        [_giteeBtn sizeToFit];
        
        [_giteeBtn addTarget:self action:@selector(giteeLoginPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _giteeBtn;
}

- (UIButton *)githubBtn {
    if(!_githubBtn) {
        _githubBtn = [[UIButton alloc] init];
        [_githubBtn setImage:[self image:@"github"] forState:UIControlStateNormal];
        [_githubBtn sizeToFit];
        [_githubBtn addTarget:self action:@selector(githubLoginPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _githubBtn;
}
//- (UIButton *)settingBtn {
//    if(!_settingBtn) {
//        _settingBtn = [[UIButton alloc] init];
//        _settingBtn.lim_size = CGSizeMake(32.0f, 32.0f);
//        [_settingBtn setImage:[self image:@"Setting"] forState:UIControlStateNormal];
//        
//        _settingBtn.lim_top = WKApp.shared.config.visibleEdgeInsets.top + 20.0f;
//        _settingBtn.lim_left = self.view.lim_width - _settingBtn.lim_width - 20.0f;
//        [_settingBtn addTarget:self action:@selector(settingPressed) forControlEvents:UIControlEventTouchUpInside];
//    }
//    return _settingBtn;
//}

-(void) settingPressed {
    WKLoginSettingVC *vc = [WKLoginSettingVC new];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}


-(void) titleLongPressed:(UILongPressGestureRecognizer*)gestureRecognizer {
    if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        WKLoginVC *vc = [[WKLoginVC alloc] init];
        [WKNavigationManager.shared pushViewController:vc animated:YES];
    }
}

-(void) giteeLoginPressed {
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        NSString *authcode = resultDict[@"authcode"];
        if(authcode) {
            WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
            vc.authcode = authcode;
            vc.url = [NSURL URLWithString:[NSString stringWithFormat:@"%@user/gitee?authcode=%@",WKAPIClient.sharedClient.config.baseUrl,authcode]];
            [WKNavigationManager.shared pushViewController:vc animated:YES];
        }
    }).catch(^(NSError *error){
        [weakself.view showHUDWithHide:error.domain];
    });
   
}

-(void) githubLoginPressed {
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        NSString *authcode = resultDict[@"authcode"];
        if(authcode) {
            WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
            vc.authcode = authcode;
            vc.url = [NSURL URLWithString:[NSString stringWithFormat:@"%@user/github?authcode=%@",WKAPIClient.sharedClient.config.baseUrl,authcode]];
            [WKNavigationManager.shared pushViewController:vc animated:YES];
        }
    }).catch(^(NSError *error){
        [weakself.view showHUDWithHide:error.domain];
    });
}


#pragma mark - ASAuthorizationControllerDelegate

//授权成功的回调
/**
 当授权成功后，我们可以通过这个拿到用户的 userID、email、fullName、authorizationCode、identityToken 以及 realUserStatus 等信息。
 */
-(void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization API_AVAILABLE(ios(13.0)) {
    
    if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
        
        // 用户登录使用ASAuthorizationAppleIDCredential
        ASAuthorizationAppleIDCredential *credential = authorization.credential;
        
        //苹果用户唯一标识符，该值在同一个开发者账号下的所有 App 下是一样的，开发者可以用该唯一标识符与自己后台系统的账号体系绑定起来。
        NSString *userId = credential.user;
        NSString *state = credential.state;
        NSPersonNameComponents *fullName = credential.fullName;
        //苹果用户信息，邮箱
        NSString *email = credential.email;
        NSString *authorizationCode = [[NSString alloc] initWithData:credential.authorizationCode encoding:NSUTF8StringEncoding]; // refresh token
        /**
         验证数据，用于传给开发者后台服务器，然后开发者服务器再向苹果的身份验证服务端验证本次授权登录请求数据的有效性和真实性，详见 Sign In with Apple REST API。如果验证成功，可以根据 userIdentifier 判断账号是否已存在，若存在，则返回自己账号系统的登录态，若不存在，则创建一个新的账号，并返回对应的登录态给 App。
         */
        NSString *identityToken = [[NSString alloc] initWithData:credential.identityToken encoding:NSUTF8StringEncoding];
        /**
         用于判断当前登录的苹果账号是否是一个真实用户
         取值有：unsupported、unknown、likelyReal。
         */
        ASUserDetectionStatus realUserStatus = credential.realUserStatus;
        //  需要使用钥匙串的方式保存用户的唯一信息 这里暂且处于测试阶段 是否的NSUserDefaults
        [[NSUserDefaults standardUserDefaults] setValue:userId forKey:@"ShareCurrentIdentifier"];
        
        NSLog(@"credential---->%@",identityToken);
        
    } else if ([authorization.credential isKindOfClass:[ASPasswordCredential class]]) {
        
        // 用户登录使用现有的密码凭证
        ASPasswordCredential *passwordCredential = authorization.credential;
        // 密码凭证对象的用户标识 用户的唯一标识
        NSString *user = passwordCredential.user;
        // 密码凭证对象的密码
        NSString *password = passwordCredential.password;
        
        NSLog(@"credential2---->%@",[NSString stringWithFormat:@"%@",passwordCredential]);
        
    } else {
        
    }
}

//失败的回调
-(void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    
    NSString *errorMsg = nil;
    
    switch (error.code) {
        case ASAuthorizationErrorCanceled:
            errorMsg = @"用户取消了授权请求";
            break;
        case ASAuthorizationErrorFailed:
            errorMsg = @"授权请求失败";
            break;
        case ASAuthorizationErrorInvalidResponse:
            errorMsg = @"授权请求响应无效";
            break;
        case ASAuthorizationErrorNotHandled:
            errorMsg = @"未能处理授权请求";
            break;
        case ASAuthorizationErrorUnknown:
            errorMsg = @"授权请求失败未知原因";
            break;
    }
    
    NSLog(@"error--->%@",[NSString stringWithFormat:@"%@",errorMsg]);
}



-(UIImage*) image:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}
@end
