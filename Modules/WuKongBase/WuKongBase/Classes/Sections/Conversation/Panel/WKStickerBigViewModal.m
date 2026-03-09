//
//  WKStickerBigViewModal.m
//  WuKongBase
//
//  Created by tt on 2021/10/20.
//

#import "WKStickerBigViewModal.h"
#import "WuKongBase.h"
#import <Lottie/Lottie.h>
#import <GZIP/GZIP.h>
@interface WKStickerBigViewModal ()

@property(nonatomic,strong) UIView *focusedView;
@property(nonatomic,strong) UIView *view;

@property(nonatomic,strong) UIImageView *animationView;

@property(nonatomic,strong) UIView *animationBoxView;


@property(nonatomic,strong) UIView *snapshotFocusedView;

@property(nonatomic,strong) WKSticker *sticker;

@end

@implementation WKStickerBigViewModal

+(WKStickerBigViewModal*) focusedView:(UIView*)focusedView sticker:(WKSticker*)sticker{
    WKStickerBigViewModal *modal = [WKStickerBigViewModal new];
    modal.focusedView = focusedView;
    modal.sticker = sticker;
    return modal;
}


-(void) presentOnWindow:(UIWindow*)window {
    if(self.view.superview!=nil) {
        return;
    }
    UIImpactFeedbackGenerator *feedBackGenertor = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedBackGenertor impactOccurred];
    
    [window addSubview:self.view];
    
    [window layoutIfNeeded];
    
  //  [self addSnapshotFocusedView];
    
    [self addSticker];
}

- (UIView *)view {
    if(!_view) {
        _view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
//        [_view setBackgroundColor:[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.4f]];
        _view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap)];
        [_view addGestureRecognizer:tapGesture];
    }
    return _view;
}

-(void) didTap {
    [self dismiss];
}
-(void) dismiss {
    [self.view removeFromSuperview];
}

-(void) addSnapshotFocusedView {
    [self.snapshotFocusedView removeFromSuperview];
    self.snapshotFocusedView = nil;
    
    UIView *snapshotView = [self.focusedView snapshotViewAfterScreenUpdates:true];
    [self.view addSubview:snapshotView];
    
    UIView *focusedViewSuperview = self.focusedView.superview;
    
   CGRect convertedFrame = [self.view convertRect:self.focusedView.frame fromView:focusedViewSuperview];
    snapshotView.frame = convertedFrame;
    snapshotView.userInteractionEnabled = false;

    self.snapshotFocusedView = snapshotView;
}

-(void) downSticker:(void(^)(NSString *jsonPath))compeletion {
    NSString *storePath = [NSString stringWithFormat:@"%@/%@_%@",[WKSDK shared].options.messageFileRootDir,self.sticker.category,[self.sticker.path lastPathComponent]];
    
    [WKFileUtil createDirectoryIfNotExist:[storePath stringByDeletingLastPathComponent]];
    
    NSString *jsonStorePath = [NSString stringWithFormat:@"%@.json",storePath];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:jsonStorePath]) {
        if(compeletion) {
            compeletion(jsonStorePath);
        }
    }else {
        NSURLSessionDownloadTask *task = [[WKAPIClient sharedClient] createDownloadTask:[[WKApp shared] getFileFullUrl:self.sticker.path].absoluteString storePath:storePath progress:^(NSProgress * _Nullable downloadProgress) {
            
        } completeCallback:^(NSError * _Nullable error) {
            if(error) {
                [[WKNavigationManager shared].topViewController.view showHUDWithHide:error.domain];
                return;
            }
            NSError *copyError;
            [[[NSData dataWithContentsOfFile:storePath] gunzippedData] writeToFile:jsonStorePath options:NSDataWritingAtomic error:&copyError];
            if(copyError) {
                WKLogError(@"复制sticker路径失败->%@",error);
                [[WKNavigationManager shared].topViewController.view showHUDWithHide:copyError.domain];
                return;
            }
            if(compeletion) {
                compeletion(jsonStorePath);
            }
           
        }];
        [task resume];
    }
}

-(void) addSticker {
    
    [self.view addSubview:self.animationBoxView];

    __weak typeof(self) weakSelf = self;
    [self downSticker:^(NSString *jsonPath) {
        [weakSelf setAnimationFromFilePath:jsonPath];
       
    }];
    
    UIView *focusedViewSuperview = self.focusedView.superview;
    CGRect convertedFrame = [self.view convertRect:weakSelf.focusedView.frame fromView:focusedViewSuperview];
    weakSelf.animationBoxView.lim_top = convertedFrame.origin.y - weakSelf.animationBoxView.lim_height;
    weakSelf.animationBoxView.lim_left = convertedFrame.origin.x + (weakSelf.focusedView.lim_width/2.0f - weakSelf.animationBoxView.lim_width/2.0f);
    
    if(weakSelf.animationBoxView.lim_left<0) {
        weakSelf.animationBoxView.lim_left = 0.0f;
    }
    if(weakSelf.animationBoxView.lim_right> WKScreenWidth) {
        weakSelf.animationBoxView.lim_left = WKScreenWidth - weakSelf.animationBoxView.lim_width;
    }
    
}

-(void) setAnimationFromFilePath:(NSString*)path {
    
    CGSize pixelSize = CGSizeMake(120.0f*2, 120.0f*2);
    [self.animationView lim_setImageWithURL:[NSURL fileURLWithPath:path] placeholderImage:nil options:SDWebImageRefreshCached context:@{
        SDWebImageContextImageThumbnailPixelSize:@(pixelSize),
    }];

    
//    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:path];
//    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//    [self.animationView setAnimationFromJSON:[WKJsonUtil toDic:jsonStr]];
}

- (UIImageView *)animationView {
    if(!_animationView) {
        _animationView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 120.0f, 120.0f)];
        _animationView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _animationView;
}

- (UIView *)animationBoxView {
    if(!_animationBoxView) {
        _animationBoxView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 140.0f, 140.0f)];
        [_animationBoxView addSubview:self.animationView];
        self.animationBoxView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        
        _animationBoxView.layer.shadowColor = [UIColor colorWithRed:0.0f/255.0f green:0.0f/255.0f blue:0.0f/255.0f alpha:0.4f].CGColor;
        _animationBoxView.layer.shadowOffset = CGSizeMake(-1, -1);
        _animationBoxView.layer.shadowOpacity = 0.6f;
        _animationBoxView.layer.cornerRadius = 8.0f;
        
        self.animationView.lim_centerX_parent = self.animationBoxView;
        self.animationView.lim_centerY_parent = self.animationBoxView;
        
    }
    return _animationBoxView;
}

@end
