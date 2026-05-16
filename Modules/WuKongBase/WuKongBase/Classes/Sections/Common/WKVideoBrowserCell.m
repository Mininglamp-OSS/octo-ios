//
//  WKVideoBrowserCell.m
//  WuKongSmallVideo
//
//  Created by tt on 2020/4/30.
//

#import "WKVideoBrowserCell.h"
#import "WKVideoBrowserData.h"
#import <WuKongBase/UIImage+WK.h>
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKLoadProgressView.h>
#import <AVFoundation/AVFoundation.h>
#import "UIImage+WK.h"
@interface WKVideoBrowserCell ()

@property(nonatomic,strong) UIImageView *coverImgView;
@property(nonatomic,strong) WKLoadProgressView *progressView;
// player
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;

@property(nonatomic,strong) WKMessageFileDownloadTask *dowloadTask; // 下载任务


@end

@implementation WKVideoBrowserCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.coverImgView];
        [self.contentView addSubview:self.progressView];
    }
    return self;
}

- (void)prepareForReuse {
    if(self.player) {
        [self.player pause];
        self.player = nil;
    }
    if(self.playerLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
      name:AVPlayerItemDidPlayToEndTimeNotification
    object:nil];
    [super prepareForReuse];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.progressView.frame = self.bounds;
    
}

#pragma mark - <YBIBCellProtocol>

@synthesize yb_cellData = _yb_cellData;
@synthesize yb_hideBrowser = _yb_hideBrowser;

- (void)setYb_cellData:(id<YBIBDataProtocol>)yb_cellData {
    __weak typeof(self) weakSelf = self;
    
    _yb_cellData = yb_cellData;
    WKVideoBrowserData *videoData = (WKVideoBrowserData*)yb_cellData;
    __weak typeof(videoData) weakSelfVideoData = videoData;
    if(videoData.coverImage) {
        self.coverImgView.image = videoData.coverImage;
        
        self.coverImgView.lim_size =  [self calCoverSize:videoData.coverImage];
        self.coverImgView.lim_centerY_parent = self;
        self.coverImgView.lim_centerX_parent = self;
    }
    videoData.progress = ^(CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.progressView setProgress:progress];
        });
        
    };
    videoData.download(^(NSString * _Nonnull videoPath,NSError *error) {
        if(!error) {
            weakSelf.progressView.hidden = YES;
            weakSelfVideoData.videoPath = videoPath;
            [weakSelf playVideo:videoPath];
        }
       
    });
    
}

-(CGSize) calCoverSize:(UIImage*)img {
    CGSize imgSize  = img.size;
    CGFloat scale = 1;
    CGFloat  scaleHeight = WKScreenHeight/imgSize.height;
    CGFloat  scaleWidth = WKScreenWidth/imgSize.width;
    BOOL widthScale = false; // 是否按照宽的比率缩放
    widthScale = imgSize.height<=imgSize.width;
    
    if(widthScale) {
        CGFloat width = imgSize.width * scaleWidth;
        CGFloat height = imgSize.height * scaleWidth;
        if(height>WKScreenHeight) {
             width = imgSize.width * scaleHeight;
             height = imgSize.height * scaleHeight;
            return CGSizeMake(width, height);
        }
        return CGSizeMake(width, height);
    }else{
        CGFloat width = imgSize.width * scaleHeight;
        CGFloat height = imgSize.height * scaleHeight;
        if(width>WKScreenWidth) {
             width = imgSize.width * scaleWidth;
             height = imgSize.height * scaleWidth;
            return CGSizeMake(width, height);
        }
        return CGSizeMake(width, height);
    }
    
}

-(void) playVideo:(NSString*)videoURL {
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@",videoURL]]];
    self.player = [[AVPlayer alloc] initWithPlayerItem:item];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = CGRectMake(0, 0, WKScreenWidth, WKScreenHeight);
    self.playerLayer.position = self.contentView.center;
    [self.contentView.layer addSublayer:self.playerLayer];
    [self.playerLayer setNeedsDisplay];
    [self.player play];
    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
        object:nil
         queue:nil
    usingBlock:^(NSNotification *note) {
          [weakSelf.player seekToTime:kCMTimeZero];
          [weakSelf.player play];
    }];
    // 移除封面图
    [self.coverImgView removeFromSuperview];
}

-(void) dealloc {
    if(self.dowloadTask) {
        [self.dowloadTask removeListener:self];
    }
    if(self.player) {
        [self.player pause];
        self.player = nil;
    }
    if(self.playerLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
      name:AVPlayerItemDidPlayToEndTimeNotification
    object:nil];
}

#pragma mark - touch

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
//    self.yb_hideBrowser();
}



- (UIImageView *)coverImgView {
    if(!_coverImgView) {
        _coverImgView = [[UIImageView alloc] init];
    }
    return _coverImgView;
}
-(WKLoadProgressView*) progressView {
    if(!_progressView) {
        _progressView = [[WKLoadProgressView alloc] initWithFrame:CGRectMake(18, 0, 44, 44)];
        _progressView.maxProgress = 1.0f;
        _progressView.hidden = NO;
        _progressView.backgroundColor =
        [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:0.7];
    }
    return _progressView;
}

@end
