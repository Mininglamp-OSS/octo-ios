//
//  WKLogicView.m
//  WuKongLogin
//
//  Created by tt on 2019/12/2.
//

#import "WKLoginView.h"
#import <Masonry/Masonry.h>
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKImageView.h>
#import <WuKongBase/WKButton.h>
#import "WKCountrySelectVC.h"
#import "WKRegisterVC.h"
#import "WKForgetPasswordVC.h"
#import "WKAuthWebViewVC.h"
#import <WuKongBase/WKServerSettingHelper.h>
#import <WuKongBase/WKWebViewVC.h>

// 登录页根据 appconfig 下发的 oidc_providers 在两种形态切换:
//   Octo:    无 SSO provider → 现有 Octo 账号密码登录布局 (form + login + register)
//   SsoOnly: 有 SSO provider → app logo + 居中欢迎标题 + 主 SSO 按钮 + helper 文案
// 互斥, 由 -computeMode 控制。和 web dmworklogin 行为差异: web SSO 模式下保留 Octo
// 表单作为「已有账号」备用入口; iOS 这里按产品要求彻底隐藏 Octo, 没有备用入口。
typedef NS_ENUM(NSUInteger, WKLoginViewMode) {
    WKLoginViewModeOcto = 0,
    WKLoginViewModeSsoOnly,
};

// 服务条款 / 隐私协议 PDF 走静态 CDN, WKWebView 原生支持 PDF 直显。
// 由 OctoConfig.xcconfig 的 OCTO_TERMS_URL / OCTO_PRIVACY_URL 注入,
// 私有部署可改写, 见 [WKApp shared].config.octoTermsURL / octoPrivacyURL。

@interface WKLoginView() <UITextFieldDelegate> {
}

@property(nonatomic,assign) WKLoginViewMode currentMode;

@property(nonatomic,strong) UIImageView *bgImgView; // 背景图
@property(nonatomic,strong) UILabel *welcomeTitleLbl; // 欢迎标题

// SsoOnly 模式才用的 hero logo
@property(nonatomic,strong) UIImageView *heroLogoView;

// ---------- 手机号输入相关 ----------
@property(nonatomic,strong) UIView *mobileBoxView; // 手机号输入的box view
@property(nonatomic,strong) UIButton *countryBtn; // 国家区号
@property(nonatomic,strong) UIImageView *downArrowView; // 向下的小箭头
@property(nonatomic,strong) UIView *countrySpliteLineView; // 分割线
@property(nonatomic,strong) UITextField *mobileTextField; // 手机输入
@property(nonatomic,strong) UIView *mobileBottomLineView; // 手机号底部输入线

// ---------- 密码输入相关 ----------
@property(nonatomic,strong) UIView *passwordBoxView; // 密码输入的box view
@property(nonatomic,strong) UIView *passwordBottomLineView; // 密码底部输入线
@property(nonatomic,strong) UITextField *passwordTextField; // 密码输入
@property(nonatomic,strong) UIButton *eyeBtn; // 眼睛关闭

// ---------- 底部相关 ----------
@property(nonatomic,strong) UIButton *forgetPwdBtn; // 忘记密码
@property(nonatomic,strong) UIButton *loginBtn; // 登录按钮
@property(nonatomic,strong) UILabel *registerTipLbl; // 注册提示
@property(nonatomic,strong) UIButton *registerBtn; // 注册

// ---------- SSO 区 ----------
@property(nonatomic,strong) UILabel *ssoSubtitleLbl; // SsoOnly 形态欢迎标题下的双行说明
@property(nonatomic,strong) UIButton *ssoBtn;
@property(nonatomic,strong) UILabel *ssoHelperLbl; // 按钮下方的 "身份认证由 X 提供 · 企业级安全"
@property(nonatomic,strong) WKOidcProviderConfig *currentProvider;
@property(nonatomic,assign) BOOL ssoInFlight; // 防止连续点击重复 push 授权页

// ---------- 协议入口 ----------
@property(nonatomic,strong) UIButton *termsBtn;
@property(nonatomic,strong) UILabel *legalDotLbl;
@property(nonatomic,strong) UIButton *privacyBtn;

@end

@implementation WKLoginView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _country = @"86";
    _currentMode = WKLoginViewModeOcto;

    [self addSubview:self.bgImgView];
    [self addSubview:self.heroLogoView];
    [self addSubview:self.welcomeTitleLbl];
    self.welcomeTitleLbl.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(serverSettingLongPressed:)];
    longPress.minimumPressDuration = 1.5;
    [self.welcomeTitleLbl addGestureRecognizer:longPress];

    [self addSubview:self.mobileBoxView];
    // 区号选择器默认隐藏，输入纯数字时才显示
    [self.mobileBoxView addSubview:self.countryBtn];
    self.countryBtn.hidden = YES;
    [self updateCountryBtnTitle];
    [self.mobileBoxView addSubview:self.downArrowView];
    self.downArrowView.hidden = YES;
    [self.mobileBoxView addSubview:self.countrySpliteLineView];
    self.countrySpliteLineView.hidden = YES;
    [self.mobileBoxView addSubview:self.mobileTextField];
    [self.mobileBoxView addSubview:self.mobileBottomLineView];

    [self addSubview:self.passwordBoxView];
    [self.passwordBoxView addSubview:self.passwordBottomLineView];
    [self.passwordBoxView addSubview:self.passwordTextField];
    [self.passwordBoxView addSubview:self.eyeBtn];

    [self addSubview:self.forgetPwdBtn];
    [self addSubview:self.loginBtn];
    [self addSubview:self.registerTipLbl];
    [self addSubview:self.registerBtn];

    [self addSubview:self.ssoBtn];
    [self addSubview:self.ssoSubtitleLbl];
    [self addSubview:self.ssoHelperLbl];

    [self addSubview:self.termsBtn];
    [self addSubview:self.legalDotLbl];
    [self addSubview:self.privacyBtn];

    [self refreshDynamicConfig];

    return self;
}

#pragma mark -- 视图初始化

// ---------- 背景图片 ----------
- (UIImageView *)bgImgView {
    if(!_bgImgView) {
        _bgImgView = [[UIImageView alloc] initWithImage:[[WKApp shared] loadImage:@"Background" moduleID:@"WuKongLogin"]];
        _bgImgView.frame = self.bounds;
    }
    return _bgImgView;
}

// ---------- Hero Logo (SsoOnly) ----------
- (UIImageView *)heroLogoView {
    if(!_heroLogoView) {
        _heroLogoView = [[UIImageView alloc] init];
        _heroLogoView.contentMode = UIViewContentModeScaleAspectFit;
        _heroLogoView.image = [WKApp appLaunchIcon];
        // 圆角和 app 图标在 home screen 上的视觉一致 (iOS 默认 ~22.37% 圆角率, 80pt 取 18pt)
        _heroLogoView.layer.masksToBounds = YES;
        _heroLogoView.layer.cornerRadius = 18.0f;
        _heroLogoView.hidden = YES; // 默认 Octo 模式隐藏
    }
    return _heroLogoView;
}

// ---------- 欢迎标题 ----------
- (UILabel *)welcomeTitleLbl {
    if(!_welcomeTitleLbl) {
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:LLang(@"欢迎登录%@"),[WKApp shared].config.appName] attributes: @{NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size: 32],NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0]}];
        _welcomeTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(30, 93, WKScreenWidth-60, 50)];
        _welcomeTitleLbl.attributedText = string;
        _welcomeTitleLbl.textAlignment = NSTextAlignmentLeft;
    }
    return _welcomeTitleLbl;
}

// ---------- 手机号输入 ----------

- (UIView *)mobileBoxView {
    if(!_mobileBoxView) {
        _mobileBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, 240.0f, WKScreenWidth, 40.0f)];
        //[_mobileBoxView setBackgroundColor:[UIColor redColor]];
        _mobileBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
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
-(void) updateCountryBtnTitle {
    [self.countryBtn setTitle:[NSString stringWithFormat:@"+ %@",_country] forState:UIControlStateNormal];
}
- (UIImageView *)downArrowView {
    if(!_downArrowView) {
        _downArrowView = [[UIImageView alloc] initWithFrame:CGRectMake(self.countryBtn.lim_right-12.0f, self.mobileBoxView.lim_height/2.0f - 6.0f, 12.0f, 12.0f)];
        [_downArrowView setImage:[[WKApp shared] loadImage:@"ArrowDown" moduleID:@"WuKongLogin"]];
    }
    return _downArrowView;
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
        CGFloat left = 20.0f;  // 默认从左边距开始，不保留区号空间
        _mobileTextField = [[UITextField alloc] initWithFrame:CGRectMake(left, self.mobileBoxView.lim_height/2.0f - 20.0f, WKScreenWidth - left - 20.0f, 40.0f)];
        _mobileTextField.placeholder = LLang(@"邮箱 / 用户名");
        _mobileTextField.keyboardType = UIKeyboardTypeDefault; // 改为支持字母和数字
        _mobileTextField.returnKeyType = UIReturnKeyNext;
        _mobileTextField.delegate = self;
        // 监听文本变化
        [_mobileTextField addTarget:self action:@selector(mobileTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
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

// ---------- 密码输入 ----------

- (UIView *)passwordBoxView {
    if(!_passwordBoxView) {
        _passwordBoxView = [[UIView alloc] initWithFrame:CGRectMake(0, self.mobileBoxView.lim_bottom+20.0f, WKScreenWidth, self.mobileBoxView.lim_height)];
       // [_passwordBoxView setBackgroundColor:[UIColor grayColor]];
        _passwordBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
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
        _eyeBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.lim_width - 20.0f - width, self.passwordBoxView.lim_height/2.0f - (height)/2.0f, width, height)];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOff" moduleID:@"WuKongLogin"] forState:UIControlStateNormal];
        [_eyeBtn setImage:[[WKApp shared] loadImage:@"BtnEyeOn" moduleID:@"WuKongLogin"] forState:UIControlStateSelected];
        _eyeBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_eyeBtn setImageEdgeInsets:UIEdgeInsetsMake(height/4.0f, width, height/4.0f,  width)];
        [_eyeBtn addTarget:self action:@selector(passwordLookPressed:) forControlEvents:UIControlEventTouchUpInside];
       // [_eyeBtn setBackgroundColor:[UIColor redColor]];
    }
    return _eyeBtn;
}

// ---------- 底部相关 ----------

// 忘记密码
- (UIButton *)forgetPwdBtn {
    if(!_forgetPwdBtn) {
        _forgetPwdBtn = [[UIButton alloc] initWithFrame:CGRectMake(20.0f, self.passwordBoxView.lim_bottom+15.0f, 60.0f, 17.0f)];
        [_forgetPwdBtn setTitle:LLang(@"忘记密码?") forState:UIControlStateNormal];
        [_forgetPwdBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_forgetPwdBtn titleLabel] setFont:[UIFont systemFontOfSize:12.0f]];
        [_forgetPwdBtn addTarget:self action:@selector(forgetPwdPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _forgetPwdBtn;
}

-(void) forgetPwdPressed {
    WKForgetPasswordVC *vc = [WKForgetPasswordVC new];
    vc.country = self.country;
    vc.mobile = self.mobileTextField.text;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

// 登录
- (UIButton *)loginBtn {
    if(!_loginBtn) {
        _loginBtn = [[UIButton alloc] initWithFrame:CGRectMake(30.0f, self.passwordBoxView.lim_bottom+82.0f, WKScreenWidth - 60.0f, 40.0f)];
//        [_loginBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_loginBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_loginBtn setTitle:LLang(@"登录") forState:UIControlStateNormal];
        [_loginBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _loginBtn.layer.masksToBounds = YES;
        _loginBtn.layer.cornerRadius = 4.0f;
        [_loginBtn addTarget:self action:@selector(loginBtnPressed) forControlEvents:UIControlEventTouchUpInside];

        [WKApp.shared.config setThemeStyleButton:_loginBtn];

    }
    return _loginBtn;
}

-(UILabel*) registerTipLbl {
    if(!_registerTipLbl) {
        _registerTipLbl = [[UILabel alloc] init];
        [_registerTipLbl setText:LLang(@"新用户？请")];
        [_registerTipLbl setFont:[UIFont systemFontOfSize:16.0f]];
        [_registerTipLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0]];
        [_registerTipLbl sizeToFit];
        _registerTipLbl.lim_top = self.loginBtn.lim_bottom + 25.0f;
        _registerTipLbl.lim_left = self.lim_width/2.0f - _registerTipLbl.lim_width/2.0f - 20.0f;
    }
    return _registerTipLbl;
}

- (UIButton *)registerBtn {
    if(!_registerBtn) {
        _registerBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.registerTipLbl.lim_right, self.registerTipLbl.lim_top-7.2f, 20.0f, 22.0f)];
        [_registerBtn setTitle:LLang(@"注册") forState:UIControlStateNormal];
        [_registerBtn sizeToFit];
        [_registerBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_registerBtn titleLabel] setFont:[UIFont systemFontOfSize:16.0f]];
        [_registerBtn addTarget:self action:@selector(toRegisterPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _registerBtn;
}

// ---------- SSO 区 ----------
- (UIButton *)ssoBtn {
    if(!_ssoBtn) {
        // 仅在 SsoOnly 模式下展示, 实际样式 (实心 themeColor + 锁图标) 在 -layoutSsoOnly 里 apply。
        _ssoBtn = [[UIButton alloc] init];
        _ssoBtn.layer.masksToBounds = YES;
        _ssoBtn.layer.cornerRadius = 4.0f;
        [[_ssoBtn titleLabel] setFont:[UIFont systemFontOfSize:15.0f]];
        [_ssoBtn addTarget:self action:@selector(ssoBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        _ssoBtn.hidden = YES;
    }
    return _ssoBtn;
}

- (UILabel *)ssoSubtitleLbl {
    if(!_ssoSubtitleLbl) {
        _ssoSubtitleLbl = [[UILabel alloc] init];
        _ssoSubtitleLbl.numberOfLines = 2;
        _ssoSubtitleLbl.font = [UIFont systemFontOfSize:14.0f];
        _ssoSubtitleLbl.textColor = [UIColor colorWithRed:140.0f/255.0f green:140.0f/255.0f blue:148.0f/255.0f alpha:1.0];
        _ssoSubtitleLbl.textAlignment = NSTextAlignmentLeft;
        _ssoSubtitleLbl.hidden = YES;
    }
    return _ssoSubtitleLbl;
}

- (UILabel *)ssoHelperLbl {
    if(!_ssoHelperLbl) {
        _ssoHelperLbl = [[UILabel alloc] init];
        _ssoHelperLbl.font = [UIFont systemFontOfSize:12.0f];
        _ssoHelperLbl.textColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0];
        _ssoHelperLbl.textAlignment = NSTextAlignmentCenter;
        _ssoHelperLbl.hidden = YES;
    }
    return _ssoHelperLbl;
}

// ---------- 协议入口 ----------
- (UIButton *)termsBtn {
    if(!_termsBtn) {
        _termsBtn = [[UIButton alloc] init];
        [_termsBtn setTitle:LLang(@"《服务协议》") forState:UIControlStateNormal];
        [_termsBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_termsBtn titleLabel] setFont:[UIFont systemFontOfSize:12.0f]];
        [_termsBtn addTarget:self action:@selector(termsPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _termsBtn;
}

- (UILabel *)legalDotLbl {
    if(!_legalDotLbl) {
        _legalDotLbl = [[UILabel alloc] init];
        _legalDotLbl.text = @"·";
        _legalDotLbl.font = [UIFont systemFontOfSize:12.0f];
        _legalDotLbl.textColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0];
        _legalDotLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _legalDotLbl;
}

- (UIButton *)privacyBtn {
    if(!_privacyBtn) {
        _privacyBtn = [[UIButton alloc] init];
        [_privacyBtn setTitle:LLang(@"《隐私政策》") forState:UIControlStateNormal];
        [_privacyBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        [[_privacyBtn titleLabel] setFont:[UIFont systemFontOfSize:12.0f]];
        [_privacyBtn addTarget:self action:@selector(privacyPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _privacyBtn;
}

#pragma mark -- 动态配置

// 形态选择: 客户端写死「有 SSO provider → 只显示 SSO」, 不依赖额外服务端开关。
// (与 web dmworklogin 的行为差异: web 在 SSO 模式下仍保留 Octo 表单作为「已有账号」
// 备选; iOS 这里按产品要求彻底隐藏 Octo 入口, 给老用户的备用登录路径走「长按欢迎标题
// 切服务器」+ 切到非 SSO 部署的入口, 或后端去掉 oidc_providers 临时回退。)
- (WKLoginViewMode)computeMode {
    NSArray<WKOidcProviderConfig*> *providers = [WKApp shared].remoteConfig.oidcProviders;
    return providers.count > 0 ? WKLoginViewModeSsoOnly : WKLoginViewModeOcto;
}

// SsoOnly 模式下, 取第一个 provider 作为主 CTA (web dmworklogin 也是单 provider 单 CTA)。
- (WKOidcProviderConfig *)pickPrimaryProvider {
    NSArray<WKOidcProviderConfig*> *providers = [WKApp shared].remoteConfig.oidcProviders;
    return providers.count > 0 ? providers.firstObject : nil;
}

- (void)refreshDynamicConfig {
    self.currentProvider = [self pickPrimaryProvider];
    WKLoginViewMode mode = [self computeMode];
    self.currentMode = mode;
    [self applyLayoutForMode:mode];
}

- (void)applyLayoutForMode:(WKLoginViewMode)mode {
    if(mode == WKLoginViewModeSsoOnly) {
        [self layoutSsoOnly];
    } else {
        [self layoutOcto];
    }

    [self layoutLegalFooter];
}

// Octo 模式: 没有 SSO provider 时走原始布局 (form + login + register). SSO 区视图整组隐藏。
// (computeMode 保证此分支下 oidcProviders 必为空, 所以不需要再 if hasSso, 也不需要 SSO 分割线 / helper。)
- (void)layoutOcto {
    self.heroLogoView.hidden = YES;

    // 欢迎标题: 还原成 "欢迎登录Octo" (SsoOnly 模式可能改成过 "欢迎回来")
    self.welcomeTitleLbl.textAlignment = NSTextAlignmentLeft;
    NSMutableAttributedString *titleStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:LLang(@"欢迎登录%@"), [WKApp shared].config.appName ?: @""] attributes:@{
        NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size:32.0f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0],
    }];
    self.welcomeTitleLbl.attributedText = titleStr;
    self.welcomeTitleLbl.frame = CGRectMake(30, 93, WKScreenWidth-60, 50);

    self.mobileBoxView.hidden = NO;
    self.passwordBoxView.hidden = NO;
    self.forgetPwdBtn.hidden = NO;
    self.loginBtn.hidden = NO;
    self.registerTipLbl.hidden = NO;
    self.registerBtn.hidden = NO;

    self.ssoBtn.hidden = YES;
    self.ssoSubtitleLbl.hidden = YES;
    self.ssoHelperLbl.hidden = YES;
}

// SsoOnly 模式: logo (居中) + 欢迎回来 (左对齐) + 双行副标题 (左对齐) + 主 SSO 按钮 + 信任标记。
// 文案 / 图标参考 Aegis 登录设计稿: 盾牌+对勾 主图标, 「身份认证由 X 提供 · 企业级安全」信任标记。
- (void)layoutSsoOnly {
    WKOidcProviderConfig *provider = self.currentProvider;
    NSString *displayName = provider.name.length > 0 ? provider.name : provider.providerId;
    NSString *appName = [WKApp shared].config.appName ?: @"Octo";

    // Octo 表单整组隐藏
    self.mobileBoxView.hidden = YES;
    self.passwordBoxView.hidden = YES;
    self.forgetPwdBtn.hidden = YES;
    self.loginBtn.hidden = YES;
    self.registerTipLbl.hidden = YES;
    self.registerBtn.hidden = YES;

    // Hero logo (不变)
    CGFloat logoSize = 80.0f;
    CGFloat logoTop = 140.0f;
    self.heroLogoView.hidden = NO;
    self.heroLogoView.frame = CGRectMake((WKScreenWidth - logoSize)/2.0f, logoTop, logoSize, logoSize);

    // 欢迎标题: 左对齐, "欢迎回来" (长按手势保留)
    CGFloat sideMargin = 30.0f;
    self.welcomeTitleLbl.textAlignment = NSTextAlignmentLeft;
    NSMutableAttributedString *titleStr = [[NSMutableAttributedString alloc] initWithString:LLang(@"欢迎回来") attributes:@{
        NSFontAttributeName: [UIFont fontWithName:@"PingFangSC-Semibold" size:32.0f],
        NSForegroundColorAttributeName: [UIColor colorWithRed:49/255.0 green:49/255.0 blue:49/255.0 alpha:1.0],
    }];
    self.welcomeTitleLbl.attributedText = titleStr;
    self.welcomeTitleLbl.frame = CGRectMake(sideMargin, self.heroLogoView.lim_bottom + 40.0f, WKScreenWidth - sideMargin*2, 44);

    // 双行副标题: "使用 X 安全登录你的 Y 账号\n新用户首次登录将自动创建账号"
    self.ssoSubtitleLbl.hidden = NO;
    self.ssoSubtitleLbl.text = [NSString stringWithFormat:LLang(@"使用 %@ 安全登录你的 %@ 账号\n新用户首次登录将自动创建账号"), displayName, appName];
    self.ssoSubtitleLbl.frame = CGRectMake(sideMargin, self.welcomeTitleLbl.lim_bottom + 12.0f, WKScreenWidth - sideMargin*2, 44);

    // 主 SSO 按钮: 实心 themeColor, 56pt 高, 大圆角, 盾牌+对勾 图标
    self.ssoBtn.hidden = NO;
    self.ssoBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.ssoBtn.layer.borderWidth = 0.0f;
    self.ssoBtn.layer.cornerRadius = 12.0f;
    [self.ssoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [[self.ssoBtn titleLabel] setFont:[UIFont fontWithName:@"PingFangSC-Semibold" size:17.0f]];
    // SF Symbol checkmark.shield.fill (iOS 13+, 工程 deployment target iOS 14)
    UIImage *shieldImg = nil;
    if(@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *conf = [UIImageSymbolConfiguration configurationWithPointSize:20.0f weight:UIImageSymbolWeightSemibold];
        shieldImg = [[UIImage systemImageNamed:@"checkmark.shield.fill" withConfiguration:conf] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    [self.ssoBtn setImage:shieldImg forState:UIControlStateNormal];
    self.ssoBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.ssoBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, 10)];
    [self.ssoBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
    [self.ssoBtn setTitle:[NSString stringWithFormat:LLang(@"使用 %@ 登录"), displayName] forState:UIControlStateNormal];
    CGFloat btnHeight = 56.0f;
    CGFloat btnTop = self.ssoSubtitleLbl.lim_bottom + 40.0f;
    CGFloat btnSide = 20.0f;
    self.ssoBtn.frame = CGRectMake(btnSide, btnTop, WKScreenWidth - btnSide*2, btnHeight);

    // 信任标记: 盾牌(描边) + "身份认证由 X 提供 · 企业级安全", 居中。
    // NSTextAttachment 把图标内嵌到 attributed string 里, 保证 UILabel 整体居中对齐。
    self.ssoHelperLbl.hidden = NO;
    UIColor *helperColor = [UIColor colorWithRed:140.0f/255.0f green:140.0f/255.0f blue:148.0f/255.0f alpha:1.0];
    UIFont *helperFont = [UIFont systemFontOfSize:12.0f];
    NSMutableAttributedString *helperStr = [[NSMutableAttributedString alloc] init];
    if(@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *shieldConf = [UIImageSymbolConfiguration configurationWithPointSize:11.0f weight:UIImageSymbolWeightRegular];
        UIImage *helperShield = [[UIImage systemImageNamed:@"shield" withConfiguration:shieldConf] imageWithTintColor:helperColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = helperShield;
        // 微调让图标基线和文字对齐 (盾牌图形偏上, -2 让它视觉居中)
        attachment.bounds = CGRectMake(0, -2.0f, helperShield.size.width, helperShield.size.height);
        [helperStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        [helperStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  "]];
    }
    NSString *helperText = [NSString stringWithFormat:LLang(@"身份认证由 %@ 提供 · 企业级安全"), displayName];
    [helperStr appendAttributedString:[[NSAttributedString alloc] initWithString:helperText attributes:@{
        NSFontAttributeName: helperFont,
        NSForegroundColorAttributeName: helperColor,
    }]];
    self.ssoHelperLbl.attributedText = helperStr;
    self.ssoHelperLbl.frame = CGRectMake(20.0f, self.ssoBtn.lim_bottom + 16.0f, WKScreenWidth - 40.0f, 18.0f);
}

- (void)layoutLegalFooter {
    // 安全区底 + 24pt 留白
    CGFloat bottomSafe = 0.0f;
    if(@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        bottomSafe = window.safeAreaInsets.bottom;
    }
    CGFloat footerHeight = 16.0f;
    CGFloat footerTop = WKScreenHeight - bottomSafe - 24.0f - footerHeight;

    [self.termsBtn sizeToFit];
    [self.privacyBtn sizeToFit];
    CGFloat dotW = 8.0f;
    CGFloat gap = 6.0f;
    CGFloat totalW = self.termsBtn.lim_width + gap + dotW + gap + self.privacyBtn.lim_width;
    CGFloat startX = (WKScreenWidth - totalW)/2.0f;

    self.termsBtn.frame = CGRectMake(startX, footerTop, self.termsBtn.lim_width, footerHeight);
    self.legalDotLbl.frame = CGRectMake(self.termsBtn.lim_right + gap, footerTop, dotW, footerHeight);
    self.privacyBtn.frame = CGRectMake(self.legalDotLbl.lim_right + gap, footerTop, self.privacyBtn.lim_width, footerHeight);
}

#pragma mark -- 协议入口跳转
- (void)termsPressed {
    [self openWebURL:[WKApp shared].config.octoTermsURL];
}

- (void)privacyPressed {
    [self openWebURL:[WKApp shared].config.octoPrivacyURL];
}

- (void)openWebURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if(!url) return;
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = url;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

#pragma mark -- SSO

-(void) ssoBtnPressed {
    if(self.ssoInFlight) return;
    WKOidcProviderConfig *provider = self.currentProvider;
    if(!provider) return;
    self.ssoInFlight = YES;
    __weak typeof(self) weakself = self;
    [WKAPIClient.sharedClient GET:@"user/thirdlogin/authcode" parameters:nil].then(^(NSDictionary *resultDict){
        weakself.ssoInFlight = NO;
        NSString *authcode = resultDict[@"authcode"];
        if(!authcode || authcode.length == 0) {
            [weakself showHUDWithHide:LLang(@"获取授权失败，请重试")];
            return;
        }
        NSURL *authorizeURL = [weakself buildOidcAuthorizeURL:provider authcode:authcode];
        if(!authorizeURL) {
            [weakself showHUDWithHide:LLang(@"授权地址无效")];
            return;
        }
        WKAuthWebViewVC *vc = [[WKAuthWebViewVC alloc] init];
        vc.authcode = authcode;
        vc.url = authorizeURL;
        [WKNavigationManager.shared pushViewController:vc animated:YES];
    }).catch(^(NSError *error){
        weakself.ssoInFlight = NO;
        [weakself showHUDWithHide:error.domain];
    });
}

// Build OIDC authorize URL for the webview to load.
// Delegates to WKOidcProviderConfig shared helper (R1: centralize URL
// construction + safe query encoding + redacted logging; see WKOidcProviderConfig.m
// for full implementation rationale).
//
// flag=3 reason: iOS SDK CONNECT 包带 deviceFlag=3, 后端按 (uid, device_flag, token)
// 查设备 token; 若 OIDC 回跳 flag 不是 3, IM CONNECT 查不到对应 device-token row 会
// 被静默关 socket。WKLoginVM / WKRegisterVM 所有 native 登录接口也都发 flag=3。
- (NSURL *)buildOidcAuthorizeURL:(WKOidcProviderConfig *)provider authcode:(NSString *)authcode {
    // R1 fix (Jerry-Xin Critical): delegate to WKOidcProviderConfig shared helper,
    // which uses NSURLComponents + NSURLQueryItem for RFC 3986-safe query encoding and
    // avoids logging full authorize URL (authcode / device_* redacted).
    return [WKOidcProviderConfig buildAuthorizeURLForProvider:provider
                                                     authcode:authcode
                                                      apiBase:WKAPIClient.sharedClient.config.baseUrl ?: @""
                                                     deviceId:[UIDevice getUUID]
                                                   deviceName:[UIDevice getDeviceName]
                                                  deviceModel:[UIDevice getDeviceModel]];
}


#pragma mark -- 服务器设置

- (void)serverSettingLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *vc = [WKNavigationManager shared].topViewController;
        if (vc) {
            [WKServerSettingHelper showServerSettingAlertInViewController:vc];
        }
    }
}

#pragma mark -- 公用方法

- (void)setCountry:(NSString *)country {
    _country = [country copy];
    [self updateCountryBtnTitle];
}

- (void)setMobile:(NSString *)mobile {
    _mobile = [mobile copy];
    self.mobileTextField.text = mobile;
}

#pragma mark -- 事件
// 跳到注册页面
-(void) toRegisterPressed{
    [[WKNavigationManager shared] pushViewController:[WKRegisterVC new] animated:YES];
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

// 登录按钮点击
-(void) loginBtnPressed{
    if(self.onLogin) {
        NSString *inputText = self.mobileTextField.text;
        // 判断是否为纯数字（手机号）
        BOOL isPhoneNumber = [self isPhoneNumber:inputText];
        NSString *country = isPhoneNumber ? [NSString stringWithFormat:@"00%@",_country] : @"";
        self.onLogin(inputText, self.passwordTextField.text, country);
    }
}

// 判断是否为纯数字
- (BOOL)isPhoneNumber:(NSString *)text {
    if (!text || text.length == 0) {
        return NO;
    }
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [text rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

// 监听输入框变化
- (void)mobileTextFieldDidChange:(UITextField *)textField {
    NSString *text = textField.text;
    BOOL isPhoneNumber = [self isPhoneNumber:text];

    // 根据输入类型显示/隐藏区号选择器
    self.countryBtn.hidden = !isPhoneNumber;
    self.downArrowView.hidden = !isPhoneNumber;
    self.countrySpliteLineView.hidden = !isPhoneNumber;

    // 调整输入框位置
    CGFloat left = isPhoneNumber ? (self.countrySpliteLineView.lim_right + 20.0f) : 20.0f;
    [self.mobileTextField mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(left);
        make.right.mas_equalTo(self.mobileBoxView).offset(-20.0f);
        make.height.mas_equalTo(40.0f);
        make.centerY.mas_equalTo(self.mobileBoxView);
    }];
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
        [weakself showHUDWithHide:error.domain];
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
        [weakself showHUDWithHide:error.domain];
    });
}


#pragma mark -- 委托
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{

    if(textField == self.mobileTextField) {
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        // 判断新文本是否为纯数字
        BOOL isPhoneNumber = [self isPhoneNumber:newText];

        // 如果是纯数字且是中国区号，限制11位
        if(isPhoneNumber && [_country isEqualToString:@"86"]) {
            NSInteger strLength = textField.text.length - range.length + string.length;
            return (strLength <= 11); // 大陆电话号码为11位
        }
    }
    return true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(_passwordTextField == textField) {
        [self loginBtnPressed];
    }
    return YES;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    self.mobileBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.passwordBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.passwordBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    self.countrySpliteLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    self.mobileBottomLineView.layer.backgroundColor = [WKApp shared].config.lineColor.CGColor;
    // SsoOnly 模式下重新 apply themeColor 实心背景; Octo 模式 ssoBtn 隐藏, 不用管。
    if(_ssoBtn && self.currentMode == WKLoginViewModeSsoOnly) {
        _ssoBtn.backgroundColor = [WKApp shared].config.themeColor;
    }
}


-(UIImage*) image:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}

@end
