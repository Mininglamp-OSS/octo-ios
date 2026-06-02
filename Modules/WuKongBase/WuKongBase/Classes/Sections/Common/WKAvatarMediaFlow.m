//
//  WKAvatarMediaFlow.m
//  WuKongBase
//

#import "WKAvatarMediaFlow.h"
#import <AVFoundation/AVFoundation.h>
#import "WuKongBase.h"
#import "WKPhotoService.h"
#import "WKVideoTrimmerVC.h"
#import "WKVideoToGIFConverter.h"
#import "WKAnimatedAvatarPreviewVC.h"
#import "WKAvatarLimits.h"
#import "UIImage+Compression.h"
#import "NSData+ImageFormat.h"
#import "UIView+WKCommon.h"
#import "WKApp.h"

@implementation WKAvatarMediaFlow

+ (void)pickAvatarFromLibraryWithHost:(UIViewController *)host
                           onAnimated:(void (^)(NSData *))onAnimated
                       onStaticPicked:(void (^)(UIImage *))onStaticPicked {
    [[WKPhotoService shared] getAvatarMediaFromLibrary:^(NSData * _Nullable imageData,
                                                          NSURL * _Nullable videoURL,
                                                          BOOL isAnimated) {
        if (videoURL) {
            [self handleVideo:videoURL host:host
                   onAnimated:onAnimated
               onStaticPicked:onStaticPicked];
            return;
        }
        if (imageData && isAnimated) {
            [self handleAnimatedImage:imageData host:host
                           onAnimated:onAnimated
                       onStaticPicked:onStaticPicked];
            return;
        }
        if (imageData) {
            UIImage *img = [UIImage imageWithData:imageData];
            if (img && onStaticPicked) {
                onStaticPicked(img);
            }
            return;
        }
        // 用户取消，不做事
    }];
}

#pragma mark - 视频分支

+ (void)handleVideo:(NSURL *)url
               host:(UIViewController *)host
         onAnimated:(void (^)(NSData *))onAnimated
     onStaticPicked:(void (^)(UIImage *))onStaticPicked {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSTimeInterval total = CMTimeGetSeconds(asset.duration);

    if (total + 0.05 < WK_AVATAR_VIDEO_MIN_SEC) {
        NSString *msg = [NSString stringWithFormat:LLang(@"视频需不少于 %.0f 秒"),
                         (double)WK_AVATAR_VIDEO_MIN_SEC];
        [host.view showHUDWithHide:msg];
        return;
    }

    // 视频时长 ≤ 输出上限：跳过 trimmer，整段直接转，输出 GIF 时长 = 视频时长
    if (total <= WK_AVATAR_VIDEO_OUTPUT_MAX_SEC + 0.05) {
        [self convertVideo:url
                 startTime:kCMTimeZero
            outputDuration:CMTimeMakeWithSeconds(total, 600)
                      host:host
                onAnimated:onAnimated
            onStaticPicked:onStaticPicked];
        return;
    }

    // 视频时长 > 输出上限：进 trimmer，窗口宽度 = 输出上限
    WKVideoTrimmerVC *trimmer =
        [[WKVideoTrimmerVC alloc] initWithVideoURL:url
                                    windowDuration:WK_AVATAR_VIDEO_OUTPUT_MAX_SEC
                                         onConfirm:^(CMTime startTime) {
            [self convertVideo:url
                     startTime:startTime
                outputDuration:CMTimeMakeWithSeconds(WK_AVATAR_VIDEO_OUTPUT_MAX_SEC, 600)
                          host:host
                    onAnimated:onAnimated
                onStaticPicked:onStaticPicked];
        } onCancel:^{
        }];
    [host.navigationController pushViewController:trimmer animated:YES];
}

+ (void)convertVideo:(NSURL *)url
           startTime:(CMTime)startTime
      outputDuration:(CMTime)duration
                host:(UIViewController *)host
          onAnimated:(void (^)(NSData *))onAnimated
      onStaticPicked:(void (^)(UIImage *))onStaticPicked {
    [host.view showHUD:LLang(@"正在生成动图…")];

    [WKVideoToGIFConverter convertVideoAtURL:url
                                    fromTime:startTime
                                    duration:duration
                                    maxBytes:WK_AVATAR_ANIMATED_MAX_BYTES
                                  completion:^(NSData * _Nullable gifData, NSError * _Nullable error) {
        [host.view hideHud];
        if (error || gifData.length == 0) {
            NSString *msg = error.localizedDescription
                ?: LLang(@"无法生成动图，请重新选择");
            [host.view showHUDWithHide:msg];
            return;
        }
        [self showPreviewWithGIF:gifData host:host
                      onAnimated:onAnimated
                  onStaticPicked:onStaticPicked];
    }];
}

#pragma mark - 动图字节分支

+ (void)handleAnimatedImage:(NSData *)data
                       host:(UIViewController *)host
                 onAnimated:(void (^)(NSData *))onAnimated
             onStaticPicked:(void (^)(UIImage *))onStaticPicked {
    if (data.length <= WK_AVATAR_ANIMATED_MAX_BYTES) {
        [self showPreviewWithGIF:data host:host
                      onAnimated:onAnimated
                  onStaticPicked:onStaticPicked];
        return;
    }

    if ([NSData jl_imageFormatWithImageData:data] != JLImageFormatGIF) {
        NSString *msg = [NSString stringWithFormat:LLang(@"动图过大（最大 %.0f MB）"),
                         (double)WK_AVATAR_ANIMATED_MAX_BYTES / 1024.0 / 1024.0];
        [host.view showHUDWithHide:msg];
        return;
    }

    [host.view showHUD:LLang(@"压缩中…")];
    UIImage *placeholder = [UIImage imageWithData:data];
    CGSize origSize = placeholder.size;
    [UIImage jl_compressWithImageGIF:data
                          targetSize:origSize
                          targetByte:WK_AVATAR_ANIMATED_MAX_BYTES
                             handler:^(NSData * _Nullable compressedData,
                                       CGSize gifImageSize,
                                       NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [host.view hideHud];
            if (error || compressedData.length == 0 ||
                compressedData.length > WK_AVATAR_ANIMATED_MAX_BYTES) {
                NSString *msg = [NSString stringWithFormat:LLang(@"动图过大（最大 %.0f MB）"),
                                 (double)WK_AVATAR_ANIMATED_MAX_BYTES / 1024.0 / 1024.0];
                [host.view showHUDWithHide:msg];
                return;
            }
            [self showPreviewWithGIF:compressedData host:host
                          onAnimated:onAnimated
                      onStaticPicked:onStaticPicked];
        });
    }];
}

#pragma mark - 预览

+ (void)showPreviewWithGIF:(NSData *)data
                      host:(UIViewController *)host
                onAnimated:(void (^)(NSData *))onAnimated
            onStaticPicked:(void (^)(UIImage *))onStaticPicked {
    WKAnimatedAvatarPreviewVC *preview =
        [[WKAnimatedAvatarPreviewVC alloc] initWithGIFData:data
                                                  onConfirm:^(NSData *gifData) {
            if (onAnimated) onAnimated(gifData);
        } onRetake:^{
            [self pickAvatarFromLibraryWithHost:host
                                     onAnimated:onAnimated
                                 onStaticPicked:onStaticPicked];
        }];
    [host.navigationController pushViewController:preview animated:YES];
}

@end
