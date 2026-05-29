//
//  WKGroupQRCodeVC.m
//  WuKongBase
//
//  Created by tt on 2020/4/2.
//

#import "WKGroupQRCodeVC.h"
#import "WuKongBase.h"
#import <LBXScan/LBXScanNative.h>
#import "WKAvatarUtil.h"
#import "WKGroupQRCodeVM.h"
#import "WKResource.h"
#import "WKActionSheetView2.h"
@interface WKGroupQRCodeVC ()

@property(nonatomic,strong) UIView *qrcodeBoxView; // 整个白色容器

@property(nonatomic,strong) UIImageView *qrcodeImgView; // 二维码图片

@property(nonatomic,strong) UIView *qrcodeMaskView; // 开启进群验证后，二维码图片的覆盖层

@property(nonatomic,strong) WKChannelInfo *channelInfo; // 频道信息

@property(nonatomic,strong) WKUserAvatar *avatarImgView; // 群头像

@property(nonatomic,strong) UILabel *titleLbl; // 群标题

@property(nonatomic,strong) UILabel *remarkLbl; // 二维码备注

@property(nonatomic,strong) WKGroupQRCodeVM *vm;

@property(nonatomic,strong) UIActivityIndicatorView *activityView;

@property(nonatomic,strong) UIButton *moreButtonItem; // 顶部右边更多按钮

@property(nonatomic,strong) UIButton *copyInviteBtn; // 复制邀请链接按钮（）
@property(nonatomic,copy) NSString *inviteUrl; // 跨 Space 邀请链接（v2 外部群入群入口）


@end

@implementation WKGroupQRCodeVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.vm = [[WKGroupQRCodeVM alloc] initWithChannel:self.channel];
    
    self.rightView = self.moreButtonItem;
    
    self.channelInfo = [[WKChannelManager shared] getChannelInfo:self.channel];
    
    [self.view addSubview:self.qrcodeBoxView];
    
    [self.qrcodeBoxView addSubview:self.qrcodeImgView];
    
    [self.qrcodeBoxView addSubview:self.qrcodeMaskView];
    
    [self.qrcodeBoxView addSubview:self.avatarImgView];
    
    [self.qrcodeBoxView addSubview:self.titleLbl];
    
    [self.qrcodeBoxView addSubview:self.remarkLbl];

    // : 复制邀请链接按钮，挂在 qrcode box 外部底部，默认隐藏直到请求返回 invite_url
    [self.view addSubview:self.copyInviteBtn];

    //

    [self.qrcodeImgView addSubview:self.activityView];


    __weak typeof(self) weakSelf = self;
    [self.activityView startAnimating];
    [self.vm requestGetQRCodeInfo].then(^(WKGroupQRCodeInfoModel *model){
        if(weakSelf.channelInfo.invite) {
             weakSelf.qrcodeMaskView.hidden = NO;
        }else {
            weakSelf.qrcodeMaskView.hidden = YES;
            [weakSelf updateRemark: [NSString stringWithFormat:LLangW(@"该二维码%ld天内(%@)前有效，重新进入将更新",weakSelf),(long)model.day,model.expire]];

        }
         weakSelf.qrcodeImgView.image =  [LBXScanNative createQRWithString:model.qrcode QRSize:weakSelf.qrcodeImgView.lim_size];
        [weakSelf.activityView stopAnimating];
        // : 拿到 invite_url 后再显示复制按钮。空字符串 / nil 保持隐藏以兼容旧后端。
        [weakSelf applyInviteUrl:model.inviteUrl];

    });
}

- (NSString *)langTitle {
    return LLang(@"群二维码名片");
}

// nav title 由 base class 通过 langTitle 自动刷; 这里刷复制按钮 + mask 文案。
// updateRemark 那条 (含动态天数/失效时间) 没有最新模型, 只能等下次进页重拉, 暂不刷。
- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if (type != WKViewConfigChangeTypeLang) return;
    if (_copyInviteBtn) {
        [_copyInviteBtn setTitle:LLang(@"复制邀请链接") forState:UIControlStateNormal];
    }
    if (_qrcodeMaskView) {
        UILabel *l1 = (UILabel *)[_qrcodeMaskView viewWithTag:9001];
        UILabel *l2 = (UILabel *)[_qrcodeMaskView viewWithTag:9002];
        l1.text = LLang(@"该群已开启进群验证");
        l2.text = LLang(@"只可通过邀请进群");
    }
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
        [actionSheetView hide];
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
        titleLbl1.tag = 9001;     // viewConfigChange 切语言时按 tag 反查重置
        titleLbl1.text = LLang(@"该群已开启进群验证");
        [titleLbl1 setFont:[UIFont systemFontOfSize:20.0f]];
        [titleLbl1 setTextColor:[UIColor grayColor]];
        [titleLbl1 sizeToFit];
        [_qrcodeMaskView addSubview:titleLbl1];
        titleLbl1.lim_left = _qrcodeMaskView.lim_width/2.0f - titleLbl1.lim_width/2.0f;
        titleLbl1.lim_top = _qrcodeMaskView.lim_height/2.0f - titleLbl1.lim_height;
        
        UILabel *titleLbl2 = [[UILabel alloc] init];
        titleLbl2.tag = 9002;
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
        [_avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:[WKAvatarUtil getGroupAvatar:self.channel.channelId]]];
    }
    return _avatarImgView;
}

-(UILabel*) titleLbl {
    if(!_titleLbl) {
         _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, self.avatarImgView.lim_bottom + 5.0f, self.qrcodeBoxView.lim_width, 18.0f)];
        _titleLbl.numberOfLines = 1.0f;
        _titleLbl.textAlignment = NSTextAlignmentCenter;
        _titleLbl.text = self.channelInfo.name;
       [_titleLbl setFont:[[WKApp shared].config appFontOfSizeMedium:16.0f]];
        
    }
    return _titleLbl;
}

-(UILabel*) remarkLbl {
    if(!_remarkLbl) {
        _remarkLbl = [[UILabel alloc] init];
        _remarkLbl.font = [UIFont systemFontOfSize:12.0f];
        _remarkLbl.numberOfLines = 0;
        _remarkLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _remarkLbl.textColor = [UIColor grayColor];
    }
    return _remarkLbl;
}

-(void) updateRemark:(NSString*)remark {
    self.remarkLbl.text = remark;
    self.remarkLbl.lim_top = self.qrcodeImgView.lim_bottom + 20.0f;
    self.remarkLbl.lim_width = self.qrcodeBoxView.lim_width - 40.0f;
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
}

#pragma mark - 复制邀请链接

// 按钮懒加载：默认隐藏，等 applyInviteUrl: 收到非空字符串后再显示。
// 防御 静默失败：显式在 applyInviteUrl: 里校验 model.inviteUrl 的类型和长度，
// 避免后端字段改名后 UI 悄悄退化（按钮常驻不可点 / 点击后复制空串）。
-(UIButton*) copyInviteBtn {
    if(!_copyInviteBtn) {
        _copyInviteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_copyInviteBtn setTitle:LLang(@"复制邀请链接") forState:UIControlStateNormal];
        [_copyInviteBtn setTitleColor:WKApp.shared.config.themeColor forState:UIControlStateNormal];
        _copyInviteBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f];
        [_copyInviteBtn addTarget:self action:@selector(copyInvitePressed) forControlEvents:UIControlEventTouchUpInside];
        _copyInviteBtn.hidden = YES;
    }
    return _copyInviteBtn;
}

-(void) applyInviteUrl:(NSString*)inviteUrl {
    NSString *trimmed = [inviteUrl isKindOfClass:[NSString class]]
        ? [inviteUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : nil;
    if (trimmed.length == 0) {
        self.inviteUrl = nil;
        self.copyInviteBtn.hidden = YES;
        return;
    }
    self.inviteUrl = trimmed;
    self.copyInviteBtn.hidden = NO;
    [self.copyInviteBtn sizeToFit];
    CGFloat w = MAX(self.copyInviteBtn.lim_width + 32.0f, 160.0f);
    CGFloat h = 40.0f;
    // 小屏兼容 (iPhone SE 1st gen 320×568 / 老设备 iOS 12+)：
    // qrcodeBoxView 高 = screenWidth-40 + 140, 会把 320pt 宽屏塞到接近底部。
    // 若按钮「紧贴 box 下方 +20」超出可视区，就钳制到安全底部上方 20pt，
    // 保证按钮始终可点（宁可和 box 轻微重叠也不能整体掉出屏幕）。
    CGFloat preferredTop = self.qrcodeBoxView.lim_bottom + 20.0f;
    CGFloat maxTop = self.view.lim_height - [self safeBottom] - h - 20.0f;
    CGFloat top = MIN(preferredTop, MAX(maxTop, 0.0f));
    self.copyInviteBtn.frame = CGRectMake((self.view.lim_width - w) / 2.0f,
                                          top,
                                          w,
                                          h);
}

-(void) copyInvitePressed {
    // 兜底：即使按钮显示了也再校验一次，防止 inviteUrl 被上层清空后竞态点击。
    NSString *url = self.inviteUrl;
    if (![url isKindOfClass:[NSString class]] || url.length == 0) {
        [self.view showHUDWithHide:LLang(@"邀请链接不可用")];
        return;
    }
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = url;
    [self.view showHUDWithHide:LLang(@"复制成功")];
}

@end
