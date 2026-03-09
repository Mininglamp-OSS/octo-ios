//
//  WKScanBottom.m
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import "WKScanBottom.h"
#import "WuKongBase.h"


@interface WKScanBottom ()

@property(nonatomic,strong) WKIconButton *albumBtn; // 相册
@property(nonatomic,strong) WKIconSwitchButton *openLightBtn; // 开灯
@property(nonatomic,strong) WKIconButton *myQRCodeBtn; // 我的二维码
@end

@implementation WKScanBottom

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 70.0f)];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = self.lim_height/2.0f;
        
        [self addSubview:self.albumBtn];
        [self addSubview:self.openLightBtn];
        [self addSubview:self.myQRCodeBtn];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    

    CGFloat leftSpace = 30.0f;
    
    CGFloat space = (self.lim_width - (leftSpace + self.albumBtn.lim_width + self.openLightBtn.lim_width + self.myQRCodeBtn.lim_width + leftSpace))/2.0f;
    
    self.albumBtn.lim_centerY_parent = self;
    self.albumBtn.lim_left = leftSpace;
    
    self.openLightBtn.lim_centerY_parent = self;
    self.openLightBtn.lim_left = self.albumBtn.lim_right + space;
    
    self.myQRCodeBtn.lim_centerY_parent = self;
    self.myQRCodeBtn.lim_left = self.openLightBtn.lim_right + space;
    
    
}

- (WKIconButton *)albumBtn {
    if(!_albumBtn) {
        _albumBtn = [[WKIconButton alloc] init];
        _albumBtn.imageView.image = LImage(@"Common/Scan/Album");
        _albumBtn.imageView.lim_size = CGSizeMake(20.0f, 20.0f);
        _albumBtn.width = 30.0f;
        _albumBtn.titleLbl.text = LLang(@"相册");
        _albumBtn.titleLbl.font = [WKApp.shared.config appFontOfSize:12.0f];
        [_albumBtn.titleLbl sizeToFit];
        
        [_albumBtn layoutSubviews];
        
        __weak typeof(self) weakSelf = self;
        _albumBtn.onClick = ^{
            if(weakSelf.onAlbum) {
                weakSelf.onAlbum();
            }
        };
        
    }
    return _albumBtn;
}

- (WKIconSwitchButton *)openLightBtn {
    if(!_openLightBtn) {
        _openLightBtn = [[WKIconSwitchButton alloc] initWithIconSize:CGSizeMake(20.0f, 20.0f)];
        _openLightBtn.width = 30.0f;
        UIImage *icon = LImage(@"Common/Scan/OpenLight");
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        _openLightBtn.offIconImgView.image = icon;
        [_openLightBtn.offIconImgView setTintColor:[UIColor whiteColor]];
        
       
        
        _openLightBtn.onIconImgView.image = icon;
        [ _openLightBtn.onIconImgView setTintColor:[UIColor redColor]];
        
        _openLightBtn.onTitleLbl.text = LLang(@"开灯");
        _openLightBtn.onTitleLbl.font = [WKApp.shared.config appFontOfSize:12.0f];
        _openLightBtn.onTitleLbl.textColor = [UIColor redColor];
        [_openLightBtn.onTitleLbl sizeToFit];
        
        _openLightBtn.offTitleLbl.text = LLang(@"开灯");
        _openLightBtn.offTitleLbl.font = [WKApp.shared.config appFontOfSize:12.0f];
        [_openLightBtn.offTitleLbl sizeToFit];
        
        [_openLightBtn layoutSubviews];
        
        __weak typeof(self) weakSelf = self;
        _openLightBtn.onSwitch = ^(BOOL on) {
            if(weakSelf.onOpenLight) {
                weakSelf.onOpenLight(on);
            }
        };

       
    }
    return _openLightBtn;
}

- (WKIconButton *)myQRCodeBtn {
    if(!_myQRCodeBtn) {
        _myQRCodeBtn = [[WKIconButton alloc] init];
        _myQRCodeBtn.imageView.image = LImage(@"Common/Scan/QRCode");
        _myQRCodeBtn.imageView.lim_size = CGSizeMake(20.0f, 20.0f);
        _myQRCodeBtn.width = 30.0f;
        
        _myQRCodeBtn.titleLbl.text = LLang(@"二维码");
        _myQRCodeBtn.titleLbl.font = [WKApp.shared.config appFontOfSize:12.0f];
        [_myQRCodeBtn.titleLbl sizeToFit];
        
        [_myQRCodeBtn layoutSubviews];
        __weak typeof(self) weakSelf = self;
        _myQRCodeBtn.onClick = ^{
            if(weakSelf.onMyQRCode) {
                weakSelf.onMyQRCode();
            }
        };

        
    }
    return _myQRCodeBtn;
}


@end

