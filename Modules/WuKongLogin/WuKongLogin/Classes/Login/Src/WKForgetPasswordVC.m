// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKForgetPasswordVC.m
//  WuKongLogin
//
//  Created by tt on 2020/10/27.
//

#import "WKForgetPasswordVC.h"
#import "WKCountrySelectVC.h"
#import "WKForgetPasswordVM.h"
typedef enum : NSUInteger {
    CodeStatusNormal, // 正常
    CodeStatusGeting, // 获取中
    CodeStatusCountdown // 倒计时中
} CodeStatus;

static int lastGetCodeTimestamp = 0; // 最后一次获取验证码的时间戳（单位秒）

@interface WKForgetPasswordVC ()<UITextFieldDelegate>



@property(nonatomic,strong) UIImageView *bgImgView; // 背景图
@property(nonatomic,strong) UILabel *titleLbl; // 标题
@property(nonatomic,strong) UILabel *subtitleLbl; // 子标题

// ---------- 手机号输入相关 ----------
@property(nonatomic,strong) UIView *mobileBoxView; // 手机号输入的box view
@property(nonatomic,strong) UIButton *countryBtn; // 国家区号
@property(nonatomic,strong) UIImageView *downArrowView; // 向下的小箭头

@property(nonatomic,strong) UIView *countrySpliteLineView; // 分割线
@property(nonatomic,strong) UITextField *mobileTextField; // 手机输入
@property(nonatomic,strong) UIView *mobileBottomLineView; // 手机号底部输入线

// ---------- 短信验证码相关 ----------
@property(nonatomic,strong) UIView *codeBoxView; // 验证码输入的box view
@property(nonatomic,strong) UIView *codeLineView; // 验证码底部输入线
@property(nonatomic,strong) UITextField *codeTextField; // 验证码输入
@property(nonatomic,strong) UIButton *getCodeBtn; // 获取验证码的按钮
@property(nonatomic,assign) CodeStatus status;
@property(nonatomic, strong) NSTimer *codeTimer;
@property(nonatomic) NSInteger countdownSec; //倒计时

// ---------- 新密码输入相关 ----------
@property(nonatomic,strong) UIView *passwordBoxView; // 密码输入的box view
@property(nonatomic,strong) UIView *passwordBottomLineView; // 密码底部输入线
@property(nonatomic,strong) UITextField *passwordTextField; // 新密码输入
@property(nonatomic,strong) UIButton *eyeBtn; // 眼睛关闭

// ---------- 确认新密码相关 ----------
@property(nonatomic,strong) UIView *confirmPasswordBoxView;
@property(nonatomic,strong) UIView *confirmPasswordBottomLineView;
@property(nonatomic,strong) UITextField *confirmPasswordTextField;
@property(nonatomic,strong) UIButton *confirmEyeBtn;

// ---------- 底部相关 ----------
@property(nonatomic,strong) UIButton *okBtn; // 重置密码按钮


@end

@implementation WKForgetPasswordVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKForgetPasswordVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [self.view addSubview:self.bgImgView];
    [super viewDidLoad];
    self.title = LLang(@"忘记密码");

    [self.navigationBar setBackgroundColor:[UIColor clearColor]];

    [self.view addSubview:self.titleLbl];
    [self.view addSubview:self.subtitleLbl];

    [self.view addSubview:self.mobileBoxView];
    // 隐藏区号选择器，因为现在只支持邮箱
    // [self.mobileBoxView addSubview:self.countryBtn];
    // [self updateCountryBtnTitle];
    // [self.mobileBoxView addSubview:self.downArrowView];
    // [self.mobileBoxView addSubview:self.countrySpliteLineView];
    [self.mobileBoxView addSubview:self.mobileTextField];
    [self.mobileBoxView addSubview:self.mobileBottomLineView];
    
    [self.view addSubview:self.codeBoxView];
    [self.codeBoxView addSubview:self.codeLineView];
    [self.codeBoxView addSubview:self.codeTextField];
    [self.codeBoxView addSubview:self.getCodeBtn];
    
    [self.view addSubview:self.passwordBoxView];
    [self.passwordBoxView addSubview:self.passwordBottomLineView];
    [self.passwordBoxView addSubview:self.passwordTextField];
    [self.passwordBoxView addSubview:self.eyeBtn];

    [self.view addSubview:self.confirmPasswordBoxView];
    [self.confirmPasswordBoxView addSubview:self.confirmPasswordBottomLineView];
    [self.confirmPasswordBoxView addSubview:self.confirmPasswordTextField];
    [self.confirmPasswordBoxView addSubview:self.confirmEyeBtn];

    [self.view addSubview:self.okBtn];
    
}

- (NSString *)country {
    if(!_country) {
        return @"86";
    }
    return _country;
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
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:LLang(@"验证您的邮箱") attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size: 20],NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0]}];
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, self.navigationBar.lim_bottom+10.0f, WKScreenWidth-60, 22)];
        _titleLbl.attributedText = string;
        _titleLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLbl;
}

- (UILabel *)subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, self.titleLbl.lim_bottom + 10.0f , WKScreenWidth-15.0*2, 32.0f)];
        _subtitleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _subtitleLbl.text = [NSString stringWithFormat:LLang(@"%@会发送验证码到您的邮箱，请输入您收到的验证码"),[WKApp shared].config.appName];
        _subtitleLbl.textColor = [WKApp shared].config.tipColor;
        _subtitleLbl.textAlignment = NSTextAlignmentCenter;
        _subtitleLbl.numberOfLines = 0;
    }
    return _subtitleLbl;
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
        _mobileTextField.placeholder = LLang(@"邮箱地址");
        _mobileTextField.keyboardType = UIKeyboardTypeEmailAddress;
        _mobileTextField.returnKeyType = UIReturnKeyNext;
        _mobileTextField.delegate = self;
        _mobileTextField.text = self.mobile;
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

// ---------- 短信验证码相关 ----------

- (UIView *)codeBoxView {
    if(!_codeBoxView) {
        _codeBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.mobileBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
       // [_passwordBoxView setBackgroundColor:[UIColor grayColor]];
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
    }
    return _getCodeBtn;
}

// ---------- 密码输入 ----------

- (UIView *)passwordBoxView {
    if(!_passwordBoxView) {
        _passwordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.codeBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
       // [_passwordBoxView setBackgroundColor:[UIColor grayColor]];
    }
    return _passwordBoxView;
}
- (UIView *)passwordBottomLineView {
    if(!_passwordBottomLineView) {
        _passwordBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _passwordBottomLineView.layer.backgroundColor =[WKApp shared].config.lineColor.CGColor;
        
    }
    return _passwordBottomLineView;
}

- (UITextField *)passwordTextField {
    if(!_passwordTextField) {
        _passwordTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        [_passwordTextField setPlaceholder:LLang(@"请输入新密码")];
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



// ---------- 确认新密码 ----------

- (UIView *)confirmPasswordBoxView {
    if(!_confirmPasswordBoxView) {
        _confirmPasswordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.passwordBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
    }
    return _confirmPasswordBoxView;
}

- (UIView *)confirmPasswordBottomLineView {
    if(!_confirmPasswordBottomLineView) {
        _confirmPasswordBottomLineView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, self.confirmPasswordBoxView.lim_height, WKScreenWidth-40.0f, 1)];
        _confirmPasswordBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    }
    return _confirmPasswordBottomLineView;
}

- (UITextField *)confirmPasswordTextField {
    if(!_confirmPasswordTextField) {
        _confirmPasswordTextField = [[UITextField alloc] initWithFrame:CGRectMake(20.0f, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth-20*2 - 32.0f, 40.0f)];
        [_confirmPasswordTextField setPlaceholder:LLang(@"确认新密码")];
        _confirmPasswordTextField.returnKeyType = UIReturnKeyDone;
        _confirmPasswordTextField.secureTextEntry = YES;
        _confirmPasswordTextField.delegate = self;
    }
    return _confirmPasswordTextField;
}

- (UIButton *)confirmEyeBtn {
    if(!_confirmEyeBtn) {
        CGFloat width = 32.0f;
        CGFloat height = 32.0f;
        _confirmEyeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.view.lim_width - 20.0f - width, self.confirmPasswordBoxView.lim_height/2.0f - (height)/2.0f, width, height)];
        [_confirmEyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOff" moduleID:@"WuKongLogin"] forState:UIControlStateNormal];
        [_confirmEyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOn" moduleID:@"WuKongLogin"] forState:UIControlStateSelected];
        _confirmEyeBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_confirmEyeBtn setImageEdgeInsets:UIEdgeInsetsMake(height/4.0f, width, height/4.0f, width)];
        [_confirmEyeBtn addTarget:self action:@selector(confirmPasswordLookPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _confirmEyeBtn;
}

// ---------- 底部相关 ----------


- (UIButton *)okBtn {
    if(!_okBtn) {
        _okBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f, self.confirmPasswordBoxView.lim_bottom+40.0f, WKScreenWidth - 60.0f, 40.0f)];
        [_okBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_okBtn setTitle:LLang(@"重置密码") forState:UIControlStateNormal];
        [_okBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _okBtn.layer.masksToBounds = YES;
        _okBtn.layer.cornerRadius = 4.0f;
        [_okBtn addTarget:self action:@selector(okBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        
        CAGradientLayer *gl = [CAGradientLayer layer];
        gl.frame =_okBtn.bounds;
        gl.startPoint = CGPointMake(0, 0);
        gl.endPoint = CGPointMake(1, 1);
        gl.colors = @[(__bridge id)[UIColor colorWithRed:78/255.0 green:80/255.0 blue:252/255.0 alpha:1.0].CGColor, (__bridge id)[UIColor colorWithRed:149/255.0 green:85/255.0 blue:241/255.0 alpha:1.0].CGColor];
        gl.locations = @[@(0), @(1.0f)];
        
        [WKApp.shared.config setThemeStyleButton:_okBtn];
        
    }
    return _okBtn;
}


#pragma mark - 事件
// 跳到注册页面
-(void) toLoginPressed{
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

// 新密码小眼睛点击
-(void) passwordLookPressed:(UIButton*)btn {
    btn.selected = !btn.selected;
    _passwordTextField.secureTextEntry = !btn.selected;
}
// 确认密码小眼睛点击
-(void) confirmPasswordLookPressed:(UIButton*)btn {
    btn.selected = !btn.selected;
    _confirmPasswordTextField.secureTextEntry = !btn.selected;
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
// 判断是否为邮箱
- (BOOL)isEmailAddress:(NSString *)text {
    if (!text || text.length == 0) {
        return NO;
    }
    NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}";
    NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailPredicate evaluateWithObject:text];
}

// 判断是否为纯数字
- (BOOL)isPhoneNumber:(NSString *)text {
    if (!text || text.length == 0) {
        return NO;
    }
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [text rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

// 获取验证码
-(void) sendCode {
    int now = [[NSDate date] timeIntervalSince1970];
    if(now - lastGetCodeTimestamp< 60 ) {
        [self.view showHUDWithHide:[NSString stringWithFormat:LLang(@"发送验证码过于频繁，请在%d秒后重试"),(60 - (now-lastGetCodeTimestamp))]];
        return;
    }

    NSString *email = self.mobileTextField.text;

    // 邮箱格式验证
    if (![self isEmailAddress:email]) {
        [self.view showHUDWithHide:LLang(@"邮箱格式不正确！")];
        return;
    }

    self.status = CodeStatusGeting;
    [self refreshSendCode];
    __weak typeof(self) weakSelf = self;

    // 邮箱忘记密码，code_type = 2
    [self.viewModel emailSendCode:email codeType:2].then(^(NSDictionary *resultDic){
        if(resultDic && resultDic[@"exist"] && [resultDic[@"exist"] integerValue] == 1) {
            weakSelf.status = CodeStatusNormal;
            [weakSelf refreshSendCode];
            [WKAlertUtil alert:LLang(@"邮箱已注册,去登录？") buttonsStatement:@[LLang(@"取消"),LLang(@"去登录")] chooseBlock:^(NSInteger buttonIdx) {
                if(buttonIdx == 1) {
                    [[WKNavigationManager shared] popViewControllerAnimated:YES];
                    return;
                }
            }];
            return;
        }
        [WKApp shared].loginInfo.extra[@"email"] = email;
        lastGetCodeTimestamp = [[NSDate date] timeIntervalSince1970];
        [weakSelf startCountDown]; // 开始倒计时
        weakSelf.mobileTextField.enabled = NO; // 禁用输入框
    }).catch(^(NSError *error){
        [weakSelf.view showHUDWithHide:error.domain];
        weakSelf.status = CodeStatusNormal;
        [weakSelf refreshSendCode];
    });

}

-(void) startCountDown {
    self.countdownSec = 60.0f; // 60秒倒计时
    self.status = CodeStatusCountdown;
    [self refreshSendCode];
    _codeTimer =
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(refreshSendCode)
                                   userInfo:nil
                                    repeats:YES];
}

-(void) refreshSendCode {
    if(self.status == CodeStatusNormal) {
        self.getCodeBtn.alpha = 1.0f;
        self.getCodeBtn.enabled = YES;
        [self.getCodeBtn setTitle:LLang(@"获取验证码") forState:UIControlStateNormal];
    }else if(self.status == CodeStatusGeting) {
        self.getCodeBtn.alpha = 0.5f;
        self.getCodeBtn.enabled = NO;
        [self.getCodeBtn setTitle:LLang(@"获取中") forState:UIControlStateNormal];
    }else if(self.status == CodeStatusCountdown) {
        if(self.countdownSec<=1) {
            [_codeTimer invalidate];
            _codeTimer = nil;
            self.status = CodeStatusNormal;
            [self refreshSendCode];
            return;
        }
        self.getCodeBtn.alpha = 0.5f;
        self.getCodeBtn.enabled = NO;
        [_getCodeBtn setTitle:[NSString stringWithFormat:LLang(@"重新发送(%li)"),(long)--self.countdownSec] forState:UIControlStateNormal];
        
    }
    
}

-(void) okBtnPressed {
    NSString *code = self.codeTextField.text;
    NSString *email = self.mobileTextField.text;
    NSString *password = self.passwordTextField.text;
    NSString *confirmPassword = self.confirmPasswordTextField.text;

    __weak typeof(self) weakSelf = self;
    if([email isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"邮箱不能为空！")];
        return;
    }
    // 邮箱格式验证
    if (![self isEmailAddress:email]) {
        [self.view showHUDWithHide:LLang(@"邮箱格式不正确！")];
        return;
    }
    if([code isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"验证码不能为空！")];
        return;
    }
    if([password isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"新密码不能为空！")];
        return;
    }
    if (password.length < 6 || password.length > 16) {
        [self.view showHUDWithHide:LLang(@"密码长度为6-16位！")];
        return;
    }
    if(![password isEqualToString:confirmPassword]) {
        [self.view showHUDWithHide:LLang(@"两次密码输入不一致！")];
        return;
    }

    [self.view showHUD];

    // 邮箱忘记密码
    [self.viewModel emailForgetPwd:email code:code pwd:password].then(^{
        [weakSelf.view switchHUDSuccess:LLang(@"密码重置成功，请登录")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        });
    }).catch(^(NSError *error){
        [weakSelf.view switchHUDError:error.domain];
    });

}

#pragma mark -- 委托
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    // 邮箱输入不限制长度
    return true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(_passwordTextField == textField) {
       
    }
    return YES;
}
- (void)dealloc {
    if(self.codeTimer) {
        [self.codeTimer invalidate];
        self.codeTimer = nil;
    }
}


@end
