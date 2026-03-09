//
//  WKLoginPhoneCheckStartVC.m
//  WuKongLogin
//
//  Created by tt on 2020/10/26.
//

#import "WKLoginPhoneCheckStartVC.h"
#import "WKLoginPhoneCheckVC.h"
@interface WKLoginPhoneCheckStartVC ()

@property(nonatomic,strong) UIImageView *iconImgView;

@property(nonatomic,strong) UILabel *tipLbl;

@property(nonatomic,strong) UILabel *phoneTipLbl;

@property(nonatomic,strong) UIButton *okBtn;

@end

@implementation WKLoginPhoneCheckStartVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.iconImgView];
    [self.view addSubview:self.tipLbl];
    [self.view addSubview:self.phoneTipLbl];
    [self.view addSubview:self.okBtn];
}

- (NSString *)langTitle {
    return LLang(@"登录验证");
}


- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        CGFloat width = 122.0f;
        CGFloat height = 109.0f;
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(WKScreenWidth/2.0f - width/2.0f, self.navigationBar.lim_bottom + 120.0f, width, height)];
        [_iconImgView setImage:[self imageName:@"LoginCheck"]];
    }
    return _iconImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] initWithFrame:CGRectMake(15.0f,self.iconImgView.lim_bottom + 20.0f , WKScreenWidth - 30.0f, 0.0f)];
        _tipLbl.text =[NSString stringWithFormat: LLang(@"你正在一台新设备登录%@，需要进行安全验证，通过后下次无需验证。"),[WKApp shared].config.appName];
        _tipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _tipLbl.numberOfLines = 0;
        _tipLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _tipLbl.textColor = [WKApp shared].config.tipColor;
        [_tipLbl sizeToFit];
    }
    return _tipLbl;
}

- (UILabel *)phoneTipLbl {
    if(!_phoneTipLbl) {
        _phoneTipLbl = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, self.tipLbl.lim_bottom + 20.0f, WKScreenWidth - 30.0f, 0.0f)];
        _phoneTipLbl.text = [NSString stringWithFormat:LLang(@"手机号码：%@"),self.phone];
        _phoneTipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _phoneTipLbl.numberOfLines = 0;
        _phoneTipLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _phoneTipLbl.textColor = [WKApp shared].config.tipColor;
        [_phoneTipLbl sizeToFit];
    }
    return _phoneTipLbl;
}

- (UIButton *)okBtn {
    if(!_okBtn) {
        _okBtn = [[UIButton alloc] initWithFrame:CGRectMake(15.0f, self.phoneTipLbl.lim_bottom + 20.0f, WKScreenWidth - 30.0f, 40.0f)];
        [_okBtn setTitle:LLang(@"开始验证") forState:UIControlStateNormal];
        _okBtn.backgroundColor = [WKApp shared].config.themeColor;
        _okBtn.layer.masksToBounds = YES;
        _okBtn.layer.cornerRadius = 4.0f;
        _okBtn.lim_left = WKScreenWidth/2.0f - _okBtn.lim_width/2.0f;
        [_okBtn addTarget:self action:@selector(okPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [WKApp.shared.config setThemeStyleButton:_okBtn];
    }
    return _okBtn;
}

-(void) okPressed {
    WKLoginPhoneCheckVC *vc = [WKLoginPhoneCheckVC new];
    vc.phone = self.phone;
    vc.uid = self.uid;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}
@end
