//
//  WKScanVC.m
//  WuKongBase
//
//  Created by tt on 2020/4/3.
//

#import "WKScanVC.h"
#import "WKResource.h"
#import "WKAlertUtil.h"
#import "WKScanHandler.h"
#import "LBXPermission.h"
#import "WKMeQRCodeVC.h"
#import "WKScanBottom.h"
@interface WKScanVC ()

@property(nonatomic,strong) NSArray<WKScanHandler*> *handlers;

@property(nonatomic,strong) WKNavigationBar *navigationBar;

#pragma mark - 底部几个功能：开启闪光灯、相册、我的二维码
//底部显示的功能项
@property (nonatomic, strong) WKScanBottom *bottomView;


@end

@implementation WKScanVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.style = [self getScanViewStyle];
    //开启只识别框内
    self.isOpenInterestRect = YES;
    
    // 获取所有处理扫一扫的处理者
   self.handlers =  [[WKApp shared] invokes:WKPOINT_CATEGORY_SCAN_HANDLER param:nil];
    
    //设置扫码后需要扫码图像
    self.isNeedScanImage = YES;
    
    
//    __weak typeof(self) weakSelf = self;
    [LBXPermission authorizeWithType:LBXPermissionType_Camera completion:^(BOOL granted, BOOL firstTime) {
        if(!granted) {
            [LBXPermissionSetting showAlertToDislayPrivacySettingWithTitle:LLang(@"提示") msg:LLang(@"没有相机权限，是否前往设置") cancel:LLang(@"取消") setting:LLang(@"设置") completion:^{
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
            }];
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self drawNavigationBar];
    [self bottomView];
}

-(void) drawNavigationBar {
    if(_navigationBar) {
        return;
    }
    self.navigationBar.title = LLang(@"扫一扫");
    self.navigationBar.style = WKNavigationBarStyleWhite;
    self.navigationBar.titleLabel.textColor = [UIColor whiteColor];
    self.navigationBar.showBackButton = YES;
    [self.view addSubview:self.navigationBar];
}


- (WKNavigationBar *)navigationBar {
    if(!_navigationBar) {
        _navigationBar = [[WKNavigationBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f,WKScreenWidth,[WKApp shared].config.navHeight)];
        [_navigationBar setBackgroundColor:[UIColor clearColor]];
        _navigationBar.onBack = ^{
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        };
    }
    return _navigationBar;
}

- (WKScanBottom *)bottomView {
    if(!_bottomView) {
        CGFloat safeBottom = 0.0f;
        if (@available(iOS 11.0, *)) {
            safeBottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
        }
        _bottomView = [[WKScanBottom alloc] init];
        _bottomView.lim_top = WKScreenHeight - 200 - safeBottom;
        _bottomView.lim_centerX_parent = self.view;
        __weak typeof(self) weakSelf = self;
        _bottomView.onAlbum = ^{
            [weakSelf openPhoto];
        };
        _bottomView.onMyQRCode = ^{
            [weakSelf myQRCode];
        };
        _bottomView.onOpenLight = ^(BOOL on) {
            [weakSelf openOrCloseFlash];
        };
        [self.view addSubview:_bottomView];
    }
    return _bottomView;
}
//
//- (void)drawBottomItems
//{
//    if (_bottomItemsView) {
//
//        return;
//    }
//    CGFloat safeBottom = 0.0f;
//    if (@available(iOS 11.0, *)) {
//         safeBottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
//    }
//    self.bottomItemsView = [[UIView alloc]initWithFrame:CGRectMake(0, WKScreenHeight-100 - safeBottom,
//    CGRectGetWidth(self.view.frame), 100)];
//    _bottomItemsView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
//
//    [self.view addSubview:_bottomItemsView];
//
//    CGSize size = CGSizeMake(65, 87);
//    self.btnFlash = [[UIButton alloc]init];
//    _btnFlash.bounds = CGRectMake(0, 0, size.width, size.height);
//    _btnFlash.center = CGPointMake(CGRectGetWidth(_bottomItemsView.frame)/2, CGRectGetHeight(_bottomItemsView.frame)/2);
//     [_btnFlash setImage:[self imageName:@"qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
//    [_btnFlash addTarget:self action:@selector(openOrCloseFlash) forControlEvents:UIControlEventTouchUpInside];
//
//    self.btnPhoto = [[UIButton alloc]init];
//    _btnPhoto.bounds = _btnFlash.bounds;
//    _btnPhoto.center = CGPointMake(CGRectGetWidth(_bottomItemsView.frame)/4, CGRectGetHeight(_bottomItemsView.frame)/2);
//    [_btnPhoto setImage:[self imageName:@"qrcode_scan_btn_photo_nor"] forState:UIControlStateNormal];
//    [_btnPhoto setImage:[self imageName:@"qrcode_scan_btn_photo_down"] forState:UIControlStateHighlighted];
//    [_btnPhoto addTarget:self action:@selector(openPhoto) forControlEvents:UIControlEventTouchUpInside];
//
//    self.btnMyQR = [[UIButton alloc]init];
//    _btnMyQR.bounds = _btnFlash.bounds;
//    _btnMyQR.center = CGPointMake(CGRectGetWidth(_bottomItemsView.frame) * 3/4, CGRectGetHeight(_bottomItemsView.frame)/2);
//    [_btnMyQR setImage:[self imageName:@"qrcode_scan_btn_myqrcode_nor"] forState:UIControlStateNormal];
//    [_btnMyQR setImage:[self imageName:@"qrcode_scan_btn_myqrcode_down"] forState:UIControlStateHighlighted];
//    [_btnMyQR addTarget:self action:@selector(myQRCode) forControlEvents:UIControlEventTouchUpInside];
//
//    [_bottomItemsView addSubview:_btnFlash];
//    [_bottomItemsView addSubview:_btnPhoto];
//    [_bottomItemsView addSubview:_btnMyQR];
//
//}

-(LBXScanViewStyle*) getScanViewStyle {
     //设置扫码区域参数
       LBXScanViewStyle *style = [[LBXScanViewStyle alloc]init];
       
       style.centerUpOffset = 44;
       style.photoframeAngleStyle = LBXScanViewPhotoframeAngleStyle_Inner;
       style.photoframeLineW = 2;
       style.photoframeAngleW = 18;
       style.photoframeAngleH = 18;
       style.isNeedShowRetangle = YES;
       style.anmiationStyle = LBXScanViewAnimationStyle_LineMove;
       style.colorAngle = [UIColor colorWithRed:0./255 green:200./255. blue:20./255. alpha:1.0];
       
       //qq里面的线条图片
       NSBundle *bundle = [NSBundle bundleForClass:LBXScanViewController.class];
       NSURL *url = [bundle URLForResource:@"CodeScan" withExtension:@"bundle"];
      UIImage *imgLine = [self at_imageNamed:@"qrcode_Scan_weixin_Line" inBundle:[NSBundle bundleWithURL:url]];
      // UIImage *imgLine = [UIImage imageNamed:@"CodeScan.bundle/qrcode_Scan_weixin_Line"];
       style.animationImage = imgLine;
       
       style.notRecoginitonArea = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    return style;
}

- (void)scanResultWithArray:(NSArray<LBXScanResult*>*)array {
    if (array.count < 1)
    {
         __weak __typeof(self) weakSelf = self;
        [WKAlertUtil alert:LLang(@"扫描失败！") buttonsStatement:@[LLang(@"知道了")] chooseBlock:^(NSInteger buttonIdx) {
            [weakSelf reStartDevice];
        }];
        return;
    }
    LBXScanResult *scanResult = array[0];
    
    __weak typeof(self) weakSelf = self;
    [WKScanVC handleScanResult:scanResult handlers:self.handlers reStartDevice:^{
        [weakSelf reStartDevice];
    }];
    
}

+(BOOL) isQRCodeURL:(NSString*)scanResult {
    if([scanResult hasPrefix:@"http"]) {
        NSURL *scanResultURL = [NSURL URLWithString:scanResult];
        NSURL *scanPrefixURL = [NSURL URLWithString:[WKApp shared].config.scanURLPrefix];
        
        if([scanResultURL.host isEqualToString:scanPrefixURL.host] && [scanResultURL.path containsString:scanPrefixURL.path]) {
            return true;
        }
    }
    return false;
}

+(void) handleScanResult:(LBXScanResult*)result handlers:(NSArray<WKScanHandler*>*)handlers reStartDevice:(void(^)(void))reStartDevice{
    NSString *strResult = result.strScanned;
    UIView *topView = [WKNavigationManager shared].topViewController.view;
   if([self isQRCodeURL:strResult]) {
       if(handlers && handlers.count>0) {
           [[WKAPIClient sharedClient] GET:strResult parameters:nil model:WKScanResult.class].then(^(WKScanResult*result){
               for (WKScanHandler *handler in handlers) {
                  BOOL can =  [handler handle:result reScan:^{
                      if(reStartDevice) {
                          reStartDevice();
                      }
                   }];
                   if(can) {
                       break;
                   }
               }
           }).catch(^(NSError *error){
               WKLogError(@"扫码请求失败！-> %@",error);
               if(error) {
                   [topView showMsg:error.domain];
               }
               if(reStartDevice) {
                   reStartDevice();
               }
           });
           return;
       }
   } else if([strResult hasPrefix:@"http"]) {
       WKWebViewVC *vc =  [[WKWebViewVC alloc] init];
       vc.url = [NSURL URLWithString:strResult];
       [[WKNavigationManager shared] pushViewController:vc animated:YES];
   }else{
       [WKAlertUtil alert:strResult buttonsStatement:@[LLang(@"知道了")] chooseBlock:^(NSInteger buttonIdx) {
           if(reStartDevice) {
               reStartDevice();
           }
       }];
   }
}

+(void) handleScanResult:(LBXScanResult*)result handlers:(NSArray<WKScanHandler*>*)handlers {
    [self handleScanResult:result handlers:handlers reStartDevice:nil];
}


-(UIImage*) imageName:(NSString*)name {
    NSBundle *bundle = [NSBundle bundleForClass:LBXScanViewController.class];
    NSURL *url = [bundle URLForResource:@"CodeScan" withExtension:@"bundle"];
    return [self at_imageNamed:name inBundle:[NSBundle bundleWithURL:url]];
}

- (UIImage *)at_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle  {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
    return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
#elif __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
    return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
#else
    if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
        return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    } else {
        return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
    }
#endif
}

#pragma mark -底部功能项
//打开相册
- (void)openPhoto
{
    __weak __typeof(self) weakSelf = self;
    [LBXPermission authorizeWithType:LBXPermissionType_Photos completion:^(BOOL granted, BOOL firstTime) {
        if (granted) {
            [weakSelf openLocalPhoto:NO];
        }
        else if (!firstTime )
        {
            [LBXPermissionSetting showAlertToDislayPrivacySettingWithTitle:LLang(@"提示") msg:LLang(@"没有相册权限，是否前往设置") cancel:LLang(@"取消") setting:LLang(@"设置")];
        }
    }];
}


//开关闪光灯
//- (void)openOrCloseFlash
//{
//    [super openOrCloseFlash];
//
//    if (self.isOpenFlash)
//    {
//        [_btnFlash setImage:[self imageName:@"qrcode_scan_btn_flash_down"] forState:UIControlStateNormal];
//    }
//    else
//        [_btnFlash setImage:[self imageName:@"qrcode_scan_btn_flash_nor"] forState:UIControlStateNormal];
//}

-(void) myQRCode {
    WKMeQRCodeVC *vc = [WKMeQRCodeVC new];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}


@end
