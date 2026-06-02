//
//  WKBotAvatarVC.m
//  WuKongBase
//

#import "WKBotAvatarVC.h"
#import "WKActionSheetView2.h"
#import "WKMediaPickerController.h"
#import "TOCropViewController.h"
#import "WKAvatarMediaFlow.h"
#import <SDWebImage/SDAnimatedImage.h>

@interface WKBotAvatarVC ()<TOCropViewControllerDelegate>

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UIButton *moreButtonItem;

@end

@implementation WKBotAvatarVC

- (void)viewDidLoad {
    [super viewDidLoad];

    // 仅创建者可见 3-dots 编辑入口；非创建者打开本页只是全屏查看。
    if(self.canEdit) {
        self.navigationBar.rightView = self.moreButtonItem;
    }

    [self.view addSubview:self.avatarImgView];

    if(self.botUid.length > 0) {
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:self.botUid]];
        self.avatarImgView.url = [WKAvatarUtil getAvatar:self.botUid cacheKey:info.avatarCacheKey];
    }
}

- (NSString *)langTitle {
    return LLang(@"机器人头像");
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, [self visibleRect].origin.y + 100.0f, WKScreenWidth, WKScreenWidth)];
    }
    return _avatarImgView;
}

// 右上角更多按钮（与 WKMeAvatarVC 同款资源 + 同款交互）
-(UIButton*) moreButtonItem {
    if(!_moreButtonItem) {
        _moreButtonItem = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButtonItem addTarget:self action:@selector(moreBtnPress) forControlEvents:UIControlEventTouchUpInside];
        _moreButtonItem.frame = CGRectMake(0, 0, 44, 44);

        UIImage *img = [[self imageName:@"Common/Index/More"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_moreButtonItem setImage:img forState:UIControlStateNormal];
        [_moreButtonItem setTintColor:WKApp.shared.config.navBarButtonColor];
    }
    return _moreButtonItem;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

#pragma mark -- 事件

-(void) moreBtnPress {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *actionSheet = [WKActionSheetView2 initWithTip:nil];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"拍照") onClick:^{
        [weakSelf cameraPressed];
    }]];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"从手机相册选择") onClick:^{
        [WKAvatarMediaFlow pickAvatarFromLibraryWithHost:weakSelf
                                              onAnimated:^(NSData *gifData) {
            [weakSelf uploadAnimatedAvatar:gifData];
        } onStaticPicked:^(UIImage *image) {
            [weakSelf cropAvatar:image];
        }];
    }]];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"保存图片") onClick:^{
        UIImage *currentImg = weakSelf.avatarImgView.avatarImgView.image;
        if(currentImg) {
            UIImageWriteToSavedPhotosAlbum(currentImg, weakSelf, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
    }]];
    [actionSheet show];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if(error) {
        [self.view showHUDWithHide:LLang(@"保存失败！")];
    } else {
        [self.view showHUDWithHide:LLang(@"保存成功！")];
    }
}

-(void) cameraPressed {
    __weak typeof(self) weakSelf = self;
    [[WKPhotoService shared] getPhotoFromCamera:^(UIImage * _Nonnull image) {
        [weakSelf cropAvatar:image];
    }];
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
            didCropToImage:(nonnull UIImage *)image
                  withRect:(CGRect)cropRect
                     angle:(NSInteger)angle {
    [self dismissViewControllerAnimated:YES completion:nil];

    if(self.botUid.length == 0) {
        [self.view showHUDWithHide:LLang(@"上传失败")];
        return;
    }

    NSData *data = [[WKPhotoService shared] compressImageSize:image toByte:1024*50];

    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];

    // 路径与 Android `UserModel.uploadAvatar`（wkuikit/.../user/service/UserModel.java:169-171）
    // 同源：`users/<botUid>/avatar`。`WKMeAvatarVC` 用的 `users/{uid}/avatar` 是后端
    // 对自身的 placeholder，Bot 头像必须显式带上 botUid，由后端校验当前登录者的
    // 创建者权限（前端 canEdit 仅是 UI gate，权威授权在服务端）。
    NSString *uploadPath = [NSString stringWithFormat:@"users/%@/avatar", self.botUid];
    [[WKAPIClient sharedClient] fileUpload:uploadPath data:data progress:^(NSProgress * _Nonnull progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id  _Nullable resposeObject, NSError * _Nullable error) {
        if(error) {
            [weakSelf.view switchHUDSuccess:LLangW(@"上传失败", weakSelf)];
            WKLogError(@"Bot头像上传失败 -> %@", error);
            return;
        }

        weakSelf.avatarImgView.avatarImgView.image = image;
        [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];

        // 对齐 WKMeAvatarVC.cropViewController 的缓存刷新链路：
        // 1) 旋转 avatarCacheKey → 2) 写入 SDImageCache（避免空窗）→
        // 3) 清 NSURLCache → 4) 广播 WKNOTIFY_USER_AVATAR_UPDATE 让所有列表 / 头像 view 跟新
        NSString *uid = weakSelf.botUid;
        WKChannel *botChannel = [WKChannel personWithChannelID:uid];
        [[WKSDK shared].channelManager refreshAvatarCacheKey:botChannel];
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:botChannel];
        NSString *avatarKey = [WKAvatarUtil getAvatar:uid cacheKey:info.avatarCacheKey];

        [[SDImageCache sharedImageCache] storeImage:image forKey:avatarKey toDisk:YES completion:nil];
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:avatarKey]]];

        [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_USER_AVATAR_UPDATE object:@{@"uid": uid ?: @""}];
    }];
}

#pragma mark - 动图上传

// 动图头像（GIF / APNG / 动 WebP / 视频转 GIF）上传：跳过 TOCropViewController 与 JPEG 压缩，
// 直接把字节扔后端；缓存层用 storeImageData: 保留动画。
-(void) uploadAnimatedAvatar:(NSData *)data {
    if (self.botUid.length == 0) {
        [self.view showHUDWithHide:LLang(@"上传失败")];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];

    NSString *uploadPath = [NSString stringWithFormat:@"users/%@/avatar", self.botUid];
    [[WKAPIClient sharedClient] fileUpload:uploadPath
                                       data:data
                                   progress:^(NSProgress * _Nonnull progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id  _Nullable resposeObject, NSError * _Nullable error) {
        if (error) {
            [weakSelf.view switchHUDSuccess:LLangW(@"上传失败", weakSelf)];
            WKLogError(@"Bot 动图头像上传失败 -> %@", error);
            return;
        }

        UIImage *previewImg = [SDAnimatedImage imageWithData:data] ?: [UIImage imageWithData:data];
        weakSelf.avatarImgView.avatarImgView.image = previewImg;
        [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];

        NSString *uid = weakSelf.botUid;
        WKChannel *botChannel = [WKChannel personWithChannelID:uid];
        [[WKSDK shared].channelManager refreshAvatarCacheKey:botChannel];
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:botChannel];
        NSString *avatarKey = [WKAvatarUtil getAvatar:uid cacheKey:info.avatarCacheKey];

        [[SDImageCache sharedImageCache] storeImage:previewImg
                                           imageData:data
                                              forKey:avatarKey
                                              toDisk:YES
                                          completion:nil];
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:
            [NSURLRequest requestWithURL:[NSURL URLWithString:avatarKey]]];

        [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_USER_AVATAR_UPDATE
                                                            object:@{@"uid": uid ?: @""}];
    }];
}

@end
