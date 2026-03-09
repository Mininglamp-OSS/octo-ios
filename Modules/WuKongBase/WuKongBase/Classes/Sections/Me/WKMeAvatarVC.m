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
@interface WKMeAvatarVC ()<TOCropViewControllerDelegate>

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UIButton *moreButtonItem;


@end

@implementation WKMeAvatarVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.rightView = self.moreButtonItem;
    [self.view addSubview:self.avatarImgView];
    self.avatarImgView.url = [WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid];
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
        [[WKPhotoService shared] getPhotoOneFromLibrary:^(UIImage * _Nonnull image) {
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
            weakSelf.avatarImgView.avatarImgView.image = image;
            [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];
            [[SDImageCache sharedImageCache] removeImageForKey:[WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid] withCompletion:nil];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:WKNOTIFY_USER_AVATAR_UPDATE object:@{@"uid":[WKApp shared].loginInfo.uid?:@""}];
        }
        
    }];
}


@end
