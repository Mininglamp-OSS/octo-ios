//
//  WKPhotoBrowser.m
//  WuKongBase
//
//  Created by tt on 2022/3/21.
//

#import "WKPhotoBrowser.h"
#import "NSData+ImageFormat.h"
#import "UIImage+Compression.h"
#import "WKApp.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/PHAsset.h>
#import "WKFileLocationHelper.h"
#import "WKNavigationManager.h"
#import "WuKongBase.h"
#import <ZLPhotoBrowser/ZLPhotoBrowser-Swift.h>

@implementation WKPhotoBrowser

static WKPhotoBrowser *_instance;


+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKPhotoBrowser *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(void) showPreviewWithSender:(UIViewController*)vc selectImageBlock:(void(^)(NSArray<UIImage *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock{
    ZLPhotoPreviewSheet *ps = [[ZLPhotoPreviewSheet alloc] initWithSelectedAssets:@[]];
    ps.selectImageBlock = ^(NSArray<ZLResultModel *> * _Nonnull results, BOOL isOriginal) {
        NSMutableArray<UIImage*> *images = [NSMutableArray array];
        NSMutableArray<PHAsset*> *assets = [NSMutableArray array];
        if(results && results.count>0) {
            for (ZLResultModel *result in results) {
                [images addObject:result.image];
                [assets addObject:result.asset];
            }
        }
        if(selectImageBlock) {
            selectImageBlock(images,assets,isOriginal);
        }
    };
    [ps showPreviewWithAnimate:YES sender:vc];
}

-(void) showPreviewWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock allowSelectVideo:(BOOL)allowSelectVideo{
    [ZLPhotoConfiguration default].saveNewImageAfterEdit = NO;
    [ZLPhotoConfiguration default].maxSelectCount = 9;
    [self showWithSender:vc selectCompressImageBlock:selectImageBlock allowSelectVideo:allowSelectVideo preview:YES];
    
}

-(void) showPhotoLibraryWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock allowSelectVideo:(BOOL)allowSelectVideo {
    [self showPhotoLibraryWithSender:vc selectCompressImageBlock:selectImageBlock maxSelectCount:1 allowSelectVideo:allowSelectVideo];
}

-(void) showPhotoLibraryWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock maxSelectCount:(NSInteger)maxCount allowSelectVideo:(BOOL)allowSelectVideo {
    [ZLPhotoConfiguration default].saveNewImageAfterEdit = NO;
    [ZLPhotoConfiguration default].maxSelectCount = maxCount;
    [self showWithSender:vc selectCompressImageBlock:selectImageBlock allowSelectVideo:allowSelectVideo preview:NO];
}


-(void) showWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock allowSelectVideo:(BOOL)allowSelectVideo preview:(BOOL)preview{
    [ZLPhotoConfiguration default].allowSelectVideo = allowSelectVideo;
    ZLPhotoPreviewSheet *ps = [[ZLPhotoPreviewSheet alloc] initWithSelectedAssets:@[]];
    ps.selectImageBlock = ^(NSArray<ZLResultModel *> *results, BOOL isOriginal) {
        NSMutableArray<UIImage*> *images = [NSMutableArray array];
        NSMutableArray<PHAsset*> *assets = [NSMutableArray array];
        if(results && results.count>0) {
            for (ZLResultModel *result in results) {
                [images addObject:result.image];
                [assets addObject:result.asset];
            }
        }
        if(selectImageBlock) {
            NSMutableArray<NSData*> *imageDatas = [NSMutableArray array];
            __block NSInteger selectRetain = 0;
            if(images && images.count>0) {
                selectRetain = images.count;
                for (UIImage *img in images) {
                    SDImageFormat sdimageFormat = [img sd_imageFormat];
                    
                    NSData *imgData = [img sd_imageDataAsFormat:sdimageFormat compressionQuality:1.0f];
//                    NSData *imgData = UIImagePNGRepresentation(img);
                    JLImageFormat format = [NSData jl_imageFormatWithImageData: imgData];
                    if(format == JLImageFormatGIF) {
                        [UIImage jl_compressWithImageGIF:imgData targetSize:img.size targetByte:[WKApp shared].config.imageMaxLimitBytes handler:^(NSData * _Nullable compressedData, CGSize gifImageSize, NSError * _Nullable error) {
                            selectRetain--;
                            if(compressedData) {
                                [imageDatas addObject:compressedData];
                            } else { // 压缩失败 只能将原图发出去
                                WKLogWarn(@"压缩失败，将原图发出去！");
                                [imageDatas addObject:imgData];
                            }
                            if(selectRetain <= 0) {
                                selectImageBlock(imageDatas,assets,isOriginal);
                                return;
                            }
                        }];
                    }else {
                        selectRetain--;
                        NSData *imgCompressData  = [UIImage jl_compressImageSize:img toByte:[WKApp shared].config.imageMaxLimitBytes];
                        if(imgCompressData) {
                            [imageDatas addObject:imgCompressData];
                        }
                        if(selectRetain <= 0) {
                            selectImageBlock(imageDatas,assets,isOriginal);
                            return;
                        }
                    }
                }
            }
            if(selectRetain <= 0) {
                selectImageBlock(imageDatas,assets,isOriginal);
            }
           
        }
    };
    if(preview) {
        [ps showPreviewWithAnimate:YES sender:vc];
    }else{
        [ps showPhotoLibraryWithSender:vc];
    }
    
}

+(void) fetchAssetFilePathWithAsset:(PHAsset*)asset completion:(void(^)(NSString* filePath))completion {
    if(asset.mediaType == PHAssetMediaTypeVideo) {
        [ZLPhotoManager fetchAVAssetForVideo:asset completion:^(AVAsset * avasset, NSDictionary * infoDict) {
            NSString *outputFileName = [WKFileLocationHelper genFilenameWithExt:@"mp4"];
            NSString *outputPath = [WKFileLocationHelper filepathForTempDir:@"video_temp" filename:outputFileName];
            
            
            AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:avasset
                                                                             presetName:AVAssetExportPresetMediumQuality];
            session.outputURL = [NSURL fileURLWithPath:outputPath];
            session.outputFileType = AVFileTypeMPEG4;   // 支持安卓某些机器的视频播放
            session.shouldOptimizeForNetworkUse = YES;
            session.videoComposition = [WKPhotoBrowser getVideoComposition:avasset];  //修正某些播放器不识别视频Rotation的问题
            [session exportAsynchronouslyWithCompletionHandler:^(void) {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (session.status == AVAssetExportSessionStatusCompleted){
                         completion(session.outputURL.absoluteString);
                     } else {
                         completion(nil);
                     }
                 });
             }];
        }];
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            NSString *outputFileName = [WKFileLocationHelper genFilenameWithExt:@"mp4"];
//            NSString *outputPath = [WKFileLocationHelper filepathForVideo:outputFileName];
//
//
//            AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset
//                                                                             presetName:AVAssetExportPresetMediumQuality];
//            session.outputURL = [NSURL fileURLWithPath:outputPath];
//            session.outputFileType = AVFileTypeMPEG4;   // 支持安卓某些机器的视频播放
//            session.shouldOptimizeForNetworkUse = YES;
//            session.videoComposition = [weakSelf getVideoComposition:asset];  //修正某些播放器不识别视频Rotation的问题
//        });
    }else {
        [ZLPhotoManager fetchAssetFilePathFor:asset completion:^(NSString * _Nullable filepath) {
            completion(filepath);
        }];
    }
}

-(void) exportVideo:(NSURL*)videoURL completion:(void(^)(NSString* filePath))completion {
    NSString *outputFileName = [WKFileLocationHelper genFilenameWithExt:@"mp4"];
    NSString *outputPath = [WKFileLocationHelper filepathForTempDir:@"video_temp" filename:outputFileName];
    
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPreset1280x720];
    exportSession.outputURL = [NSURL fileURLWithPath:outputPath];
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse= YES;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exportSession.status == AVAssetExportSessionStatusCompleted){
                completion(exportSession.outputURL.absoluteString);
            } else {
                completion(nil);
            }
        });
    }];
}


-(void) showPreviewWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock {
    [self showPreviewWithSender:vc selectCompressImageBlock:selectImageBlock allowSelectVideo:YES];
    
}

-(void) takePhoto:(UIViewController*)vc doneBlock:(void(^)(UIImage *img,NSURL *url))doneBlock cancelBlock:(void(^)(void))cancelBlock{
//    [ZLPhotoConfiguration default].allowRecordVideo = YES;
    [ZLPhotoConfiguration default].allowSelectVideo = YES;
    ZLCustomCamera *customCamera = [[ZLCustomCamera alloc] init];
    [customCamera setTakeDoneBlock:^(UIImage * _Nullable image, NSURL * _Nullable url) {
        if(doneBlock) {
            if(url) {
                UIView *topView = [WKNavigationManager shared].topViewController.view;
                [topView showHUD:LLang(@"压缩中")];
                [self exportVideo:url completion:^(NSString * _Nonnull filePath) {
                    [topView hideHud];
                    doneBlock(image,[NSURL URLWithString:filePath]);
                }];
            }else {
                doneBlock(image,nil);
            }
           
        }
    }];
    [customCamera setCancelBlock:^{
        if(cancelBlock) {
            cancelBlock();
        }
    }];
    [vc showDetailViewController:customCamera sender:nil];
}

+ (AVMutableVideoComposition *)getVideoComposition:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    CGSize videoSize = videoTrack.naturalSize;
    BOOL isPortrait_ = [WKPhotoBrowser isVideoPortrait:asset];
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

+ (BOOL) isVideoPortrait:(AVAsset *)asset
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



@end
