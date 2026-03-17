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
#import <M80AttributedLabel/M80AttributedLabel.h>
// 验证码相关的枚举和变量已移除

@interface WKRegisterVC ()<UITextFieldDelegate,M80AttributedLabelDelegate>


@property(nonatomic,strong) UIImageView *bgImgView; // 背景图
@property(nonatomic,strong) UILabel *titleLbl; // 欢迎标题

// ---------- 账号输入相关 ----------
@property(nonatomic,strong) UIView *mobileBoxView; // 账号输入的box view
@property(nonatomic,strong) UIButton *countryBtn; // 国家区号
@property(nonatomic,strong) UIImageView *downArrowView; // 向下的小箭头
@property(nonatomic,strong) NSString *country;
@property(nonatomic,strong) UIView *countrySpliteLineView; // 分割线
@property(nonatomic,strong) UITextField *mobileTextField; // 账号输入
@property(nonatomic,strong) UIView *mobileBottomLineView; // 账号底部输入线

// ---------- 短信验证码相关（已移除） ----------
// @property(nonatomic,strong) UIView *codeBoxView;
// @property(nonatomic,strong) UIView *codeLineView;
// @property(nonatomic,strong) UITextField *codeTextField;
// @property(nonatomic,strong) UIButton *getCodeBtn;
// @property(nonatomic,assign) CodeStatus status;
// @property(nonatomic, strong) NSTimer *codeTimer;
// @property(nonatomic) NSInteger countdownSec;

// ---------- 昵称输入相关 ----------
@property(nonatomic,strong) UIView *nicknameBoxView; // 昵称输入的box view
@property(nonatomic,strong) UIView *nicknameBottomLineView; // 昵称底部输入线
@property(nonatomic,strong) UITextField *nicknameTextField; // 昵称输入

// ---------- 密码输入相关 ----------
@property(nonatomic,strong) UIView *passwordBoxView; // 密码输入的box view
@property(nonatomic,strong) UIView *passwordBottomLineView; // 密码底部输入线
@property(nonatomic,strong) UITextField *passwordTextField; // 密码输入
@property(nonatomic,strong) UIButton *eyeBtn; // 眼睛关闭

// ---------- 邀请码相关 ----------

@property(nonatomic,strong) UIView *inviteCodeBoxView; // 邀请码box view
@property(nonatomic,strong) UIView *inviteCodeBottomLineView; // 邀请码底部线
@property(nonatomic,strong) UITextField *inviteCodeTextField; // 邀请码输入框


// ---------- 底部相关 ----------
@property(nonatomic,strong) UIButton *registerBtn; // 注册按钮
@property(nonatomic,strong) UILabel *loginTipLbl; // 登录提示
@property(nonatomic,strong) UIButton *toLoginBtn; // 去登录

@property(nonatomic,strong) M80AttributedLabel *privacyLbl; // 隐私条款

@end

@implementation WKRegisterVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKRegisterVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationBar.hidden = YES;
     _country = @"86";
    [self.view addSubview:self.bgImgView];
    [self.view addSubview:self.titleLbl];

    [self.view addSubview:self.mobileBoxView];
    // 隐藏区号选择器，因为现在只支持邮箱注册
    // [self.mobileBoxView addSubview:self.countryBtn];
    // [self updateCountryBtnTitle];
    // [self.mobileBoxView addSubview:self.downArrowView];
    // [self.mobileBoxView addSubview:self.countrySpliteLineView];
    [self.mobileBoxView addSubview:self.mobileTextField];
    [self.mobileBoxView addSubview:self.mobileBottomLineView];

    // 隐藏验证码输入框
    // [self.view addSubview:self.codeBoxView];
    // [self.codeBoxView addSubview:self.codeLineView];
    // [self.codeBoxView addSubview:self.codeTextField];
    // [self.codeBoxView addSubview:self.getCodeBtn];

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
    
}

- (WKBaseVM *)viewModel {
    return [WKRegisterVM new];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}


#pragma mark -- 视图初始化

// ---------- 背景图片 ----------
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
// ---------- 手机号输入 ----------

- (UIView *)mobileBoxView {
    if(!_mobileBoxView) {
        _mobileBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 190.0f, WKScreenWidth, 40.0f)];
        //[_mobileBoxView setBackgroundColor:[UIColor redColor]];
    }
    return _mobileBoxView;
}
- (UIButton *)countryBtn {
    if(!_countryBtn) {
        _countryBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, self.mobileBoxView.lim_height/2.0f - 10.0f, 70.0f, 20.0f)];
        
        [[_countryBtn titleLabel] setFont:WKApp.shared.config.defaultFont];
        [_countryBtn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
        [_countryBtn addTarget:self action:@selector(countryBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _countryBtn;
}
- (UIImageView *)downArrowView {
    if(!_downArrowView) {
        _downArrowView = [[UIImageView alloc] initWithFrame:CGRectMake(self.countryBtn.lim_right-12.0f, self.mobileBoxView.lim_height/2.0f - 6.0f, 12.0f, 12.0f)];
        [_downArrowView setImage:[[WKApp shared] loadImage:@"ArrowDown" moduleID:@"WuKongLogin"]];
    }
    return _downArrowView;
}
-(void) updateCountryBtnTitle {
    [self.countryBtn setTitle:[NSString stringWithFormat:@"+ %@",_country] forState:UIControlStateNormal];
}
- (UIView *)countrySpliteLineView {
    if(!_countrySpliteLineView) {
        _countrySpliteLineView = [[UIView alloc] initWithFrame:CGRectMake(self.countryBtn.lim_right+10.0f,self.mobileBoxView.lim_height/2.0f - 5.0f,1,10)];
        _countrySpliteLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
       
    }
    return _countrySpliteLineView;
}

-(UITextField*) mobileTextField {
    if(!_mobileTextField) {
        _mobileTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth - 40.0f, 40.0f)];
        _mobileTextField.placeholder = LLang(@"请输入账号（可以是任意字符）");
        _mobileTextField.keyboardType = UIKeyboardTypeDefault;
        _mobileTextField.returnKeyType = UIReturnKeyNext;
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

// ---------- 短信验证码相关（已移除）----------
/*
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
        _codeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.codeBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-self.codeLineView.lim_left - 80.0f, 40.0f)];
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
        _getCodeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.codeTextField.lim_width, self.codeTextField.lim_top, 80.0f, height)];
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
*/

// ---------- 昵称输入 ----------

- (UIView *)nicknameBoxView {
    if(!_nicknameBoxView) {
        // 验证码框已隐藏，昵称框直接在手机号框下面
        _nicknameBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.mobileBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
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

// ---------- 密码输入 ----------

- (UIView *)passwordBoxView {
    if(!_passwordBoxView) {
        _passwordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.nicknameBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
       // [_passwordBoxView setBackgroundColor:[UIColor grayColor]];
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
        [_eyeBtn setImageEdgeInsets:UIEdgeInsetsMake(height/4.0f, width, height/4.0f,  width)];
        [_eyeBtn addTarget:self action:@selector(passwordLookPressed:) forControlEvents:UIControlEventTouchUpInside];
       // [_eyeBtn setBackgroundColor:[UIColor redColor]];
    }
    return _eyeBtn;
}


// ---------- 邀请码 ----------

- (UIView *)inviteCodeBoxView {
    if(!_inviteCodeBoxView) {
        _inviteCodeBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.passwordBoxView.lim_bottom+20.0f, WKScreenWidth, self.passwordBoxView.lim_height)];
    }
    return _inviteCodeBoxView;
}

- (UITextField *)inviteCodeTextField {
    if(!_inviteCodeTextField) {
        _inviteCodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        
        _inviteCodeTextField.hidden = !WKApp.shared.remoteConfig.registerInviteOn;
        if(WKApp.shared.remoteConfig.registerInviteOn) {
            [_inviteCodeTextField setPlaceholder:LLang(@"邀请码（必填）")];
        }else {
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



// ---------- 底部相关 ----------


// 注册
- (UIButton *)registerBtn {
    if(!_registerBtn) {
        CGFloat top = self.passwordBoxView.lim_bottom;
        if(WKApp.shared.remoteConfig.registerInviteOn) {
            top = self.inviteCodeBoxView.lim_bottom;
        }
        _registerBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f,top+82.0f, WKScreenWidth - 60.0f, 40.0f)];
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

#pragma mark - 事件
// 跳到注册页面
-(void) toLoginPressed{
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

// 密码那个小眼睛点击
-(void) passwordLookPressed:(UIButton*)btn {
    btn.selected = !btn.selected;
    _passwordTextField.secureTextEntry = !btn.selected;
}
// 国家点击
-(void) countryBtnPressed {
    WKCountrySelectVC *vc = [WKCountrySelectVC new];
    vc.onFinished = ^(NSDictionary *data) {
        self->_country = [data[@"code"] stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@""];
        if(self.mobileTextField.text.length>11) {
            self.mobileTextField.text = [self.mobileTextField.text substringToIndex:11];
        }
        [self updateCountryBtnTitle];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [[[WKNavigationManager shared] topViewController] presentViewController:nav animated:YES completion:nil];
}
// 获取验证码相关方法已移除，不再需要验证码验证

-(void) registerBtnPressed {
    NSString *account = self.mobileTextField.text;
    NSString *nickname = self.nicknameTextField.text;
    NSString *password = self.passwordTextField.text;
    NSString *inviteCode = self.inviteCodeTextField.text;

    // 验证必填项 - 移除格式限制
    if ([account isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"账号不能为空！")];
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
    // 移除密码长度限制

    // 检查邀请码（如果需要）
    if(WKApp.shared.remoteConfig.registerInviteOn && [inviteCode isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"邀请码不能为空！")];
        return;
    }

    [self.view showHUD:LLang(@"注册中")];
    __weak typeof(self) weakSelf = self;

    // 注册，不需要验证码
    [self.viewModel emailRegister:account code:@"" name:nickname password:password inviteCode:inviteCode].then(^(WKLoginResp*resp){
        [weakSelf.view hideHud];
        // 保存登录信息
        [WKLoginVM handleLoginData:resp isSave:YES];

        if(inviteCode && ![inviteCode isEqualToString:@""]) {
            // 有邀请码，注册时服务端已通过邀请码加入空间，检查后直接进入
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
                    // 邀请码未能加入空间，仍显示引导页
                    WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
                    [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
                }
            }).catch(^(NSError *error){
                WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
                [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
            });
        } else {
            // 没有邀请码，显示SpaceGate引导页
            WKSpaceGateVC *spaceGateVC = [WKSpaceGateVC new];
            [[WKNavigationManager shared] pushViewController:spaceGateVC animated:YES];
        }
    }).catch(^(NSError *error){
        [weakSelf.view switchHUDError:error.domain];
    });
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
        [_privacyLbl appendText:LLang(@"点击“注册”即表示已阅读并同意")];
        NSString *uPTxt = LLang(@"用户协议");
        [_privacyLbl addCustomLink:[WKApp shared].config.userAgreementUrl forRange:NSMakeRange(_privacyLbl.text.length, uPTxt.length)];
        [_privacyLbl appendText:uPTxt];
        [_privacyLbl appendText:@"、"];
        NSString *pPTxt = LLang(@"隐私政策");
        [_privacyLbl addCustomLink:[WKApp shared].config.privacyAgreementUrl forRange:NSMakeRange(_privacyLbl.text.length, pPTxt.length)];
        [_privacyLbl appendText:pPTxt];
        
        [_privacyLbl sizeToFit];
        _privacyLbl.lim_centerX_parent = self.view;
        _privacyLbl.lim_top = WKScreenHeight - ( bottom + 30.0f);
    }
    return _privacyLbl;
}

#pragma mark -- M80AttributedLabelDelegate

- (void)m80AttributedLabel:(M80AttributedLabel *)label clickedOnLink:(id)linkData {
    WKWebViewVC *vc = [WKWebViewVC new];
    vc.url = [NSURL URLWithString:linkData];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark -- 委托
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    // 邮箱注册不限制输入长度
    return true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(_passwordTextField == textField) {
       
    }
    return YES;
}
- (void)dealloc {
    // 验证码timer已移除
}

@end
