//
//  WKRegisterNextVC.m
//  WuKongLogin
//
//  Created by tt on 2020/7/29.
//

#import "WKRegisterNextVC.h"
#import "WKActionSheetView2.h"
#import "TOCropViewController.h"
@interface WKRegisterNextVC ()<TOCropViewControllerDelegate>

@property(nonatomic,strong) UILabel *tipLbl; // 提醒文字
@property(nonatomic,strong) UIImageView *defaultAvatarImgView; // 默认头像
@property(nonatomic,strong) UITextField *nameTextFd; // 名字输入
@property(nonatomic,strong) UIView *lineView;
@property(nonatomic,strong) UIButton *okBtn; // 确定按钮

@property(nonatomic,assign) BOOL avatarIsUploaded; // 头像是否已上传

@end

@implementation WKRegisterNextVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKRegisterVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    [self.navigationBar setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:self.tipLbl];
    [self.view addSubview:self.defaultAvatarImgView];
    [self.view addSubview:self.nameTextFd];
    [self.view addSubview:self.lineView];
    [self.view addSubview:self.okBtn];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}


- (NSString *)langTitle {
    return LLang(@"完善个人资料");
}


- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.text = LLang(@"请设置你的个人头像和昵称");
        [_tipLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_tipLbl setTextColor:[[WKApp shared].config defaultTextColor]];
        [_tipLbl sizeToFit];
        _tipLbl.lim_left = self.view.lim_width/2.0f - _tipLbl.lim_width/2.0f;
        _tipLbl.lim_top = self.navigationBar.lim_bottom + 40.0f;
    }
    return _tipLbl;
}

- (UIImageView *)defaultAvatarImgView {
    if(!_defaultAvatarImgView) {
        _defaultAvatarImgView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.lim_width/2.0f - 70.0f/2.0f, self.tipLbl.lim_bottom+20.0f, 70.0f, 70.0f)];
        [_defaultAvatarImgView setImage:[self imageName:@"DefaultReigsterAvatar"]];
        _defaultAvatarImgView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarPressed)];
        [_defaultAvatarImgView addGestureRecognizer:tap];
    }
    return _defaultAvatarImgView;
}

- (UITextField *)nameTextFd {
    if(!_nameTextFd) {
        _nameTextFd = [[UITextField alloc] initWithFrame:CGRectMake(15.0f, self.defaultAvatarImgView.lim_bottom+20.0f, self.view.lim_width-30.0f, 44.0f)];
        [_nameTextFd setPlaceholder:LLang(@"名字(必填)")];
    }
    return _nameTextFd;
}

- (UIView *)lineView {
    if(!_lineView) {
        _lineView = [[UIView alloc] initWithFrame:CGRectMake(self.nameTextFd.lim_left, self.nameTextFd.lim_bottom, self.nameTextFd.lim_width, 1.0f)];
        [_lineView setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
    return _lineView;
}

- (UIButton *)okBtn {
    if(!_okBtn) {
        _okBtn = [[UIButton alloc] initWithFrame:CGRectMake(15.0f, self.lineView.lim_bottom + 20.0f, self.view.lim_width-30.0f, 44.0f)];
        _okBtn.layer.masksToBounds = YES;
        _okBtn.layer.cornerRadius = 4.0f;
        [_okBtn setTitle:LLang(@"确定") forState:UIControlStateNormal];
        [_okBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_okBtn addTarget:self action:@selector(okPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [WKApp.shared.config setThemeStyleButton:_okBtn];
    }
    return _okBtn;
}

-(UIImage*) imageName:(NSString*)name {
    return [[WKApp shared] loadImage:name moduleID:@"WuKongLogin"];
}

#pragma mark -- 事件

// 头像点击
-(void) avatarPressed {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *actionSheet = [WKActionSheetView2 initWithTip:nil];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"拍照") onClick:^{
        [[WKPhotoService shared] getPhotoFromCamera:^(UIImage * _Nonnull image) {
            [weakSelf cropAvatar:image];
        }];
    }]];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"从手机相册选择") onClick:^{
        [[WKPhotoService shared] getPhotoOneFromLibrary:^(UIImage * _Nonnull image) {
            [weakSelf cropAvatar:image];
        }];
    }]];
    [actionSheet show];
}

-(void) okPressed {
    if(!self.avatarIsUploaded) {
        [self.view showHUDWithHide:LLang(@"头像不能为空！")];
        return;
    }
    NSString *name = self.nameTextFd.text;
    if(!name || [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"名字不能为空！")];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"提交中")];
    [self.viewModel updateName:name].then(^{
        [weakSelf.view hideHud];
        [WKApp shared].loginInfo.extra[@"name"] =name;
        [[WKApp shared].loginInfo save];
        
        [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
    
    }).catch(^(NSError *error){
        [weakSelf.view switchHUDError:error.domain];
    });
}

-(void) cropAvatar:(UIImage*)avatarImg {
    TOCropViewController *cropController = [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleDefault image:avatarImg];
    cropController.delegate = self;
    cropController.aspectRatioPreset = TOCropViewControllerAspectRatioPresetSquare;
    cropController.aspectRatioPickerButtonHidden = YES;
    [self presentViewController:cropController animated:YES completion:nil];
}


#pragma mark - TOCropViewControllerDelegate

- (void)cropViewController:(nonnull TOCropViewController *)cropViewController
didCropToImage:(nonnull UIImage *)image withRect:(CGRect)cropRect
                     angle:(NSInteger)angle {
    [self dismissViewControllerAnimated:YES completion:nil];
   
    
    NSData *data = [[WKPhotoService shared] compressImageSize:image toByte:1024*50]; // 压缩到50k
    
     NSLog(@"头像大小->%ld K",data.length/1024);
    
    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];
    [[WKAPIClient sharedClient] fileUpload:@"users/{uid}/avatar" data:data progress:^(NSProgress * _Nonnull progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id  _Nullable resposeObject, NSError * _Nullable error) {
        if(error) {
            [weakSelf.view switchHUDSuccess:LLang(@"上传失败")];
            WKLogError(@"上传失败！-> %@",error);
        }else {
            weakSelf.avatarIsUploaded = true;
            weakSelf.defaultAvatarImgView.image = image;
            [weakSelf.view switchHUDSuccess:LLang(@"上传成功")];
            [[SDImageCache sharedImageCache] removeImageForKey:[WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid] withCompletion:nil];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_USER_AVATAR_UPDATE object:@{@"uid":[WKApp shared].loginInfo.uid?:@""}];
        }
        
    }];
}

@end
