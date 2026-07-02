//
//  WKChannelHistoryStreamingVideoData.m
//

#import "WKChannelHistoryStreamingVideoData.h"
#import "WKChannelHistoryStreamingVideoCell.h"
#import "WKChannelHistoryFileDownloader.h"
#import "WuKongBase.h"
#import <Photos/Photos.h>
#import <YBImageBrowser/YBIBPhotoAlbumManager.h>
#import <YBImageBrowser/YBIBCopywriter.h>

@implementation WKChannelHistoryStreamingVideoData

@synthesize yb_isHideTransitioning = _yb_isHideTransitioning;
@synthesize yb_currentOrientation = _yb_currentOrientation;
@synthesize yb_containerSize = _yb_containerSize;
@synthesize yb_containerView = _yb_containerView;
@synthesize yb_auxiliaryViewHandler = _yb_auxiliaryViewHandler;
@synthesize yb_webImageMediator = _yb_webImageMediator;
@synthesize yb_backView = _yb_backView;

- (Class)yb_classOfCell {
    return WKChannelHistoryStreamingVideoCell.class;
}

- (BOOL)yb_allowSaveToPhotoAlbum {
    return YES;
}

/// 保存到相册:
///   1) videoURL 是本地 file:// 且文件存在 → 直接调 UISaveVideoAtPathToSavedPhotosAlbum
///   2) 否则先走 WKChannelHistoryFileDownloader 拉一份到 tmp, 再保存
- (void)yb_saveToPhotoAlbum {
    __weak typeof(self) ws = self;
    [YBIBPhotoAlbumManager getPhotoAlbumAuthorizationSuccess:^{
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        NSString *localPath = ss.videoURL.isFileURL ? ss.videoURL.path : nil;
        if (localPath.length > 0
            && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
            [ss saveLocalPathToAlbum:localPath];
            return;
        }
        NSString *src = ss.remoteURLString.length > 0 ? ss.remoteURLString : ss.videoURL.absoluteString;
        if (src.length == 0) return;
        UIView *container = ss.yb_containerView;
        id<YBIBAuxiliaryViewHandler> aux = ss.yb_auxiliaryViewHandler ? ss.yb_auxiliaryViewHandler() : nil;
        [aux yb_showLoadingWithContainer:container progress:0];
        [WKChannelHistoryFileDownloader
            downloadRemoteUrl:src
                     fileName:ss.fileName
                       onProgress:^(double progress) {
            [aux yb_showLoadingWithContainer:container progress:(CGFloat)progress];
        }
                     onComplete:^(NSURL *localURL, NSError *error) {
            [aux yb_hideLoadingWithContainer:container];
            if (error || localURL.path.length == 0) {
                [aux yb_showIncorrectToastWithContainer:container text:LLang(@"保存视频失败")];
                return;
            }
            [ss saveLocalPathToAlbum:localURL.path];
        }];
    } failed:^{
        __strong typeof(ws) ss = ws;
        id<YBIBAuxiliaryViewHandler> aux = ss.yb_auxiliaryViewHandler ? ss.yb_auxiliaryViewHandler() : nil;
        [aux yb_showIncorrectToastWithContainer:ss.yb_containerView
                                            text:[YBIBCopywriter sharedCopywriter].getPhotoAlbumAuthorizationFailed];
    }];
}

- (void)saveLocalPathToAlbum:(NSString *)path {
    if (!UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
        id<YBIBAuxiliaryViewHandler> aux = self.yb_auxiliaryViewHandler ? self.yb_auxiliaryViewHandler() : nil;
        [aux yb_showIncorrectToastWithContainer:self.yb_containerView text:LLang(@"保存视频失败")];
        return;
    }
    UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(savedVideo:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)savedVideo:(NSString *)path
    didFinishSavingWithError:(NSError *)error
    contextInfo:(void *)contextInfo {
    id<YBIBAuxiliaryViewHandler> aux = self.yb_auxiliaryViewHandler ? self.yb_auxiliaryViewHandler() : nil;
    if (error) {
        [aux yb_showIncorrectToastWithContainer:self.yb_containerView text:LLang(@"保存视频失败")];
    } else {
        [aux yb_showCorrectToastWithContainer:self.yb_containerView text:LLang(@"保存视频成功")];
    }
}

@end
