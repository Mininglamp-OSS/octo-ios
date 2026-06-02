//
//  WKMeAvatarVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WKMeAvatarVC.h"
#import "WKActionSheetView2.h"
#import "WKMediaPickerController.h"
#import "TOCropViewController.h"
#import "WKAvatarMediaFlow.h"
#import <SDWebImage/SDAnimatedImage.h>
@interface WKMeAvatarVC ()<TOCropViewControllerDelegate>

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UIButton *moreButtonItem;


@end

@implementation WKMeAvatarVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.rightView = self.moreButtonItem;
    [self.view addSubview:self.avatarImgView];
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
    self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid cacheKey:info.avatarCacheKey];
}

- (NSString *)langTitle {
    return LLang(@"个人头像");
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, [self visibleRect].origin.y + 100.0f, WKScreenWidth, WKScreenWidth)];
    }
    return _avatarImgView;
}

// 右上角更多按钮
-(UIButton*) moreButtonItem {
    if(!_moreButtonItem) {
        _moreButtonItem = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButtonItem addTarget:self action:@selector(moreBtnPress) forControlEvents:UIControlEventTouchUpInside];
        _moreButtonItem.frame = CGRectMake(0 , 0, 44, 44);
//       _moreButtonItem =[[UIBarButtonItem alloc] initWithCustomView:button];
        
        UIImage *img = [[self imageName:@"Common/Index/More"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_moreButtonItem setImage:img forState:UIControlStateNormal];
        [_moreButtonItem setTintColor:WKApp.shared.config.navBarButtonColor];
    }
    return _moreButtonItem;
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


#pragma mark -- 事件

// 更多点击
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
        UIImageWriteToSavedPhotosAlbum(self.avatarImgView.avatarImgView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }]];
    [actionSheet show];
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    // 保存完毕
       if (error) {
           [self.view showHUDWithHide:LLang(@"保存失败！")];
       }else{
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
didCropToImage:(nonnull UIImage *)image withRect:(CGRect)cropRect
                     angle:(NSInteger)angle {
    [self dismissViewControllerAnimated:YES completion:nil];


    NSData *data = [[WKPhotoService shared] compressImageSize:image toByte:1024*50]; // 压缩到50k


    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];
    [[WKAPIClient sharedClient] fileUpload:@"users/{uid}/avatar" data:data progress:^(NSProgress * _Nonnull progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id  _Nullable resposeObject, NSError * _Nullable error) {
        if(error) {
            [weakSelf.view switchHUDSuccess:LLangW(@"上传失败", weakSelf)];
            WKLogError(@"上传失败！-> %@",error);
        }else {
            NSLog(@"[Avatar] upload success, imageSize=%@", NSStringFromCGSize(image.size));
            weakSelf.avatarImgView.avatarImgView.image = image;
            [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];

            // 生成新的 avatarCacheKey，统一使用 cacheKey URL 体系
            NSString *uid = [WKApp shared].loginInfo.uid;
            [[WKSDK shared].channelManager refreshAvatarCacheKey:[WKChannel personWithChannelID:uid]];
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:uid]];
            NSString *avatarKey = [WKAvatarUtil getAvatar:uid cacheKey:info.avatarCacheKey];

            // 写入 SDWebImage 缓存（内存 + 磁盘）
            [[SDImageCache sharedImageCache] storeImage:image forKey:avatarKey toDisk:YES completion:nil];

            // 清除 NSURLCache 中该 URL 的 HTTP 缓存
            [[NSURLCache sharedURLCache] removeCachedResponseForRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:avatarKey]]];

            // 发送通知，其他页面从缓存加载新头像
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_USER_AVATAR_UPDATE object:@{@"uid":uid?:@""}];
        }

    }];
}

#pragma mark - 动图上传

// 动图头像（GIF / APNG / 动 WebP / 视频转 GIF）上传：跳过裁剪 & JPEG 压缩，
// 直接把原始字节扔给后端；缓存层用 storeImageData: 保留动画。
-(void) uploadAnimatedAvatar:(NSData *)data {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];
    [[WKAPIClient sharedClient] fileUpload:@"users/{uid}/avatar"
                                       data:data
                                   progress:^(NSProgress * _Nonnull progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id  _Nullable resposeObject, NSError * _Nullable error) {
        if (error) {
            [weakSelf.view switchHUDSuccess:LLangW(@"上传失败", weakSelf)];
            WKLogError(@"动图头像上传失败！-> %@", error);
            return;
        }

        UIImage *previewImg = [SDAnimatedImage imageWithData:data] ?: [UIImage imageWithData:data];
        weakSelf.avatarImgView.avatarImgView.image = previewImg;
        [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];

        NSString *uid = [WKApp shared].loginInfo.uid;
        [[WKSDK shared].channelManager refreshAvatarCacheKey:[WKChannel personWithChannelID:uid]];
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:uid]];
        NSString *avatarKey = [WKAvatarUtil getAvatar:uid cacheKey:info.avatarCacheKey];

        // 关键差异：传 imageData，让磁盘缓存留住完整动画字节；内存缓存放 SDAnimatedImage 实例
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
