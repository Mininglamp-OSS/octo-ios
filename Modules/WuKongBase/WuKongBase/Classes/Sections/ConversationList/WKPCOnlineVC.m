//
//  WKPCOnlineVC.m
//  WuKongBase
//
//  Created by tt on 2021/9/18.
//

#import "WKPCOnlineVC.h"
#import "WKConversationVC.h"
#import "WKMySettingManager.h"
@interface WKPCOnlineVC ()

@property(nonatomic,strong) UIImageView *pcIconImgView;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;

@property(nonatomic,strong) UIButton *quitPCBtn;

// ---------- 静音 ----------
@property(nonatomic,strong) UIView *muteBoxView;
@property(nonatomic,strong) UIImageView *muteIconImgView;
@property(nonatomic,strong) UILabel *muteLbl;

// ---------- 文件 ----------
@property(nonatomic,strong) UIView *fileBoxView;
@property(nonatomic,strong) UIImageView *fileIconImgView;
@property(nonatomic,strong) UILabel *fileLbl;

@end

@implementation WKPCOnlineVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    
    self.navigationBar.backgroundColor = self.view.backgroundColor;
    
    [self.view addSubview:self.pcIconImgView];
    [self.view addSubview:self.titleLbl];
    [self.view addSubview:self.subtitleLbl];
    [self.view addSubview:self.quitPCBtn];
    
    [self.view addSubview:self.muteBoxView];
    [self.muteBoxView addSubview:self.muteIconImgView];
    [self.view addSubview:self.muteLbl];
    
    [self.view addSubview:self.fileBoxView];
    [self.fileBoxView addSubview:self.fileIconImgView];
    [self.view addSubview:self.fileLbl];
    
    
    [self layout];
}

- (void)setMute:(BOOL)mute {
    _mute = mute;
    
    if(mute) {
        self.subtitleLbl.text = @"手机通知已关闭";
        self.muteBoxView.backgroundColor = [WKApp shared].config.themeColor;
        self.muteIconImgView.tintColor = [UIColor whiteColor];
        
        self.pcIconImgView.image = [self imageName:@"ConversationList/Device/PCSilence"];
    }else {
        self.subtitleLbl.text = @"手机通知已开启";
        self.muteBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.muteIconImgView.tintColor = [UIColor grayColor];
        self.pcIconImgView.image = [self imageName:@"ConversationList/Device/PCNormal"];
    }
    
    
    [self.subtitleLbl sizeToFit];
    [self layout];
}

-(void) layout {
    
    self.pcIconImgView.lim_top = [[WKApp shared].config visibleEdgeInsets].top + 120.0f;
    self.pcIconImgView.lim_centerX_parent = self.view;
    
    self.titleLbl.lim_top = self.pcIconImgView.lim_bottom + 30.0f;
    self.titleLbl.lim_centerX_parent = self.view;
    
    self.subtitleLbl.lim_top = self.titleLbl.lim_bottom + 10.0f;
    self.subtitleLbl.lim_centerX_parent = self.view;
    
    self.muteBoxView.lim_top = self.subtitleLbl.lim_bottom + 60.0f;
    self.muteBoxView.lim_left = 60.0f;
    self.muteIconImgView.lim_centerX_parent = self.muteBoxView;
    self.muteIconImgView.lim_centerY_parent = self.muteBoxView;
    
    self.muteLbl.lim_left = self.muteBoxView.lim_left + (self.muteBoxView.lim_width/2.0f - self.muteLbl.lim_width/2.0f);
    self.muteLbl.lim_top = self.muteBoxView.lim_bottom + 4.0f;
    
    self.fileBoxView.lim_top = self.muteBoxView.lim_top;
    self.fileBoxView.lim_left = self.view.lim_width - self.fileBoxView.lim_width - 60.0f;
    self.fileIconImgView.lim_centerY_parent = self.fileBoxView;
    self.fileIconImgView.lim_centerX_parent = self.fileBoxView;
    
    self.fileLbl.lim_left = self.fileBoxView.lim_left + (self.fileBoxView.lim_width/2.0f - self.fileLbl.lim_width/2.0f);
    self.fileLbl.lim_top = self.fileBoxView.lim_bottom + 4.0f;
    
    [self.quitPCBtn sizeToFit];
    self.quitPCBtn.lim_size = CGSizeMake(self.quitPCBtn.lim_width + 40.0f, self.quitPCBtn.lim_height + 10.0f);
    self.quitPCBtn.lim_top = self.view.lim_height - [[WKApp shared].config visibleEdgeInsets].bottom - 60.0f;
    self.quitPCBtn.lim_centerX_parent = self.view;
    
    
}

- (UIImageView *)pcIconImgView {
    if(!_pcIconImgView) {
        _pcIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 200.0f, 120.0f)];
        _pcIconImgView.image = [self imageName:@"ConversationList/Device/PCNormal"];
    }
    return _pcIconImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:24.0f];
        _titleLbl.text = [NSString stringWithFormat:LLang(@"网页%@已登录"),[WKApp shared].config.appName];
        [_titleLbl sizeToFit];
    }
    return _titleLbl;
}

- (UILabel *)subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] init];
        _subtitleLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _subtitleLbl.textColor = [WKApp shared].config.tipColor;
    }
    return _subtitleLbl;
}

- (UIButton *)quitPCBtn {
    if(!_quitPCBtn) {
        _quitPCBtn = [[UIButton alloc] init];
        [_quitPCBtn setTitle:[NSString stringWithFormat:LLang(@"退出网页%@"),[WKApp shared].config.appName] forState:UIControlStateNormal];
        [_quitPCBtn sizeToFit];
        [_quitPCBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        _quitPCBtn.layer.masksToBounds = YES;
        _quitPCBtn.layer.cornerRadius = 8.0f;
        [_quitPCBtn.titleLabel setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        _quitPCBtn.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        [_quitPCBtn addTarget:self action:@selector(quitPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _quitPCBtn;
}

-(void) quitPressed {
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:[NSString stringWithFormat:LLang(@"退出网页%@？"),[WKApp shared].config.appName]];
    
    __weak typeof(self) weakSelf = self;
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"退出") onClick:^{
        [weakSelf.view showHUD];
        [[WKAPIClient sharedClient] POST:@"user/pc/quit" parameters:nil].then(^{
            [weakSelf.view hideHud];
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }).catch(^(NSError *error){
            [weakSelf.view hideHud];
            [weakSelf.view showHUDWithHide:error.domain];
        });
    }]];
    [sheet show];
}

- (UIView *)muteBoxView {
    if(!_muteBoxView) {
        _muteBoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 80.0f, 80.0f)];
        _muteBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _muteBoxView.layer.masksToBounds = YES;
        _muteBoxView.layer.cornerRadius = _muteBoxView.lim_height/2.0f;
        _muteBoxView.userInteractionEnabled = YES;
        [_muteBoxView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mutePressed)]];
    }
    return _muteBoxView;
}

-(void) mutePressed {
    self.mute = !self.mute;
    WKOnlineStatusManager.shared.muteOfApp = self.mute;
    [WKMySettingManager.shared muteOfApp:self.mute];
}

- (UIImageView *)muteIconImgView {
    if(!_muteIconImgView) {
        _muteIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        _muteIconImgView.image = [self imageName:@"ConversationList/Device/Mute"];
        _muteIconImgView.image = [_muteIconImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return _muteIconImgView;
}

- (UILabel *)muteLbl {
    if(!_muteLbl) {
        _muteLbl = [[UILabel alloc] init];
        _muteLbl.text = LLang(@"手机静音");
        _muteLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _muteLbl.textColor = [WKApp shared].config.tipColor;
        [_muteLbl sizeToFit];
    }
    return _muteLbl;
}

- (UIView *)fileBoxView {
    if(!_fileBoxView) {
        _fileBoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 80.0f, 80.0f)];
        _fileBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _fileBoxView.layer.masksToBounds = YES;
        _fileBoxView.layer.cornerRadius = _fileBoxView.lim_height/2.0f;
        [_fileBoxView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(filePressed)]];
    }
    return _fileBoxView;
}

-(void) filePressed {
    WKConversationVC *vc = [WKConversationVC new];
    vc.channel = WKFileHelperChannel;
    [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
}

- (UIImageView *)fileIconImgView {
    if(!_fileIconImgView) {
        _fileIconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        _fileIconImgView.image = [self imageName:@"ConversationList/Device/TransFile"];
    }
    return _fileIconImgView;
}

- (UILabel *)fileLbl {
    if(!_fileLbl) {
        _fileLbl = [[UILabel alloc] init];
        _fileLbl.text = LLang(@"传文件");
        _fileLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _fileLbl.textColor = [WKApp shared].config.tipColor;
        [_fileLbl sizeToFit];
    }
    return _fileLbl;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
