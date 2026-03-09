//
//  WKWebClientInfoVC.m
//  WuKongBase
//
//  Created by tt on 2021/8/24.
//

#import "WKWebClientInfoVC.h"
#import <Lottie/Lottie.h>
#import "WKScanVC.h"
@interface WKWebClientInfoVC ()

@property(nonatomic,strong)  LOTAnimationView *animationView;

@property(nonatomic,copy) UILabel *titleLbl;

@property(nonatomic,strong) UIView *item1BoxView;
@property(nonatomic,strong) UIImageView *webIconImgView;
@property(nonatomic,strong) UILabel *webLbl;
@property(nonatomic,strong) UILabel *addrLbl;
@property(nonatomic,strong) UIButton *copyBtn;


@property(nonatomic,strong) UILabel *tipLbl;

@property(nonatomic,strong) UIView *item2BoxView;
@property(nonatomic,strong) UIImageView *qrcodeImgView;
@property(nonatomic,strong) UILabel *scanLoginLbl;
@property(nonatomic,strong) UIImageView *arrowImgView;

@end

@implementation WKWebClientInfoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = LLang(@"网页端");
    
   
    [self.view addSubview:self.animationView];
    [self.view addSubview:self.titleLbl];
    
    [self.view addSubview:self.item1BoxView];
    [self.item1BoxView addSubview:self.webIconImgView];
    [self.item1BoxView addSubview:self.webLbl];
    [self.item1BoxView addSubview:self.copyBtn];
    [self.item1BoxView addSubview:self.addrLbl];
    
    [self.view addSubview:self.tipLbl];
    
    [self.view addSubview:self.item2BoxView];
    [self.item2BoxView addSubview:self.qrcodeImgView];
    [self.item2BoxView addSubview:self.scanLoginLbl];
    [self.item2BoxView addSubview:self.arrowImgView];
    
    [self layout];
    
//    self.animationView.loopAnimation = true;
    [self.animationView play];
    
}

-(void) layout {
    self.animationView.lim_top = self.navigationBar.lim_bottom + 10.0f;
    self.animationView.lim_centerX_parent = self.view;
    self.titleLbl.lim_top = self.animationView.lim_bottom;
    self.titleLbl.lim_centerX_parent = self.view;
    
    self.item1BoxView.lim_top = self.titleLbl.lim_top + 40.0f;
    self.tipLbl.lim_top = self.item1BoxView.lim_bottom + 5.0f;
    self.tipLbl.lim_centerX_parent = self.view;
    
    self.item2BoxView.lim_top = self.tipLbl.lim_bottom + 20.0f;
    
    [self layoutItem1];
    [self layoutItem2];
}

-(void) layoutItem1 {
    self.webIconImgView.lim_left = 15.0f;
    self.webIconImgView.lim_centerY_parent = self.item1BoxView;
    
    self.webLbl.lim_left = self.webIconImgView.lim_right + 15.0f;
    self.webLbl.lim_centerY_parent  = self.item1BoxView;
    
    self.copyBtn.lim_left = self.webLbl.lim_right + 2.0f;
    self.copyBtn.lim_top = self.webLbl.lim_top - 2.0f;
    
    self.addrLbl.lim_left = self.item1BoxView.lim_width - self.addrLbl.lim_width - 10.0f;
    self.addrLbl.lim_centerY_parent = self.item1BoxView;
}

-(void) layoutItem2 {
    self.qrcodeImgView.lim_left = 15.0f;
    self.qrcodeImgView.lim_centerY_parent = self.item2BoxView;
    
    self.scanLoginLbl.lim_left = self.qrcodeImgView.lim_right + 15.0f;
    self.scanLoginLbl.lim_centerY_parent = self.item2BoxView;
    
    self.arrowImgView.lim_centerY_parent = self.item2BoxView;
    self.arrowImgView.lim_left = self.item2BoxView.lim_width - self.arrowImgView.lim_width - 10.0f;
}

- (LOTAnimationView *)animationView {
    if(!_animationView) {
        _animationView = [LOTAnimationView animationNamed:@"Other/qrcode_web" inBundle:[WKApp.shared resourceBundle:@"WuKongBase"]];
        _animationView.lim_width = _animationView.lim_width * 1.0f;
        _animationView.lim_height =  _animationView.lim_height * 1.0f;
    }
    return _animationView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.text = [NSString stringWithFormat:LLang(@"%@网页端"),[WKApp shared].config.appName];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _titleLbl.textColor = [WKApp shared].config.tipColor;
        [_titleLbl sizeToFit];
    }
    return _titleLbl;
}

- (UIImageView *)webIconImgView {
    if(!_webIconImgView) {
        _webIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img = [self imageName:@"Me/Index/WebIcon"];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _webIconImgView.image = img;
        [_webIconImgView setTintColor:[WKApp shared].config.themeColor];
    }
    return _webIconImgView;
}

- (UILabel *)webLbl {
    if(!_webLbl) {
        _webLbl = [[UILabel alloc] init];
        _webLbl.text = LLang(@"web端网址");
        _webLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        [_webLbl sizeToFit];
    }
    return _webLbl;
}

- (UIButton *)copyBtn {
    if(!_copyBtn) {
        _copyBtn = [[UIButton alloc] init];
        [_copyBtn setImage:[self imageName:@"Me/Index/Copy"] forState:UIControlStateNormal];
        [_copyBtn sizeToFit];
        
        [_copyBtn addTarget:self action:@selector(copyPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _copyBtn;
}

-(void) copyPressed {
    UIPasteboard *pab = [UIPasteboard generalPasteboard];
    pab.string = self.addrLbl.text;
    
    [self.view showHUDWithHide:LLang(@"复制成功")];
}

- (UILabel *)addrLbl {
    if(!_addrLbl) {
        _addrLbl = [[UILabel alloc] init];
        _addrLbl.lim_width = 200.0f;
        _addrLbl.numberOfLines = 0;
        _addrLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _addrLbl.text = [WKApp shared].remoteConfig.webURL?:@"";
        _addrLbl.textColor = [WKApp shared].config.tipColor;
        _addrLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        [_addrLbl sizeToFit];
    }
    return _addrLbl;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.text = [NSString stringWithFormat:LLang(@"请使用浏览器访问%@,然后扫描二维码登录。为了您更好的体验，建议使用谷歌，火狐浏览器。"),[WKApp shared].config.appName];
        _tipLbl.lim_width = WKScreenWidth - 20.0f;
        _tipLbl.textColor = [WKApp shared].config.tipColor;
        _tipLbl.numberOfLines = 0;
        _tipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _tipLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        [_tipLbl sizeToFit];
    }
    return _tipLbl;
}

- (UIImageView *)qrcodeImgView {
    if(!_qrcodeImgView) {
        _qrcodeImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img = [self imageName:@"Me/Index/ScanCode"];
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _qrcodeImgView.image = img;
        [_qrcodeImgView setTintColor:[WKApp shared].config.themeColor];
        
    }
    return _qrcodeImgView;
}

- (UILabel *)scanLoginLbl {
    if(!_scanLoginLbl) {
        _scanLoginLbl = [[UILabel alloc] init];
        _scanLoginLbl.text = LLang(@"二维码扫描登录");
        _scanLoginLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        [_scanLoginLbl sizeToFit];
    }
    return _scanLoginLbl;
}

- (UIImageView *)arrowImgView {
    if(!_arrowImgView) {
        _arrowImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 9.0f, 15.0f)];
        _arrowImgView.image = [self imageName:@"Common/Index/ArrowRight"];
    }
    return _arrowImgView;
}

- (UIView *)item1BoxView {
    if(!_item1BoxView) {
        _item1BoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, self.addrLbl.lim_height+8.0f)];
    }
    return _item1BoxView;
}

- (UIView *)item2BoxView {
    if(!_item2BoxView) {
        _item2BoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 50.0f)];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(item2Press)];
        [_item2BoxView addGestureRecognizer:tap];
    }
    return _item2BoxView;
}

-(void) item2Press {
    WKScanVC *scanVC = [WKScanVC new];
    [[WKNavigationManager shared] pushViewController:scanVC animated:YES];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
