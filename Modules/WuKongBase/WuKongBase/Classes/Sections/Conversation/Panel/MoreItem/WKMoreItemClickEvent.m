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
#import "WKInputMentionCache.h"
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
        // Phase 3：相册选图全为图片 → 直接塞入聊天页输入框上方的「待发送图片栏」（取代旧的全屏 caption 编辑页）。
        // 用户在主聊天 textView 内继续打字 / @ 人 / 删图 / + 加图，点发送时由 input panel
        // 内部按 [WKApp shouldAggregateAlbumImagesWithText:...] 决定走 RichText=14 聚合
        // 还是纯图路径。draft 不丢：textView 文本始终未被本路径触碰。
        // 含视频/其它（allImages=NO）：RichText=14 仅支持图文，走原逐条发送路径，零回归。
        BOOL allImages = assets.count > 0;
        for (PHAsset *a in assets) {
            if (a.mediaType != PHAssetMediaTypeImage) { allImages = NO; break; }
        }
        if (allImages) {
            // 与 sendAlbumImageDatas: 的原子性闸门保持一致 (WKMoreItemClickEvent.m:239)：
            // jl_compressImageSize 返回 nil 时 WKPhotoBrowser 会静默丢图, 导致
            // images.count < assets.count。bar 桥接路径若不查这条, 后续
            // _commitPendingWithCaption 用 images.count 当 assetCount, 原子性闸门形同虚设——
            // 用户选了 5 张, 静默发出 4 张。和直发路径对齐: 整条可见失败、不入 bar。
            if (images.count != assets.count) {
                dispatch_block_t showFail = ^{
                    [[WKNavigationManager shared].topViewController.view
                        showHUDWithHide:LLang(@"发送失败")];
                };
                if ([NSThread isMainThread]) { showFail(); }
                else { dispatch_async(dispatch_get_main_queue(), showFail); }
                return;
            }
            // 线程安全：selectCompressImageBlock 可能在 GIF 压缩后台线程触发，UIKit 操作必须主线程。
            dispatch_block_t pushIntoBar = ^{
                id<WKConversationContext> ctx = weakContext;
                if (!ctx) return;
                [ctx appendPendingImageDatas:images];
                [ctx inputBecomeFirstResponder];
            };
            if ([NSThread isMainThread]) {
                pushIntoBar();
            } else {
                dispatch_async(dispatch_get_main_queue(), pushIntoBar);
            }
            return;
        }

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

// Phase 2 纯图（无 caption）发送：caption 确认页里用户没写描述 → 逐张发已压缩图片，
// 与原相册单图发送同一路径（[context sendMessage:]），wire 与会话语义零回归。
// 原子性闸门（Jerry-Xin critical，与 captioned 路径 sendRichTextMixedImageDatas: 对称）：
// 压缩可能返回 nil/丢图，使 imageDatas.count < assetCount。此时绝不静默只发部分图——
// 整条可见失败（弹「发送失败」HUD），与 captioned 路径的 count==assetCount gate 一致。
//
// R10 fix (lml2468): 加 onFailure 回调。原子闸 / 空 NSData 兜底命中时发生在任何
// sendMessage: 之前 (没有 failed bubble 留在 chat), 调用方已同步清 bar → 不调
// onFailure 等于静默丢图。onFailure 与 HUD 同 dispatch_async block 内同步触发,
// 给调用方一个把 bar 恢复回去的入口, 不会与已 sendMessage 的 failed bubble 重复
// (那条路径走 IM SDK 的 retry, 不经过这里)。
-(void) sendAlbumImageDatas:(NSArray<NSData *> *)imageDatas assetCount:(NSUInteger)assetCount context:(id<WKConversationContext>)context {
    [self sendAlbumImageDatas:imageDatas assetCount:assetCount context:context onFailure:nil];
}

-(void) sendAlbumImageDatas:(NSArray<NSData *> *)imageDatas
                  assetCount:(NSUInteger)assetCount
                     context:(id<WKConversationContext>)context
                   onFailure:(void(^)(void))onFailure {
    if (context == nil) return;
    void (^failVisible)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送失败")];
            if (onFailure) onFailure();
        });
    };
    // 选了 N 张就必须发齐 N 张：数量不符或存在空数据 → 整条中止、可见失败，不部分发送。
    if (imageDatas.count == 0 || imageDatas.count != assetCount) {
        failVisible();
        return;
    }
    for (NSData *data in imageDatas) {
        if (data.length == 0) { failVisible(); return; }
    }
    for (NSData *data in imageDatas) {
        UIImage *image = [[UIImage alloc] initWithData:data];
        [self sendImageMessageOfData:data full:NO targetSize:image.size context:context];
    }
}

// 待发送图片栏「+」按钮：再次拉相册（全屏库；不走 sheet 预览，匹配微信加图体验），
// 不允许选视频，maxSelectCount=remaining；选完通过 appendBlock 回到 input panel。
-(void) addMorePendingImagesForContext:(id<WKConversationContext>)context
                             remaining:(NSInteger)remaining
                           appendBlock:(void(^)(NSArray<NSData *> *images))appendBlock {
    if (context == nil || appendBlock == nil) return;
    if (remaining <= 0) return;
    UIViewController *senderVC = [context targetVC];
    if (!senderVC) return;
    [[WKPhotoBrowser shared] showPhotoLibraryWithSender:senderVC
                               selectCompressImageBlock:^(NSArray<NSData *> * _Nonnull images,
                                                          NSArray<PHAsset *> * _Nonnull assets,
                                                          BOOL isOriginal) {
        // R7 fix (yujiawei P1): 与初次选图入口 (line 124-138) 同款原子性闸门。
        // WKPhotoBrowser 在 jl_compressImageSize 返回 nil 时会**静默丢图**, 导致
        // images.count < assets.count + 索引错位 (images[i] 与 assets[i] 不一定对应)。
        // 没这条闸的话, 用户「+」选 5 张, 1 张压缩失败 → bar 静默 append 4 张, 后续
        // _commitPendingWithCaption 用 images.count 当 assetCount, 原子闸形同虚设。
        // 与直发路径一致: 整条可见失败 + 不入 bar。
        if (images.count != assets.count) {
            dispatch_block_t showFail = ^{
                [[WKNavigationManager shared].topViewController.view
                    showHUDWithHide:LLang(@"发送失败")];
            };
            if ([NSThread isMainThread]) { showFail(); }
            else { dispatch_async(dispatch_get_main_queue(), showFail); }
            return;
        }
        // 防御：相册理论上已经按 maxSelectCount=remaining + allowSelectVideo=NO 过滤，但是
        // 兜底再校验一次：剔除非 image 资产对应的 NSData，再 clamp remaining。
        NSMutableArray<NSData *> *filtered = [NSMutableArray arrayWithCapacity:images.count];
        for (NSInteger i = 0; i < (NSInteger)images.count && i < (NSInteger)assets.count; i++) {
            PHAsset *a = assets[i];
            if (a.mediaType == PHAssetMediaTypeImage) {
                [filtered addObject:images[i]];
            }
        }
        NSUInteger take = MIN(filtered.count, (NSUInteger)remaining);
        NSArray<NSData *> *out = take > 0
            ? [filtered subarrayWithRange:NSMakeRange(0, take)]
            : @[];
        // selectCompressImageBlock 可能在压缩线程触发，UIKit 操作主线程 hop。
        if ([NSThread isMainThread]) {
            appendBlock(out);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ appendBlock(out); });
        }
    }
                                         maxSelectCount:remaining
                                       allowSelectVideo:NO];
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
