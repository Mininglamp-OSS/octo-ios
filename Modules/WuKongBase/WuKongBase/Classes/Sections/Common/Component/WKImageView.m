//
//  WKImageView.m
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import "WKImageView.h"
#import <SDWebImage/SDWebImage.h>
#import "WKResource.h"
#import "WKApp.h"
#import "UIImageView+WK.h"
#import "WKDisplayLinkCalibration.h"

@implementation WKImageView

- (instancetype)init {
    self = [super init];
    if (self) { [self wk_setupAnimatedPlaybackCompensation]; }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self wk_setupAnimatedPlaybackCompensation]; }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image {
    self = [super initWithImage:image];
    if (self) { [self wk_setupAnimatedPlaybackCompensation]; }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) { [self wk_setupAnimatedPlaybackCompensation]; }
    return self;
}

// SDAnimatedImagePlayer 在某些 iOS 版本上读 CADisplayLink.frameInterval 拿到
// 非 1 的值（实测 iOS 18 上是 4），导致每帧时间累加被放大 4 倍，整个动图播放
// 比 GIF 内置 delay 期望值快约 4 倍。这里在 init 把 playbackRate 设成倒数
// 来抵消。详见 WKDisplayLinkCalibration.h 注释。
- (void)wk_setupAnimatedPlaybackCompensation {
    self.playbackRate = [WKDisplayLinkCalibration playbackRateCompensation];
}

-(void) loadImage:(NSURL*)url placeholderImage:(UIImage*)placeholderImage{
    [self lim_setImageWithURL:url placeholderImage:placeholderImage];

}

-(void) loadImage:(NSURL*)url{
    UIImage *placeholdeImg =   [WKApp.shared loadImage:@"Common/Index/Placeholder" moduleID:@"WuKongBase"];

    [self lim_setImageWithURL:url placeholderImage:placeholdeImg];
}
@end
