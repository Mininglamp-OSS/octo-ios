//
//  WKGrantLoginVC.m
//  WuKongLogin
//
//  Created by tt on 2020/4/18.
//

#import "WKGrantLoginVC.h"
#import "WKGrantLoginVM.h"
@interface WKGrantLoginVC ()
@property(nonatomic,strong) UIImageView *pcImgView;
@property(nonatomic,strong) UILabel *tipLbl;
@property(nonatomic,strong) UIButton *loginBtn;
@property(nonatomic,strong) UIButton *cancelLoginBtn;
@property(nonatomic,strong) UIButton *closeBtn;
@property(nonatomic,strong) WKGrantLoginVM *vm;
@end

@implementation WKGrantLoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.vm = [WKGrantLoginVM initWithAuthCode:self.authCode pubkeyBase64Enc:self.pubkeyBase64Enc];
    [self.view addSubview:self.pcImgView];
    [self.view addSubview:self.tipLbl];
    [self.view addSubview:self.loginBtn];
    [self.view addSubview:self.cancelLoginBtn];
    [self.view addSubview:self.closeBtn];
}

- (NSString *)langTitle {
    return LLang(@"授权登录");
}

- (UIImageView *)pcImgView {
    if(!_pcImgView) {
        _pcImgView = [[UIImageView alloc] initWithImage:[self imageName:@"PC"]];
        _pcImgView.lim_width = 120.0f;
        _pcImgView.lim_height = 120.0f;
        _pcImgView.lim_top = 120.0f;
        _pcImgView.lim_left = self.view.lim_width/2.0f - _pcImgView.lim_width/2.0f;
    }
    return _pcImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.text = [NSString stringWithFormat:LLang(@"网页版%@登录确认"),[WKApp shared].config.appName];
        _tipLbl.font = [UIFont systemFontOfSize:14.0f];
        _tipLbl.lim_top = self.pcImgView.lim_bottom+20.0f;
        [_tipLbl sizeToFit];
        _tipLbl.lim_left = self.view.lim_width/2.0f - _tipLbl.lim_width/2.0f;
    }
    return _tipLbl;
}

- (UIButton *)loginBtn {
    if(!_loginBtn) {
        _loginBtn = [[UIButton alloc] init];
        [_loginBtn setTitle:LLang(@"登录") forState:UIControlStateNormal];
        _loginBtn.lim_width = 200.0f;
        _loginBtn.lim_height = 44.0f;
        _loginBtn.layer.masksToBounds = YES;
        _loginBtn.layer.cornerRadius = 4.0f;
        [_loginBtn setBackgroundColor:[WKApp shared].config.themeColor];
        _loginBtn.lim_top = self.view.lim_height - _loginBtn.lim_height -150.0f;
        _loginBtn.lim_left = self.view.lim_width/2.0f -_loginBtn.lim_width/2.0f;
        [_loginBtn addTarget:self action:@selector(onGrantLogin) forControlEvents:UIControlEventTouchUpInside];
        
        [WKApp.shared.config setThemeStyleButton:_loginBtn];
    }
    return _loginBtn;
}
-(void) onGrantLogin{
    __weak typeof(self) weakSelf = self;
    [self.vm grantLogin].then(^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }).catch(^(NSError*error){
        [weakSelf.view showMsg:error.domain];
    });
}
- (UIButton *)cancelLoginBtn {
    if(!_cancelLoginBtn) {
        _cancelLoginBtn = [[UIButton alloc] init];
        [_cancelLoginBtn setTitle:LLang(@"取消登录") forState:UIControlStateNormal];
        [_cancelLoginBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [[_cancelLoginBtn titleLabel] setFont:[UIFont systemFontOfSize:15.0f]];
        [_cancelLoginBtn sizeToFit];
        _cancelLoginBtn.lim_top = _loginBtn.lim_bottom + 40.0f;
        _cancelLoginBtn.lim_left = self.view.lim_width/2.0f - _cancelLoginBtn.lim_width/2.0f;
         [_cancelLoginBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cancelLoginBtn;
}

- (UIButton *)closeBtn {
    if(!_closeBtn) {
        _closeBtn = [[UIButton alloc] init];
        [_closeBtn setImage:[self imageName:@"Close"] forState:UIControlStateNormal];
        _closeBtn.lim_size = CGSizeMake(24.0f, 24.0f);
        _closeBtn.lim_left = 20.0f;
        _closeBtn.lim_top = 40.0f;
        [_closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeBtn;
}
-(void) onClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(UIImage*) imageName:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}
@end
