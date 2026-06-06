//
//  WKAnimatedAvatarPreviewVC.m
//  WuKongBase
//

#import "WKAnimatedAvatarPreviewVC.h"
#import <SDWebImage/SDAnimatedImageView.h>
#import <SDWebImage/SDAnimatedImage.h>
#import "WuKongBase.h"
#import "WKImageView.h"
#import "WKApp.h"

@interface WKAnimatedAvatarPreviewVC ()

@property(nonatomic, strong) NSData *gifData;
@property(nonatomic, copy)   void (^onConfirm)(NSData *gifData);
@property(nonatomic, copy)   void (^onRetake)(void);

// 用 WKImageView (SDAnimatedImageView 子类，已带 playbackRate 4× 补偿)
// 而非 SDAnimatedImageView，让预览速度与最终上传后头像位的播放速度一致。
@property(nonatomic, strong) WKImageView *previewView;
@property(nonatomic, strong) UILabel *sizeLabel;
@property(nonatomic, strong) UIButton *confirmBtn;
@property(nonatomic, strong) UIButton *retakeBtn;

@end

@implementation WKAnimatedAvatarPreviewVC

- (instancetype)initWithGIFData:(NSData *)gifData
                      onConfirm:(void (^)(NSData *))onConfirm
                       onRetake:(void (^)(void))onRetake {
    self = [super init];
    if (self) {
        _gifData = gifData;
        _onConfirm = [onConfirm copy];
        _onRetake = [onRetake copy];
    }
    return self;
}

- (NSString *)langTitle {
    return LLang(@"预览");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationBar.titleLabel.textColor = [UIColor whiteColor];

    [self setupPreview];
    [self setupButtons];
}

- (void)setupPreview {
    CGFloat side = MIN(self.view.bounds.size.width - 80, 280);
    CGFloat top = [self getNavBottom] + 40;

    self.previewView = [[WKImageView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
    self.previewView.center = CGPointMake(self.view.bounds.size.width * 0.5, top + side * 0.5);
    self.previewView.layer.cornerRadius = side * 0.5;
    self.previewView.layer.masksToBounds = YES;
    self.previewView.contentMode = UIViewContentModeScaleAspectFill;
    self.previewView.image = [SDAnimatedImage imageWithData:self.gifData];
    [self.view addSubview:self.previewView];

    CGFloat mb = self.gifData.length / 1024.0 / 1024.0;
    self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.sizeLabel.text = [NSString stringWithFormat:LLang(@"动图头像 · 约 %.1f MB"), mb];
    self.sizeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    self.sizeLabel.font = [UIFont systemFontOfSize:13.0];
    self.sizeLabel.textAlignment = NSTextAlignmentCenter;
    [self.sizeLabel sizeToFit];
    self.sizeLabel.center = CGPointMake(self.view.bounds.size.width * 0.5,
                                        CGRectGetMaxY(self.previewView.frame) + 20);
    [self.view addSubview:self.sizeLabel];
}

- (void)setupButtons {
    CGFloat bottomPad = self.view.safeAreaInsets.bottom + 20;
    if (@available(iOS 11.0, *)) {
        // ok
    } else {
        bottomPad = 30;
    }

    CGFloat btnH = 48;
    CGFloat btnW = (self.view.bounds.size.width - 60) * 0.5;
    CGFloat bottomY = self.view.bounds.size.height - bottomPad - btnH;

    self.retakeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.retakeBtn.frame = CGRectMake(20, bottomY, btnW, btnH);
    [self.retakeBtn setTitle:LLang(@"重新选择") forState:UIControlStateNormal];
    [self.retakeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.retakeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    self.retakeBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.retakeBtn.layer.cornerRadius = btnH * 0.5;
    [self.retakeBtn addTarget:self action:@selector(retakePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.retakeBtn];

    self.confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.confirmBtn.frame = CGRectMake(20 + btnW + 20, bottomY, btnW, btnH);
    [self.confirmBtn setTitle:LLang(@"确认上传") forState:UIControlStateNormal];
    [self.confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.confirmBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.confirmBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.confirmBtn.layer.cornerRadius = btnH * 0.5;
    [self.confirmBtn addTarget:self action:@selector(confirmPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.confirmBtn];
}

- (void)retakePressed {
    [self.navigationController popViewControllerAnimated:YES];
    if (self.onRetake) self.onRetake();
}

- (void)confirmPressed {
    if (self.onConfirm) self.onConfirm(self.gifData);
    [self.navigationController popViewControllerAnimated:YES];
}

@end
