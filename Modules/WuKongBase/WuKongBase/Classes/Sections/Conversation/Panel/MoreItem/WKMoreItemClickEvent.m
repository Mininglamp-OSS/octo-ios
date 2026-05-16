// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMoreItemClickEvent.m
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import "WKMoreItemClickEvent.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import "WKNavigationManager.h"
#import "WKMediaPickerController.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <SDWebImage/SDWebImage.h>
#import "WKApp.h"
#import "WKConstant.h"
#import "WuKongBase.h"
#import "NSData+ImageFormat.h"
#import "UIImage+Compression.h"
#import "WKPhotoBrowser.h"
#import <WuKongIMSDK/WKFileContent.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
@interface WKMoreItemClickEvent () <UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIDocumentPickerDelegate>
@property(strong,nonatomic)UIImagePickerController *pickerC;
@property(nonatomic,strong) WKMediaFetcher *mediaFetcher;
@property(nonatomic,strong) id<WKConversationContext> gloabContext;
@end

@implementation WKMoreItemClickEvent


static WKMoreItemClickEvent *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMoreItemClickEvent *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(void) onPhotoItemPressed:(id<WKConversationContext>)context {
    __weak typeof(self) weakSelf = self;
    __weak typeof(context) weakContext = context;
    

    
//    self.mediaFetcher =  [[WKMediaFetcher alloc] init];
//
//    if([[WKApp shared] hasMethod:WKPOINT_SEND_VIDEO]) {
//        self.mediaFetcher.mediaTypes = @[(NSString *)kUTTypeMovie,(NSString *)kUTTypeImage];
//    }else{
//        self.mediaFetcher.mediaTypes = @[(NSString *)kUTTypeImage];
//    }
//
//    [self.mediaFetcher fetchPhotoFromLibraryOfCompress:^(NSData *imageData, NSString *path, bool isSelectOriginalPhoto, PHAssetMediaType type, NSInteger left) {
//        if(left == 0) {
//            weakSelf.mediaFetcher = nil;
//        }
//        switch (type) {
//            case PHAssetMediaTypeImage:{
//                 UIImage *image = [[UIImage alloc] initWithData:imageData];
//                 [weakSelf  sendImageMessageOfData:imageData full:isSelectOriginalPhoto targetSize:image.size context:weakContext];
//                break;
//            }
//            case PHAssetMediaTypeVideo:{
//               UIImage *preVidewImage = [weakSelf getVideoPreViewImage:[NSURL fileURLWithPath:path]];
//                NSData *preData = UIImageJPEGRepresentation(preVidewImage, 0.8f);
//                NSData *videoData = [NSData dataWithContentsOfFile:path];
//                if(!preData || !videoData) {
//                    return;
//                }
//                [[WKApp shared] invoke:WKPOINT_SEND_VIDEO param:@{
//                    @"cover_data":preData,
//                    @"video_data":videoData,
//                    @"context": context,
//                }];
//                break;
//            }
//            case PHAssetMediaTypeAudio: {
//
//                break;
//            }
//            case PHAssetMediaTypeUnknown: {
//
//                break;
//            }
//        }
//    } cancel:^{
//        weakSelf.mediaFetcher = nil;
//    }];
//
//    return;
   
    
    [context endEditing];
    
    UIView *topView = [WKNavigationManager shared].topViewController.view;
   
    __block NSInteger handleCount = 0;
    [[WKPhotoBrowser shared] showPreviewWithSender:[context targetVC] selectCompressImageBlock:^(NSArray<NSData *> * _Nonnull images, NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal) {
        [topView showHUD:LLang(@"压缩中")];
        if(assets && assets.count>0) {
            handleCount = assets.count;
            for (NSInteger i=0; i<assets.count; i++) {
               PHAsset *phAsset = assets[i];
                if(phAsset.mediaType == PHAssetMediaTypeImage) {
                    handleCount--;
                    if(handleCount == 0) {
                        [topView hideHud];
                    }
                    NSData *imageData = images[i];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    [weakSelf  sendImageMessageOfData:imageData full:isOriginal targetSize:image.size context:weakContext];
                }else if(phAsset.mediaType == PHAssetMediaTypeVideo) {
                    [WKPhotoBrowser fetchAssetFilePathWithAsset:phAsset completion:^(NSString * _Nullable filePath) {
                        handleCount--;
                        if(handleCount == 0) {
                            [topView hideHud];
                        }
                        NSURL *videoURL = [NSURL URLWithString:filePath];
                        NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
                        UIImage *preVidewImage = [weakSelf getVideoPreViewImage:videoURL];
                        NSData *preData = UIImageJPEGRepresentation(preVidewImage, 0.8f);
                        if(!preData || !videoData) {
                            return;
                        }
                        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
                        if(!asset) {
                            return;
                        }
                        long long second = asset.duration.value/asset.duration.timescale;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[WKApp shared] invoke:WKPOINT_SEND_VIDEO param:@{
                                @"cover_data":preData,
                                @"video_data":videoData,
                                @"context": context,
                                @"second":@(second),
                            }];
                        });
                    }];
                }else {
                    handleCount--;
                    if(handleCount == 0) {
                        [topView hideHud];
                    }
                }
            }
        }
       
    } allowSelectVideo:[[WKApp shared] hasMethod:WKPOINT_SEND_VIDEO]];
   
}




// 获取视频第一帧
- (UIImage*) getVideoPreViewImage:(NSURL *)path
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:path options:nil];
    AVAssetImageGenerator *assetGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    assetGen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [assetGen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *videoImage = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return videoImage;
}


//full 是否是原图
-(void) sendImageMessage:(UIImage*)image full:(BOOL)full context:(id<WKConversationContext>)context {
    WKImageContent *imageMessageContent = [WKImageContent initWithImage:image];
    [context sendMessage:imageMessageContent];
    
}
//full 是否是原图
-(void) sendImageMessageOfData:(NSData*)data full:(BOOL)full targetSize:(CGSize)size context:(id<WKConversationContext>)context {
    WKImageContent *imageMessageContent = [WKImageContent initWithData:data width:size.width height:size.height];
    [context sendMessage:imageMessageContent];
    
}

-(void) onCameraIPressed:(id<WKConversationContext>)context {
    
    
    self.gloabContext = context;
    //显示拍照
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted)
     {
         dispatch_async(dispatch_get_main_queue(), ^{
             if(!granted){
                 NSString *cancelButtonTitle = LLang(@"取消");
                 NSString *otherButtonTitle = LLang(@"确认");
                 UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LLang(@"权限提醒") message:LLang(@"请在设置里打开图片读取权限！") preferredStyle:UIAlertControllerStyleAlert];
                 UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                     
                 }];
                 
                 UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                 }];
                 [alertController addAction:cancelAction];
                 [alertController addAction:otherAction];
                 return;
             }
             if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                 NSString *cancelButtonTitle = LLang(@"取消");
                 NSString *otherButtonTitle = LLang(@"确认");
                 UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LLang(@"权限提醒") message:LLang(@"请在设置里打开图片读取权限！") preferredStyle:UIAlertControllerStyleAlert];
                 UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                     
                 }];
                 
                 UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                 }];
                 [alertController addAction:cancelAction];
                 [alertController addAction:otherAction];
                 return;
             }
             if(self.pickerC) {
                 self.pickerC = nil;
             }
             self.pickerC = [[UIImagePickerController alloc] init];
             self.pickerC.sourceType = UIImagePickerControllerSourceTypeCamera;
             self.pickerC.delegate = self;
             [[[WKNavigationManager shared] topViewController] presentViewController:self.pickerC animated:YES completion:nil];
         });
     }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [[[WKNavigationManager shared] topViewController] dismissViewControllerAnimated:YES completion:nil];
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [self  sendImageMessage:img full:NO context:self.gloabContext];
    self.gloabContext = nil;
}

-(void) onFileItemPressed:(id<WKConversationContext>)context {
    self.gloabContext = context;
    [context endEditing];

    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem, UTTypeData, UTTypeContent]];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item", @"public.data", @"public.content"] inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [[WKNavigationManager shared].topViewController presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0 || !self.gloabContext) {
        self.gloabContext = nil;
        return;
    }
    NSURL *fileURL = urls.firstObject;

    // 获取安全访问权限
    BOOL accessing = [fileURL startAccessingSecurityScopedResource];

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];
    __block NSError *coordError = nil;
    __weak typeof(self) weakSelf = self;
    [coordinator coordinateReadingItemAtURL:fileURL options:0 error:&coordError byAccessor:^(NSURL *newURL) {
        // 将文件复制到临时目录
        NSString *tempDir = NSTemporaryDirectory();
        NSString *fileName = newURL.lastPathComponent;
        NSString *tempPath = [tempDir stringByAppendingPathComponent:fileName];
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:tempPath]) {
            [fm removeItemAtPath:tempPath error:nil];
        }
        NSError *copyError = nil;
        [fm copyItemAtURL:newURL toURL:[NSURL fileURLWithPath:tempPath] error:&copyError];
        if (copyError) {
            WKLogDebug(@"文件复制失败: %@", copyError);
            return;
        }

        NSURL *localURL = [NSURL fileURLWithPath:tempPath];
        WKFileContent *fileContent = [WKFileContent initWithFileURL:localURL];
        id<WKConversationContext> ctx = weakSelf.gloabContext;
        weakSelf.gloabContext = nil;
        if (ctx) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [ctx sendMessage:fileContent];
            });
        }
    }];

    if (accessing) {
        [fileURL stopAccessingSecurityScopedResource];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.gloabContext = nil;
}

@end
