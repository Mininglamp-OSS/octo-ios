//
//  WKClassyVideoEffect.m
//  WuKongBase
//

#import "WKClassyVideoEffect.h"
#import "WKLumaKeyVideoView.h"
#import "WKMessageEffectView.h"

@implementation WKClassyVideoEffect

// 资源文件名（HEVC / 1764x3840 / ~2.4s，放在 WuKongBase/Assets/Other/）
static NSString * const kClassyVideoName = @"classy_celebrate";
static NSString * const kClassyVideoExt  = @"mp4";
// 视频宽高比 (width / height)：换素材时同步更新，否则 videoView 高度算错会拉伸抠像。
static const CGFloat kClassyVideoAspect = 1764.0 / 3840.0;

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    if (!effectView) return;
    (void)sourceRect;  // 居中悬浮，不依赖气泡位置

    NSURL *url = [self locateVideoURL];
    if (!url) {
#if DEBUG
        NSLog(@"[ClassyVideo] ❌ 找不到资源 %@.%@", kClassyVideoName, kClassyVideoExt);
#endif
        return;
    }

    static const NSTimeInterval kFadeIn = 0.45;
    static const NSTimeInterval kFadeOut = 0.6;

    WKLumaKeyVideoView *videoView = [[WKLumaKeyVideoView alloc] initWithVideoURL:url];
    // 宽度铺满屏幕、高度按视频比例等比、垂直居中。videoView 的宽高比 == 视频宽高比时，
    // WKLumaKeyVideoView 内部的 aspect-fill（MAX(w/sw,h/sh)）不再裁边也不留边，视频原样贴合。
    // 视频比屏更"高"时高度会溢出 effectView，被 effectView.clipsToBounds 裁掉（可接受，边缘本就是抠透明黑）。
    CGFloat vw = effectView.bounds.size.width;
    CGFloat vh = vw / kClassyVideoAspect;
    videoView.frame = CGRectMake(0,
                                 (effectView.bounds.size.height - vh) * 0.5,
                                 vw,
                                 vh);
    videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                               | UIViewAutoresizingFlexibleTopMargin
                               | UIViewAutoresizingFlexibleBottomMargin;
    videoView.alpha = 0.0;
    // 黑底视频，Dark 模式默认参数：
    // 主体（luma 0.25~0.75）远超过阈值完整保留；
    // 四角近纯黑 luma<0.005 完全透明，与背景一同消失。
    videoView.lumaThreshold = 0.10;
    videoView.lumaTolerance = 0.12;
    // 中心保护：脸 / 眼镜区里夹杂的深色细节不被误抠
    videoView.centerProtectRadius = 0.30;
    videoView.centerProtectSoftness = 0.14;
    // 背景半透明纱：暗部接近 floor，过渡区接近 ceil，保留主体周围漫散光晕的氛围
    videoView.backgroundAlphaFloor = 0.05;
    videoView.backgroundAlphaCeil = 0.45;
    [effectView addSubview:videoView];

    [UIView animateWithDuration:kFadeIn delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        videoView.alpha = 1.0;
    } completion:nil];

    __weak typeof(effectView) weakEffect = effectView;
    [videoView playWithCompletion:^{
        __strong typeof(weakEffect) strongEffect = weakEffect;
        [UIView animateWithDuration:kFadeOut delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            videoView.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (strongEffect) {
                [strongEffect scheduleRemovalAfterDelay:0.0];
            }
        }];
    }];

    // 兜底：视频 ~2.4s + fadeIn/fadeOut + 余量
    [effectView scheduleRemovalAfterDelay:4.5];
}

#pragma mark - 资源定位

+ (nullable NSURL *)locateVideoURL {
    NSBundle *mainBundle = [NSBundle bundleForClass:self];

    NSURL *url = [mainBundle URLForResource:kClassyVideoName withExtension:kClassyVideoExt];
    if (url) return url;
    url = [mainBundle URLForResource:kClassyVideoName withExtension:kClassyVideoExt subdirectory:@"Other"];
    if (url) return url;

    NSURL *resBundleURL = [mainBundle URLForResource:@"WuKongBase_resources" withExtension:@"bundle"];
    if (resBundleURL) {
        NSBundle *resBundle = [NSBundle bundleWithURL:resBundleURL];
        url = [resBundle URLForResource:kClassyVideoName withExtension:kClassyVideoExt subdirectory:@"Other"];
        if (url) return url;
        url = [resBundle URLForResource:kClassyVideoName withExtension:kClassyVideoExt];
        if (url) return url;
    }
    return nil;
}

@end
