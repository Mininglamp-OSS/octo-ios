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
#import "WKChatAnimatedImage.h"
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

// SDWebImage 解码动图时,默认 animatedImageClass = SDAnimatedImage,而 SDAnimatedImage
// 内部用 SDImageIOAnimatedCoder,每帧 CGImage 都是 IIOImageProvider-backed lazy 句柄。
// 把它赋给 CALayer.contents 后,CA::Transaction::commit 会反向走回 ImageIO 现场跑
// LZW (GIF) / 解 APNG / WebP ——主线程被持续薅。
//
// 这里在 WKImageView 这一层 override,把 SDWebImageContextAnimatedImageClass 替换成
// WKChatAnimatedImage —— 子类 override 了 animatedImageFrameAtIndex:,把每帧重画到
// CGBitmapContext,layer.contents 拿到的全是真位图 backing,commit 阶段不再触发 IIO
// 现场解码。
//
// 关键: 不能调 [super sd_setImageWithURL:...]!
//   SDAnimatedImageView (WebCache) 的 funnel 实现里第一行就是
//     mutableContext[SDWebImageContextAnimatedImageClass] = [SDAnimatedImage class];
//   会把我们注入的 WKChatAnimatedImage 强行覆盖回 SDAnimatedImage —— 等于没做。
//   所以这里直接调 sd_internalSetImageWithURL: 进 SDWebImage 底层管线,跳过 super
//   的 funnel,保留我们的 class 注入。
//
// 不能加 SDWebImageMatchAnimatedImageClass:
//   带这个 flag 时, SDImageLoader 看到 [[WKChatAnimatedImage alloc] initWithData:]
//   返回 nil (静态 JPEG/HEIC 没有 SDAnimatedImageCoder 认领) 就直接 return nil,
//   不再走静态图 fallback —— 头像 / 缩略图 / 图片消息 URL 路径全部加载失败。
//   SDImageCache 也会把不属于子类的缓存条目 nil 掉,缓存里的静态图也失效。
//   动图缓存的 stale SDAnimatedImage 实例需要等 SD 内部 LRU 自然淘汰,或下次冷启
//   memory cache 被清空才会重解 —— 接受这个过渡期。
//
// 覆盖范围 (任何走 sd_setImageWithURL: / lim_setImageWithURL: 的 WKImageView):
//   - WKUserAvatar.avatarImgView        头像
//   - WKImageMessageCell.imgView        URL 路径的图片消息 (本地文件路径仍走
//                                       refresh: 内的 bg-decode + WKChatAnimatedImage)
//   - WKGIFMessageCell.imgView          动图消息
//   - WKStickerImageView.stickerImgView 贴纸 (WKImageView 的间接消费方)
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options
                   context:(nullable SDWebImageContext *)context
                  progress:(nullable SDImageLoaderProgressBlock)progressBlock
                 completed:(nullable SDExternalCompletionBlock)completedBlock {
    SDWebImageMutableContext *mutableContext = context ? [context mutableCopy] : [NSMutableDictionary dictionary];
    if (!mutableContext[SDWebImageContextAnimatedImageClass]) {
        mutableContext[SDWebImageContextAnimatedImageClass] = [WKChatAnimatedImage class];
    }
    [self sd_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
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
