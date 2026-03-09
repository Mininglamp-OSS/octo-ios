//
//  WKMeQRCodeVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WKMeQRCodeVC.h"
#import "WKActionSheetView2.h"
#import "LBXScanNative.h"
@interface WKMeQRCodeVC ()

@property(nonatomic,strong) UIView *qrcodeBoxView; // 整个白色容器

@property(nonatomic,strong) UIImageView *qrcodeImgView; // 二维码图片

@property(nonatomic,strong) UIView *qrcodeMaskView; // 开启进群验证后，二维码图片的覆盖层


@property(nonatomic,strong) WKUserAvatar *avatarImgView; // 群头像

@property(nonatomic,strong) UILabel *titleLbl; // 群标题

@property(nonatomic,strong) UILabel *remarkLbl; // 二维码备注


@property(nonatomic,strong) UIActivityIndicatorView *activityView;

@property(nonatomic,strong) UIButton *moreButtonItem; // 顶部右边更多按钮

@end

@implementation WKMeQRCodeVC


- (void)viewDidLoad {
    [super viewDidLoad];
    
     self.rightView = self.moreButtonItem;

    
    [self.view addSubview:self.qrcodeBoxView];
    
    [self.qrcodeBoxView addSubview:self.qrcodeImgView];
    
    [self.qrcodeBoxView addSubview:self.qrcodeMaskView];
    
    [self.qrcodeBoxView addSubview:self.avatarImgView];
    
    [self.qrcodeBoxView addSubview:self.titleLbl];
    
    [self.qrcodeBoxView addSubview:self.remarkLbl];
    
    //
    
    [self.qrcodeImgView addSubview:self.activityView];
    
    __weak typeof(self) weakSelf = self;
    [self.activityView startAnimating];
    [[WKAPIClient sharedClient] GET:@"user/qrcode" parameters:nil].then(^(NSDictionary *result){
        weakSelf.qrcodeImgView.image =  [LBXScanNative createQRWithString:result[@"data"] QRSize:weakSelf.qrcodeImgView.lim_size];
        [weakSelf.activityView stopAnimating];
    }).catch(^(NSError *error){
        [weakSelf.view showHUDWithHide:error.domain];
    });
    
   
    [self updateRemark: [NSString stringWithFormat:LLang(@"扫一扫上面的二维码图案，加我%@"),[WKApp shared].config.appName]];
}

- (NSString *)langTitle {
    return LLang(@"我的二维码");
}

-(UIButton*) moreButtonItem {
    if(!_moreButtonItem) {
        _moreButtonItem = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButtonItem addTarget:self action:@selector(moreBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        _moreButtonItem.frame = CGRectMake(0 , 0, 44, 44);
        
        UIImage *img = [[self imageName:@"Common/Index/More"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_moreButtonItem setImage:img forState:UIControlStateNormal];
        [_moreButtonItem setTintColor:WKApp.shared.config.navBarButtonColor];
    }
    return _moreButtonItem;
}

-(void) moreBtnPressed {
    WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithCancel:nil];
    [actionSheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"保存图片") onClick:^{
        [self saveImageView];
    }]];
    [actionSheetView show];
}

//截屏分享  传入想截屏的view(也可以是controller
//webview只能截当前屏幕-_-`,用其他的方法)
- (void)saveImageView {
  UIGraphicsBeginImageContextWithOptions(self.qrcodeBoxView.frame.size, NO, 0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  [self.qrcodeBoxView.layer renderInContext:ctx];
  // 这个是要分享图片的样式(自定义的)
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  //保存到本地相机
  UIImageWriteToSavedPhotosAlbum(
      newImage, self, @selector(image:didFinishSavingWithError:contextInfo:),
      nil);
}
//保存相片的回调方法
- (void)image:(UIImage *)image
    didFinishSavingWithError:(NSError *)error
                 contextInfo:(void *)contextInfo {
  if (error) {
      [self.view showMsg:LLang(@"保存图片失败！请检查是否开启权限!")];
  } else {
    [self.view showMsg:LLang(@"保存成功！")];
  }
}

// 容器
-(UIView*) qrcodeBoxView {
    if(!_qrcodeBoxView) {
        CGFloat width = WKScreenWidth - 40.0f;
        _qrcodeBoxView = [[UIView alloc] initWithFrame:CGRectMake(20.0f, 60.0f +[self visibleRect].origin.y ,width, width + 140.0f)];
        [_qrcodeBoxView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _qrcodeBoxView.layer.masksToBounds = YES;
        _qrcodeBoxView.layer.cornerRadius = 10.0f;
    }
    return _qrcodeBoxView;
}

// 二维码图片
-(UIView*) qrcodeImgView {
    if(!_qrcodeImgView) {
        _qrcodeImgView = [[UIImageView alloc] init];
        _qrcodeImgView.frame = CGRectMake(20.0f, self.titleLbl.lim_bottom + 10.0f, self.qrcodeBoxView.lim_width - 40.0f, self.qrcodeBoxView.lim_width - 40.0f);
    }
    return _qrcodeImgView;
}

- (UIView *)qrcodeMaskView {
    if(!_qrcodeMaskView) {
        _qrcodeMaskView = [[UIView alloc] init];
        _qrcodeMaskView.hidden = YES;
        _qrcodeMaskView.frame = self.qrcodeImgView.frame;
        [_qrcodeMaskView setBackgroundColor:[UIColor whiteColor]];
        _qrcodeMaskView.layer.opacity = 0.98f;
        
        UILabel *titleLbl1 = [[UILabel alloc] init];
        titleLbl1.text = LLang(@"该群已开启进群验证");
        [titleLbl1 setFont:[UIFont systemFontOfSize:20.0f]];
        [titleLbl1 setTextColor:[UIColor grayColor]];
        [titleLbl1 sizeToFit];
        [_qrcodeMaskView addSubview:titleLbl1];
        titleLbl1.lim_left = _qrcodeMaskView.lim_width/2.0f - titleLbl1.lim_width/2.0f;
        titleLbl1.lim_top = _qrcodeMaskView.lim_height/2.0f - titleLbl1.lim_height;
        
        UILabel *titleLbl2 = [[UILabel alloc] init];
        titleLbl2.text = LLang(@"只可通过邀请进群");
        [titleLbl2 setFont:[UIFont systemFontOfSize:20.0f]];
        [titleLbl2 setTextColor:[UIColor grayColor]];
        [titleLbl2 sizeToFit];
        [_qrcodeMaskView addSubview:titleLbl2];
        titleLbl2.lim_left = _qrcodeMaskView.lim_width/2.0f - titleLbl2.lim_width/2.0f;
        titleLbl2.lim_top = titleLbl1.lim_bottom + 5.0f;
    }
    return _qrcodeMaskView;
}

// 头像
-(WKUserAvatar*) avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] init];
        _avatarImgView.lim_left = self.qrcodeBoxView.lim_width/2.0f - _avatarImgView.lim_width/2.0f;
        _avatarImgView.lim_top = 15.0f;
        _avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid];
    }
    return _avatarImgView;
}

-(UILabel*) titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, self.avatarImgView.lim_bottom + 5.0f, self.qrcodeBoxView.lim_width, 18.0f)];
        _titleLbl.numberOfLines = 1.0f;
        _titleLbl.textAlignment = NSTextAlignmentCenter;
        _titleLbl.text = [WKApp shared].loginInfo.extra[@"name"];
        _titleLbl.lim_left = self.qrcodeBoxView.lim_width/2.0f - _titleLbl.lim_width/2.0f;
        [_titleLbl setFont:[[WKApp shared].config appFontOfSizeMedium:16.0f]];
        
    }
    return _titleLbl;
}

-(UILabel*) remarkLbl {
    if(!_remarkLbl) {
        _remarkLbl = [[UILabel alloc] init];
        _remarkLbl.font = [UIFont systemFontOfSize:12.0f];
        _remarkLbl.textColor = [UIColor grayColor];
    }
    return _remarkLbl;
}

-(void) updateRemark:(NSString*)remark {
    self.remarkLbl.text = remark;
    self.remarkLbl.lim_top = self.qrcodeImgView.lim_bottom + 20.0f;
    [self.remarkLbl sizeToFit];
    self.remarkLbl.lim_left = self.qrcodeBoxView.lim_width/2.0f - self.remarkLbl.lim_width/2.0f;
}

-(UIActivityIndicatorView*) activityView {
    if(!_activityView) {
        _activityView = [[UIActivityIndicatorView alloc] init];
        _activityView.lim_left = self.qrcodeImgView.lim_width/2.0f - _activityView.lim_width/2.0f;
        _activityView.lim_top = self.qrcodeImgView.lim_height/2.0f - _activityView.lim_height/2.0f;
    }
    return _activityView;
}

// iphoneX安全距离
- (CGFloat) safeBottom {
    CGFloat safeNum = 0;
    //判断版本
    if (@available(iOS 11.0, *)) {
        //通过系统方法keyWindow来获取safeAreaInsets
        UIEdgeInsets safeArea = [[UIApplication sharedApplication] keyWindow].safeAreaInsets;
        safeNum = safeArea.bottom;
    }
    return safeNum;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}



@end
