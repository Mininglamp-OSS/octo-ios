//
//  WKVideoBrowserData.m
//  WuKongSmallVideo
//
//  Created by tt on 2020/4/30.
//

#import "WKVideoBrowserData.h"
#import "WKVideoBrowserCell.h"
#import <YBImageBrowser/YBIBPhotoAlbumManager.h>
#import <YBImageBrowser/YBIBCopywriter.h>

@implementation WKVideoBrowserData

@synthesize yb_isHideTransitioning = _yb_isHideTransitioning;
@synthesize yb_currentOrientation = _yb_currentOrientation;
@synthesize yb_containerSize = _yb_containerSize;
@synthesize yb_containerView = _yb_containerView;
@synthesize yb_auxiliaryViewHandler = _yb_auxiliaryViewHandler;
@synthesize yb_webImageMediator = _yb_webImageMediator;
@synthesize yb_backView = _yb_backView;

- (Class)yb_classOfCell {
    return WKVideoBrowserCell.self;
}

- (BOOL)yb_allowSaveToPhotoAlbum {
    return  true;
}

- (void)yb_saveToPhotoAlbum {
    [YBIBPhotoAlbumManager getPhotoAlbumAuthorizationSuccess:^{
        BOOL compatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.videoPath);
        if (compatible){
            //保存相册核心代码
            UISaveVideoAtPathToSavedPhotosAlbum(self.videoPath, self, @selector(savedPhotoVideo:didFinishSavingWithError:contextInfo:), nil);
        }
    } failed:^{
        [self.yb_auxiliaryViewHandler() yb_showIncorrectToastWithContainer:self.yb_containerView text:[YBIBCopywriter sharedCopywriter].getPhotoAlbumAuthorizationFailed];
    }];
}
//保存视频完成之后的回调
- (void) savedPhotoVideo:(NSData*)data didFinishSavingWithError: (NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        [self.yb_auxiliaryViewHandler() yb_showIncorrectToastWithContainer:self.yb_containerView text:LLang(@"保存视频失败")];
    } else {
        [self.yb_auxiliaryViewHandler() yb_showCorrectToastWithContainer:self.yb_containerView text:LLang(@"保存视频成功")];
    }
}
@end
