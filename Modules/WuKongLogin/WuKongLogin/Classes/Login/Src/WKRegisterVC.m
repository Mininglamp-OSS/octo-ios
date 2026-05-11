//
//  WKRegisterVC.m
//  WuKongLogin
//
//  Created by tt on 2020/6/18.
//

#import "WKRegisterVC.h"
#import "WKRegisterVM.h"
#import "WKCountrySelectVC.h"
#import "WKLoginVC.h"
#import "WKRegisterNextVC.h"
#import "WKSpaceGateVC.h"
#import "WKServerConfig.h"
#import "WKAuthWebViewVC.h"
#import <M80AttributedLabel/M80AttributedLabel.h>

typedef enum : NSUInteger {
    CodeStatusDefault,
    CodeStatusCountdown,
} CodeStatus;

@interface WKRegisterVC ()<UITextFieldDelegate,M80AttributedLabelDelegate>

@property(nonatomic,strong) UIImageView *bgImgView;
@property(nonatomic,strong) UILabel *titleLbl;

@property(nonatomic,strong) UIView *mobileBoxView;
@property(nonatomic,strong) UITextField *mobileTextField;
@property(nonatomic,strong) UIView *mobileBottomLineView;

// 验证码
@property(nonatomic,strong) UIView *codeBoxView;
@property(nonatomic,strong) UIView *codeLineView;
@property(nonatomic,strong) UITextField *codeTextField;
@property(nonatomic,strong) UIButton *getCodeBtn;
@property(nonatomic,assign) CodeStatus codeStatus;
@property(nonatomic,strong) NSTimer *codeTimer;
@property(nonatomic,assign) NSInteger countdownSec;

// 昵称
@property(nonatomic,strong) UIView *nicknameBoxView;
@property(nonatomic,strong) UIView *nicknameBottomLineView;
@property(nonatomic,strong) UITextField *nicknameTextField;

// 密码
@property(nonatomic,strong) UIView *passwordBoxView;
@property(nonatomic,strong) UIView *passwordBottomLineView;
@property(nonatomic,strong) UITextField *passwordTextField;
@property(nonatomic,strong) UIButton *eyeBtn;

// 邀请码
@property(nonatomic,strong) UIView *inviteCodeBoxView;
@property(nonatomic,strong) UIView *inviteCodeBottomLineView;
@property(nonatomic,strong) UITextField *inviteCodeTextField;

// 底部
@property(nonatomic,strong) UIButton *registerBtn;
@property(nonatomic,strong) UILabel *loginTipLbl;
@property(nonatomic,strong) UIButton *toLoginBtn;
@property(nonatomic,strong) M80AttributedLabel *privacyLbl;

// Aegis SSO 快速入口 — 与 WKLoginView 共享同一套 authcode / WKAuthWebViewVC 机制
@property(nonatomic,strong) UIButton *ssoBtn;
@property(nonatomic,strong) WKOidcProviderConfig *currentProvider;
@property(nonatomic,assign) BOOL ssoInFlight;

@end

@implementation WKRegisterVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.viewModel = [WKRegisterVM new];
    }
    return self;
}

/// 注册始终需要邮箱验证码
- (BOOL)needsVerificationCode {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.hidden = YES;

    [self.view addSubview:self.bgImgView];
    [self.view addSubview:self.titleLbl];

    [self.view addSubview:self.mobileBoxView];
    [self.mobileBoxView addSubview:self.mobileTextField];
    [self.mobileBoxView addSubview:self.mobileBottomLineView];

    // 正式服务器显示验证码输入框
    if ([self needsVerificationCode]) {
        [self.view addSubview:self.codeBoxView];
        [self.codeBoxView addSubview:self.codeLineView];
        [self.codeBoxView addSubview:self.codeTextField];
        [self.codeBoxView addSubview:self.getCodeBtn];
    }

    [self.view addSubview:self.nicknameBoxView];
    [self.nicknameBoxView addSubview:self.nicknameBottomLineView];
    [self.nicknameBoxView addSubview:self.nicknameTextField];

    [self.view addSubview:self.passwordBoxView];
    [self.passwordBoxView addSubview:self.passwordBottomLineView];
    [self.passwordBoxView addSubview:self.passwordTextField];
    [self.passwordBoxView addSubview:self.eyeBtn];

    [self.view addSubview:self.inviteCodeBoxView];
    [self.inviteCodeBoxView addSubview:self.inviteCodeBottomLineView];
    [self.inviteCodeBoxView addSubview:self.inviteCodeTextField];

    [self.view addSubview:self.registerBtn];
    [self.view addSubview:self.loginTipLbl];
    [self.view addSubview:self.toLoginBtn];
    [self.view addSubview:self.privacyLbl];

    [self.view addSubview:self.ssoBtn];
    [self refreshOidcProviders];
    [[WKApp shared].remoteConfig requestConfig:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRemoteConfigLoaded) name:WKNOTIFY_REMOTECONFIG_LOADED object:nil];
}

- (void)onRemoteConfigLoaded {
    [self refreshOidcProviders];
}

- (WKBaseVM *)viewModel {
    return [WKRegisterVM new];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

/// 验证码框下面的第一个输入框的 top
- (CGFloat)afterCodeTop {
    if ([self needsVerificationCode]) {
        return self.codeBoxView.lim_bottom + 20.0f;
    }
    return self.mobileBoxView.lim_bottom + 20.0f;
}

#pragma mark - UI

- (UIImageView *)bgImgView {
    if(!_bgImgView) {
        _bgImgView = [[UIImageView alloc] initWithImage:[[WKApp shared] loadImage:@"Background" moduleID:@"WuKongLogin"]];
        _bgImgView.frame = self.view.bounds;
    }
    return _bgImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:LLang(@"欢迎注册%@"),[WKApp shared].config.appName] attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size: 32],NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0]}];
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, 83, WKScreenWidth-60, 50)];
        _titleLbl.attributedText = string;
        _titleLbl.textAlignment = NSTextAlignmentLeft;
    }
    return _titleLbl;
}

- (UIView *)mobileBoxView {
    if(!_mobileBoxView) {
        _mobileBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 190.0f, WKScreenWidth, 40.0f)];
    }
    return _mobileBoxView;
}

-(UITextField*) mobileTextField {
    if(!_mobileTextField) {
        _mobileTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth - 40.0f, 40.0f)];
        _mobileTextField.placeholder = [self needsVerificationCode] ? LLang(@"请输入邮箱") : LLang(@"请输入账号（可以是任意字符）");
        _mobileTextField.keyboardType = [self needsVerificationCode] ? UIKeyboardTypeEmailAddress : UIKeyboardTypeDefault;
        _mobileTextField.returnKeyType = UIReturnKeyNext;
        _mobileTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _mobileTextField.delegate = self;
    }
    return _mobileTextField;
}

- (UIView *)mobileBottomLineView {
    if(!_mobileBottomLineView) {
        _mobileBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _mobileBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _mobileBottomLineView;
}

// ---------- 验证码 ----------

- (UIView *)codeBoxView {
    if(!_codeBoxView) {
        _codeBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.mobileBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
    }
    return _codeBoxView;
}

- (UIView *)codeLineView {
    if(!_codeLineView) {
        _codeLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.codeBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _codeLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _codeLineView;
}

- (UITextField *)codeTextField {
    if(!_codeTextField) {
        _codeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.codeBoxView.lim_height/2.0f - 20.0f, WKScreenWidth - 20.0f - 110.0f, 40.0f)];
        [_codeTextField setPlaceholder:LLang(@"请输入验证码")];
        _codeTextField.keyboardType = UIKeyboardTypeNumberPad;
        _codeTextField.returnKeyType = UIReturnKeyNext;
        _codeTextField.delegate = self;
    }
    return _codeTextField;
}

- (UIButton *)getCodeBtn {
    if(!_getCodeBtn) {
        CGFloat height = 30.0f;
        _getCodeBtn = [[UIButton alloc] initWithFrame:CGRectMake(WKScreenWidth - 20.0f - 90.0f, self.codeBoxView.lim_height/2.0f - height/2.0f, 90.0f, height)];
        [_getCodeBtn setTitle:LLang(@"获取验证码") forState:UIControlStateNormal];
        [[_getCodeBtn titleLabel] setFont:[UIFont systemFontOfSize:12.0f]];
        [_getCodeBtn setBackgroundColor:[WKApp shared].config.themeColor];
        _getCodeBtn.layer.masksToBounds = YES;
        _getCodeBtn.layer.cornerRadius = 4.0f;
        [_getCodeBtn addTarget:self action:@selector(sendCode) forControlEvents:UIControlEventTouchUpInside];
        [WKApp.shared.config setThemeStyleButton:_getCodeBtn];
    }
    return _getCodeBtn;
}

// ---------- 昵称 ----------

- (UIView *)nicknameBoxView {
    if(!_nicknameBoxView) {
        _nicknameBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, [self afterCodeTop], WKScreenWidth, self.mobileBoxView.lim_height)];
    }
    return _nicknameBoxView;
}

- (UIView *)nicknameBottomLineView {
    if(!_nicknameBottomLineView) {
        _nicknameBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.nicknameBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _nicknameBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _nicknameBottomLineView;
}

- (UITextField *)nicknameTextField {
    if(!_nicknameTextField) {
        _nicknameTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.nicknameBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2, 40.0f)];
        [_nicknameTextField setPlaceholder:LLang(@"昵称")];
        _nicknameTextField.keyboardType = UIKeyboardTypeDefault;
        _nicknameTextField.returnKeyType = UIReturnKeyNext;
        _nicknameTextField.delegate = self;
    }
    return _nicknameTextField;
}

// ---------- 密码 ----------

- (UIView *)passwordBoxView {
    if(!_passwordBoxView) {
        _passwordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.nicknameBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
    }
    return _passwordBoxView;
}

- (UIView *)passwordBottomLineView {
    if(!_passwordBottomLineView) {
        _passwordBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _passwordBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _passwordBottomLineView;
}

- (UITextField *)passwordTextField {
    if(!_passwordTextField) {
        _passwordTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        [_passwordTextField setPlaceholder:LLang(@"请输入登录密码")];
        _passwordTextField.returnKeyType = UIReturnKeyDone;
        _passwordTextField.secureTextEntry = YES;
        _passwordTextField.delegate = self;
    }
    return _passwordTextField;
}

- (UIButton *)eyeBtn {
    if(!_eyeBtn) {
        CGFloat width = 32.0f;
        CGFloat height = 32.0f;
        _eyeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.lim_width - 20.0f - width, self.passwordBoxView.lim_height/2.0f - (height)/2.0f, width, height)];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOff" moduleID:@"WuKongLogin"] forState:UIControlStateNormal];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOn" moduleID:@"WuKongLogin"] forState:UIControlStateSelected];
        _eyeBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_eyeBtn setImageEdgeInsets:UIEdgeInsetsMake(height/4.0f, width, height/4.0f, width)];
        [_eyeBtn addTarget:self action:@selector(passwordLookPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _eyeBtn;
}

// ---------- 邀请码 ----------

- (UIView *)inviteCodeBoxView {
    if(!_inviteCodeBoxView) {
        _inviteCodeBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.passwordBoxView.lim_bottom+20.0f, WKScreenWidth, self.passwordBoxView.lim_height)];
        _inviteCodeBoxView.hidden = !WKApp.shared.remoteConfig.registerInviteOn;
    }
    return _inviteCodeBoxView;
}

- (UITextField *)inviteCodeTextField {
    if(!_inviteCodeTextField) {
        _inviteCodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        _inviteCodeTextField.hidden = !WKApp.shared.remoteConfig.registerInviteOn;
        if(WKApp.shared.remoteConfig.registerInviteOn) {
            [_inviteCodeTextField setPlaceholder:LLang(@"邀请码（必填）")];
        } else {
            [_inviteCodeTextField setPlaceholder:LLang(@"邀请码（选填）")];
        }
    }
    return _inviteCodeTextField;
}

- (UIView *)inviteCodeBottomLineView {
    if(!_inviteCodeBottomLineView) {
        _inviteCodeBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.inviteCodeBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _inviteCodeBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _inviteCodeBottomLineView;
}

// ---------- 底部 ----------

- (UIButton *)registerBtn {
    if(!_registerBtn) {
        CGFloat top = self.passwordBoxView.lim_bottom;
        if(WKApp.shared.remoteConfig.registerInviteOn) {
            top = self.inviteCodeBoxView.lim_bottom;
        }
        _registerBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f, top+82.0f, WKScreenWidth - 60.0f, 40.0f)];
        [_registerBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_registerBtn setTitle:LLang(@"注册") forState:UIControlStateNormal];
        [_registerBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _registerBtn.layer.masksToBounds = YES;
        _registerBtn.layer.cornerRadius = 4.0f;
        [_registerBtn addTarget:self action:@selector(registerBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        [WKApp.shared.config setThemeStyleButton:_registerBtn];
    }
    return _registerBtn;
}

-(UILabel*) loginTipLbl {
    if(!_loginTipLbl) {
        _loginTipLbl = [[UILabel alloc] init];
        [_loginTipLbl setText:LLang(@"已有账号？请")];
        [_loginTipLbl setFont:[UIFont systemFontOfSize:16.0f]];
        [_loginTipLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0]];
        [_loginTipLbl sizeToFit];
        _loginTipLbl.lim_top = self.registerBtn.lim_bottom + 25.0f;
        _loginTipLbl.lim_left = self.view.lim_width/2.0f - _loginTipLbl.lim_width/2.0f - 20.0f;
    }
    return _loginTipLbl;
}

- (UIButton *)toLoginBtn {
    if(!_toLoginBtn) {
        _toLoginBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.loginTipLbl.lim_right, self.loginTipLbl.lim_top-7.2f, 20.0f, 22.0f)];
        [_toLoginBtn setTitle:LLang(@"登录") forState:UIControlStateNormal];
        [_toLoginBtn sizeToFit];
        [_toLoginBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_toLoginBtn titleLabel] setFont:[UIFont systemFontOfSize:16.0f]];
        [_toLoginBtn addTarget:self action:@selector(toLoginPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _toLoginBtn;
}

// ---------- Aegis SSO ----------
- (UIButton *)ssoBtn {
    if(!_ssoBtn) {
        _ssoBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f, self.loginTipLbl.lim_bottom + 20.0f, WKScreenWidth - 60.0f, 40.0f)];
        _ssoBtn.layer.masksToBounds = YES;
        _ssoBtn.layer.cornerRadius = 4.0f;
        _ssoBtn.layer.borderWidth = 1.0f;
        _ssoBtn.layer.borderColor = [WKApp shared].config.themeColor.CGColor;
        [_ssoBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_ssoBtn titleLabel] setFont:[UIFont systemFontOfSize:15.0f]];
        [_ssoBtn addTarget:self action:@selector(ssoBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        _ssoBtn.hidden = YES;
    }
    return _ssoBtn;
}

- (void)refreshOidcProviders {
    NSArray<WKOidcProviderConfig*> *providers = [WKApp shared].remoteConfig.oidcProviders;
    WKOidcProviderConfig *provider = providers.count > 0 ? providers.firstObject : nil;
    self.currentProvider = provider;
    if(!provider) {
        self.ssoBtn.hidden = YES;
        return;
    }
    NSString *title = [NSString stringWithFormat:LLang(@"使用 %@ 登录或注册"), provider.name];
    [self.ssoBtn setTitle:title forState:UIControlStateNormal];
    self.ssoBtn.hidden = NO;
}

- (void)ssoBtnPressed {
    if(self.ssoInFlight) return;
    WKOidcProviderConfig *provider = self.currentProvider;
    if(!provider) return;
    self.ssoInFlight = YES;
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        weakself.ssoInFlight = NO;
        NSString *authcode = resultDict[@"authcode"];
        if(!authcode || authcode.length == 0) {
            [weakself.view showHUDWithHide:LLang(@"获取授权失败，请重试")];
            return;
        }
        NSURL *authorizeURL = [weakself buildOidcAuthorizeURL:provider authcode:authcode];
        if(!authorizeURL) {
            [weakself.view showHUDWithHide:LLang(@"授权地址无效")];
            return;
        }
        WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
        vc.authcode = authcode;
        vc.url = authorizeURL;
        [WKNavigationManager.shared pushViewController:vc animated:YES];
    }).catch(^(NSError *error){
        weakself.ssoInFlight = NO;
        [weakself.view showHUDWithHide:error.domain];
    });
}

- (NSURL *)buildOidcAuthorizeURL:(WKOidcProviderConfig *)provider authcode:(NSString *)authcode {
    // YUJ-420 R1 fix (Jerry-Xin Critical): delegate to WKOidcProviderConfig shared helper,
    // which uses NSURLComponents + NSURLQueryItem for RFC 3986-safe query encoding and
    // avoids logging full authorize URL (authcode / device_* redacted).
    return [WKOidcProviderConfig buildAuthorizeURLForProvider:provider
                                                     authcode:authcode
                                                      apiBase:WKAPIClient.sharedClient.config.baseUrl ?: @""
                                                     deviceId:[UIDevice getUUID]
                                                   deviceName:[UIDevice getDeviceName]
                                                  deviceModel:[UIDevice getDeviceModel]];
}

- (M80AttributedLabel *)privacyLbl {
    if(!_privacyLbl) {
        CGFloat bottom = 0.0f;
        if (@available(iOS 11.0, *)) {
            bottom = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
        }
        _privacyLbl = [[M80AttributedLabel alloc] init];
        _privacyLbl.delegate = self;
        _privacyLbl.backgroundColor = [UIColor clearColor];
        [_privacyLbl setFont:[UIFont systemFontOfSize:12.0f]];
        [_privacyLbl setTextColor:[WKApp shared].config.tipColor];
        [_privacyLbl appendText:LLang(@"点击\"注册\"即表示已阅读并同意")];
        NSString *uPTxt = LLang(@"用户协议");
        [_privacyLbl addCustomLink:[WKApp shared].config.userAgreementUrl forRange:NSMakeRange(_privacyLbl.text.length, uPTxt.length)];
        [_privacyLbl appendText:uPTxt];
        [_privacyLbl appendText:@"、"];
        NSString *pPTxt = LLang(@"隐私政策");
        [_privacyLbl addCustomLink:[WKApp shared].config.privacyAgreementUrl forRange:NSMakeRange(_privacyLbl.text.length, pPTxt.length)];
        [_privacyLbl appendText:pPTxt];
        [_privacyLbl sizeToFit];
        _privacyLbl.lim_centerX_parent = self.view;
        _privacyLbl.lim_top = WKScreenHeight - (bottom + 30.0f);
    }
    return _privacyLbl;
}

#pragma mark - Actions

-(void) toLoginPressed {
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

-(void) passwordLookPressed:(UIButton*)btn {
    btn.selected = !btn.selected;
    _passwordTextField.secureTextEntry = !btn.selected;
}

-(void) sendCode {
    NSString *email = self.mobileTextField.text;
    if (!email || [email isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"请输入邮箱")];
        return;
    }
    if (self.codeStatus == CodeStatusCountdown) {
        return;
    }

    [self.view showHUD:LLang(@"发送中...")];
    WKRegisterVM *vm = (WKRegisterVM *)self.viewModel;
    __weak typeof(self) weakSelf = self;
    [vm emailSendCode:email codeType:0].then(^(id result) {
        [weakSelf.view switchHUDSuccess:LLang(@"验证码已发送")];
        [weakSelf startCountdown];
    }).catch(^(NSError *error) {
        [weakSelf.view switchHUDError:error.domain ?: LLang(@"发送失败")];
    });
}

-(void) startCountdown {
    self.codeStatus = CodeStatusCountdown;
    self.countdownSec = 60;
    [self.getCodeBtn setTitle:[NSString stringWithFormat:@"%lds", (long)self.countdownSec] forState:UIControlStateNormal];
    self.getCodeBtn.alpha = 0.5;
    self.codeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(countdownTick) userInfo:nil repeats:YES];
}

-(void) countdownTick {
    self.countdownSec--;
    if (self.countdownSec <= 0) {
        [self.codeTimer invalidate];
        self.codeTimer = nil;
        self.codeStatus = CodeStatusDefault;
        [self.getCodeBtn setTitle:LLang(@"获取验证码") forState:UIControlStateNormal];
        self.getCodeBtn.alpha = 1.0;
    } else {
        [self.getCodeBtn setTitle:[NSString stringWithFormat:@"%lds", (long)self.countdownSec] forState:UIControlStateNormal];
    }
}

-(void) registerBtnPressed {
    NSString *account = self.mobileTextField.text;
    NSString *nickname = self.nicknameTextField.text;
    NSString *password = self.passwordTextField.text;
    NSString *inviteCode = self.inviteCodeTextField.text;
    NSString *code = [self needsVerificationCode] ? self.codeTextField.text : @"";

    if ([account isEqualToString:@""]) {
        [self.view showHUDWithHide:[self needsVerificationCode] ? LLang(@"邮箱不能为空！") : LLang(@"账号不能为空！")];
        return;
    }
    if ([self needsVerificationCode] && [code isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"验证码不能为空！")];
        return;
    }
    if ([nickname isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"昵称不能为空！")];
        return;
    }
    if ([password isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"密码不能为空！")];
        return;
    }
    if(WKApp.shared.remoteConfig.registerInviteOn && [inviteCode isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"邀请码不能为空！")];
        return;
    }

    [self.view showHUD:LLang(@"注册中")];
    __weak typeof(self) weakSelf = self;

    [self.viewModel emailRegister:account code:code name:nickname password:password inviteCode:inviteCode].then(^(WKLoginResp*resp){
        [weakSelf.view hideHud];
        [WKLoginVM handleLoginData:resp isSave:YES];

        if(inviteCode && ![inviteCode isEqualToString:@""]) {
            WKSpaceGateVM *spaceVM = [WKSpaceGateVM new];
            [spaceVM getMySpaces].then(^(NSArray *spaces){
                if(spaces && spaces.count > 0) {
                    NSDictionary *firstSpace = spaces[0];
                    NSString *spaceId = firstSpace[@"space_id"];
                    if(spaceId && spaceId.length > 0) {
                        [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
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
        } else {
            WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
            [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
        }
    }).catch(^(NSError *error){
        [weakSelf.view switchHUDError:error.domain];
    });
}

#pragma mark - M80AttributedLabelDelegate

- (void)m80AttributedLabel:(M80AttributedLabel *)label clickedOnLink:(id)linkData {
    WKWebViewVC *vc = [WKWebViewVC new];
    vc.url = [NSURL URLWithString:linkData];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

- (void)dealloc {
    if (self.codeTimer) {
        [self.codeTimer invalidate];
        self.codeTimer = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
