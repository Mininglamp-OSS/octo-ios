//
//  NIMKitPhotoFetcher.m
//  NIMKit
//
//  Created by chris on 2016/11/12.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import "WKMediaPickerController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <TZImagePickerController/TZImagePickerController.h>
//#import "NIMKitProgressHUD.h"
#import "WKFileLocationHelper.h"
#import "WKConstant.h"
#import "WKProgressHUD.h"
#import "WuKongBase.h"
#import "LBXPermissionSetting.h"
#import "NSData+ImageFormat.h"
#import "UIImage+Compression.h"
//#import <ZLPhotoBrowser/ZLPhotoBrowser.h>

@interface WKMediaPickerController : TZImagePickerController

@end

@implementation WKMediaPickerController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].statusBarStyle =  UIStatusBarStyleDefault;
}

- (void)dealloc
{
}

@end

@interface WKMediaFetcher()<TZImagePickerControllerDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate>

@property (nonatomic,copy)   WKLibraryFetchResult libraryResultHandler;

@property (nonatomic,copy)   WKCameraFetchResult  cameraResultHandler;

@property (nonatomic,strong) UIImagePickerController  *imagePicker;

@property (nonatomic,weak) WKMediaPickerController  *assetsPicker;

@end

@implementation WKMediaFetcher

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mediaTypes = @[(NSString *)kUTTypeMovie,(NSString *)kUTTypeImage];
        _limit = 9;
        _allowTakePicture = YES;
    }
    return self;
}

-(void) dealloc {
}


- (void)fetchPhotoFromLibrary:(WKLibraryFetchResult)result cancel:(void (^)(void))cancel
{
    

    __weak typeof(self) weakSelf = self;
    [self setUpPhotoLibrary:^(WKMediaPickerController * _Nullable picker) {
        if (picker && weakSelf) {
            weakSelf.assetsPicker = picker;
            weakSelf.assetsPicker.imagePickerControllerDidCancelHandle = ^{
                if(cancel) {
                    cancel();
                }
            };
            weakSelf.libraryResultHandler = result;
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:picker animated:YES completion:nil];
            
        }else{
            result(nil,nil,nil,PHAssetMediaTypeUnknown,0);
        }
    }];
}

- (void)fetchPhotoFromLibrary:(WKLibraryFetchResult)result {
    [self fetchPhotoFromLibrary:result cancel:nil];
}

- (void)fetchPhotoFromLibraryOfCompress:(void(^)(NSData *imageData,NSString *path,bool isSelectOriginalPhoto, PHAssetMediaType type,NSInteger left))result cancel:(void (^)(void))cancel {
    
    __weak typeof(self) weakSelf = self;
    [self fetchPhotoFromLibrary:^(UIImage *img, NSString *path,bool isSelectOriginalPhoto, PHAssetMediaType type, NSInteger left) {
        NSData *imageData;
        switch (type) {
            case PHAssetMediaTypeImage:{
                if (path) {
                    imageData = [[NSData alloc] initWithContentsOfFile:path];
                    if(isSelectOriginalPhoto) {
                        if ([path.pathExtension isEqualToString:@"HEIC"]){
                            if (@available(iOS 13.0, *)) {
                                UIImage * originImage =  [[SDImageHEICCoder sharedCoder] decodedImageWithData:[[NSData alloc] initWithContentsOfFile:path] options:@{SDImageCoderEncodeCompressionQuality:@(0.9)}];
                                result(UIImagePNGRepresentation(originImage),path,isSelectOriginalPhoto,type,left);
                                return;
                            }
                        }else{
                            result(imageData,path,isSelectOriginalPhoto,type,left);
                        }
                        
                    }else {
                        JLImageFormat format = [NSData jl_imageFormatWithImageData:imageData];
                        UIImage *image = [[UIImage alloc] initWithData:imageData];
                        if(format == JLImageFormatGIF)  {
                            [UIImage jl_compressWithImageGIF:imageData targetSize:image.size targetByte:[WKApp shared].config.imageMaxLimitBytes handler:^(NSData * _Nullable compressedData, CGSize gifImageSize, NSError * _Nullable error) {
                                if(error) {
                                    [[WKNavigationManager shared].topViewController.view showMsg:LLangW(@"图片压缩错误！",weakSelf)];
                                    return;
                                }
                                result(imageData,path,isSelectOriginalPhoto,type,left);
                                
                            }];
                        }else {
                            NSData *imgData = [UIImage jl_compressImageSize:image toByte:[WKApp shared].config.imageMaxLimitBytes];
                            result(imgData,path,isSelectOriginalPhoto,type,left);
                        }
                    }
                    
                }else if(img) {
                    NSData *imgData  = [UIImage jl_compressImageSize:img toByte:[WKApp shared].config.imageMaxLimitBytes];
                    result(imgData,path,isSelectOriginalPhoto,type,left);
                }
                break;
            }
            default:{
                result(imageData,path,isSelectOriginalPhoto,type,left);
            }
        }
    } cancel:cancel];
}



- (void)fetchMediaFromCamera:(WKCameraFetchResult)result
{
    if ([self initCamera]) {
        self.cameraResultHandler = result;
#if TARGET_IPHONE_SIMULATOR
        NSAssert(0, @"not supported");
#elif TARGET_OS_IPHONE
        self.imagePicker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
        self.imagePicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:self.imagePicker animated:YES completion:nil];
#endif
    }
}


- (void)setUpPhotoLibrary:(void(^)(WKMediaPickerController * _Nullable picker)) handler
{
    __weak typeof(self) weakSelf = self;
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusRestricted || status == PHAuthorizationStatusDenied) {
                
                [LBXPermissionSetting showAlertToDislayPrivacySettingWithTitle:LLangW(@"提示",weakSelf) msg:LLangW(@"没有相册权限，是否前往设置",weakSelf) cancel:LLangW(@"取消",weakSelf) setting:LLangW(@"设置",weakSelf)];
                
                if(handler) handler(nil);
            }
            if (status == PHAuthorizationStatusAuthorized) {
                WKMediaPickerController *vc = [[WKMediaPickerController alloc] initWithMaxImagesCount:weakSelf.limit delegate:weakSelf];
                vc.naviBgColor = [UIColor blackColor];
                vc.naviTitleColor = [UIColor whiteColor];
                vc.barItemTextColor = [UIColor whiteColor];
                vc.navigationBar.barStyle = UIBarStyleDefault;
                vc.allowTakePicture = weakSelf.allowTakePicture;
                vc.allowPickingVideo = [weakSelf.mediaTypes containsObject:(NSString *)kUTTypeMovie];
//                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:vc animated:YES completion:nil];
                if(handler) handler(vc);
            }
        });
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    __weak typeof(self) weakSelf = self;
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *inputURL  = [info objectForKey:UIImagePickerControllerMediaURL];
            NSString *outputFileName = [WKFileLocationHelper genFilenameWithExt:@"mp4"];
            NSString *outputPath = [WKFileLocationHelper filepathForVideo:outputFileName];
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
            AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                             presetName:AVAssetExportPresetMediumQuality];
            session.outputURL = [NSURL fileURLWithPath:outputPath];
            session.outputFileType = AVFileTypeMPEG4;   // 支持安卓某些机器的视频播放
            session.shouldOptimizeForNetworkUse = YES;
            session.videoComposition = [weakSelf getVideoComposition:asset];  //修正某些播放器不识别视频Rotation的问题
            [session exportAsynchronouslyWithCompletionHandler:^(void)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (session.status == AVAssetExportSessionStatusCompleted)
                     {
                         weakSelf.cameraResultHandler(outputPath,nil);
                     }
                     else
                     {
                         weakSelf.cameraResultHandler(nil,nil);
                     }
                     weakSelf.cameraResultHandler = nil;
                 });
             }];
            
        });
        
    }else{
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        weakSelf.cameraResultHandler(nil,image);
        weakSelf.cameraResultHandler = nil;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - 相册回调
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto infos:(NSArray<NSDictionary *> *)infos
{
    
    __weak typeof(self) weakSelf = self;
    [self requestAssets:[assets mutableCopy] isSelectOriginalPhoto:isSelectOriginalPhoto result:^(UIImage *img,NSString *path, bool isSelectOriginalPhoto, PHAssetMediaType type, NSInteger left) {
        if(weakSelf.libraryResultHandler) {
            PHAssetMediaType mediaType = type;
            if(photos && photos.count>0) {
                mediaType = PHAssetMediaTypeImage;
            }
            weakSelf.libraryResultHandler(photos&& photos.count>=assets.count-left?photos[assets.count-left-1]:nil,path,isSelectOriginalPhoto,mediaType,left);
           
        }
    }];
}

- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(id)asset{
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:@[asset]];
    [self requestAssets:items isSelectOriginalPhoto:false result:self.libraryResultHandler];
}

- (void)requestAssets:(NSMutableArray *)assets isSelectOriginalPhoto:(BOOL) isSelectOriginalPhoto result:(WKLibraryFetchResult)result
{
    if (!assets.count) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [WKProgressHUD show];
    [self requestAsset:assets.firstObject handler:^(NSString *path, PHAssetMediaType type) {
        [WKProgressHUD dismiss];
        if (result)
        {
            result(nil,path,isSelectOriginalPhoto,type,assets.count-1);
        }
        WK_Dispatch_Async_Main(^{
            [assets removeObjectAtIndex:0];
            [weakSelf requestAssets:assets isSelectOriginalPhoto:isSelectOriginalPhoto result:result];
        })
        
    }];
}


- (void)requestAsset:(PHAsset *)asset  handler:(void(^)(NSString *,PHAssetMediaType)) handler
{
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHVideoRequestOptionsVersionCurrent;
        options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
        options.networkAccessAllowed = YES;
        
        [[PHImageManager defaultManager] requestExportSessionForVideo:asset options:options exportPreset:AVAssetExportPreset640x480 resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
            
            NSString *outputFileName = [WKFileLocationHelper genFilenameWithExt:@"mp4"];
            NSString *outputPath = [WKFileLocationHelper filepathForVideo:outputFileName];
            
            exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
            exportSession.outputFileType = AVFileTypeMPEG4;
            exportSession.shouldOptimizeForNetworkUse = YES;
            [exportSession exportAsynchronouslyWithCompletionHandler:^(void)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (exportSession.status == AVAssetExportSessionStatusCompleted)
                     {
                         handler(outputPath, PHAssetMediaTypeVideo);
                     }
                     else
                     {
                         handler(nil,PHAssetMediaTypeVideo);
                     }
                 });
             }];
        }];
    }
    
    if (asset.mediaType == PHAssetMediaTypeImage)
    {
        [asset requestContentEditingInputWithOptions:nil completionHandler:^(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary * _Nonnull info) {
            NSString *path = contentEditingInput.fullSizeImageURL.relativePath;
            handler(path,contentEditingInput.mediaType);
        }];
    }
    
}

#pragma mark - Private

- (void)setMediaTypes:(NSArray *)mediaTypes
{
    _mediaTypes = mediaTypes;
    _imagePicker.mediaTypes = mediaTypes;
    _assetsPicker.allowPickingVideo = [mediaTypes containsObject:(NSString *)kUTTypeMovie];
}

- (AVMutableVideoComposition *)getVideoComposition:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    CGSize videoSize = videoTrack.naturalSize;
    BOOL isPortrait_ = [self isVideoPortrait:asset];
    if(isPortrait_) {
        videoSize = CGSizeMake(videoSize.height, videoSize.width);
    }
    composition.naturalSize     = videoSize;
    videoComposition.renderSize = videoSize;
    
    videoComposition.frameDuration = CMTimeMakeWithSeconds( 1 / videoTrack.nominalFrameRate, 600);
    AVMutableCompositionTrack *compositionVideoTrack;
    compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    AVMutableVideoCompositionLayerInstruction *layerInst;
    layerInst = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    [layerInst setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
    AVMutableVideoCompositionInstruction *inst = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    inst.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    inst.layerInstructions = [NSArray arrayWithObject:layerInst];
    videoComposition.instructions = [NSArray arrayWithObject:inst];
    return videoComposition;
}

- (BOOL) isVideoPortrait:(AVAsset *)asset
{
    BOOL isPortrait = NO;
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks    count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        
        CGAffineTransform t = videoTrack.preferredTransform;
        // Portrait
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0)
        {
            isPortrait = YES;
        }
        // PortraitUpsideDown
        if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0)  {
            
            isPortrait = YES;
        }
        // LandscapeRight
        if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0)
        {
            isPortrait = NO;
        }
        // LandscapeLeft
        if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0)
        {
            isPortrait = NO;
        }
    }
    return isPortrait;
}

- (BOOL)initCamera{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:LLang(@"检测不到相机设备")
                                   delegate:nil
                          cancelButtonTitle:LLang(@"确定")
                          otherButtonTitles:nil] show];
        return NO;
    }
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:LLang(@"相机权限受限")
                                   delegate:nil
                          cancelButtonTitle:LLang(@"确定")
                          otherButtonTitles:nil] show];
        return NO;
        
    }
    self.imagePicker = [[UIImagePickerController alloc] init];
    self.imagePicker.delegate = self;
    self.imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePicker.mediaTypes = self.mediaTypes;
    return YES;
}

- (void)originalPhotoWithAsset:(id)asset completion:(void (^)(UIImage *photo,NSDictionary *info,BOOL isDegraded))completion {
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc]init];
    option.networkAccessAllowed = YES;
    option.synchronous = YES;
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeAspectFit options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        BOOL downloadFinined = (![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey]);
        if (downloadFinined && result) {
            result = [self fixOrientation:result];
            BOOL isDegraded = [[info objectForKey:PHImageResultIsDegradedKey] boolValue];
            if (completion) completion(result,info,isDegraded);
        }
    }];
}


/// 修正图片转向
- (UIImage *)fixOrientation:(UIImage *)aImage {
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}
#pragma clang diagnostic pop

@end



