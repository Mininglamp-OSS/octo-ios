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
#import <objc/runtime.h>

@implementation WKImageView

// 实例状态：cell 通过 wk_setDisplayed: 告诉它"在不在 visible 区"。
// 用关联对象避免在 .h 暴露 private property。
static const void *kWKDisplayedKey = &kWKDisplayedKey;

- (BOOL)wk_displayed {
    return [objc_getAssociatedObject(self, kWKDisplayedKey) boolValue];
}

- (void)setWk_displayed:(BOOL)displayed {
    objc_setAssociatedObject(self, kWKDisplayedKey, @(displayed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)wk_setDisplayed:(BOOL)displayed {
    self.wk_displayed = displayed;
    if (displayed) {
        // image 已加载且是动图 → startAnimating 真正启动；
        // image 还没到 / 不是动图 → no-op；image 后续到达时 setImage 会再判一次
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

// 关键：setImage 重写。
// 异步加载场景下：onWillDisplay 先 fire（wk_displayed = YES），SDWebImage 后续才 setImage。
// 此时如果不主动 startAnimating，autoPlay=NO 导致动图永远静止（修复 issue 2）。
- (void)setImage:(UIImage *)image {
    [super setImage:image];
    if (self.wk_displayed && [image isKindOfClass:[SDAnimatedImage class]]) {
        [self startAnimating];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) { [self wk_commonInit]; }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) { [self wk_commonInit]; }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image {
    self = [super initWithImage:image];
    if (self) { [self wk_commonInit]; }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) { [self wk_commonInit]; }
    return self;
}

- (void)wk_commonInit {
    // 默认 autoPlayAnimatedImage=YES（SDAnimatedImageView 原行为）。
    // 仅聊天列表的 cell（WKMessageCell.avatarImgView / WKImageMessageCell.imgView）
    // 在自己 init 里显式关掉 autoPlay 并配合 wk_setDisplayed 控制可见性。
    // 这样会话列表、个人中心等其他页面的 WKImageView 行为完全不受影响。
    [self wk_setupAnimatedPlaybackCompensation];
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
