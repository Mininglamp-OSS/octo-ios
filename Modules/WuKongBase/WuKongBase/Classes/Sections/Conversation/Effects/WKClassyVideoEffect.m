//
//  WKClassyVideoEffect.m
//  WuKongBase
//

#import "WKClassyVideoEffect.h"
#import "WKLumaKeyVideoView.h"
#import "WKMessageEffectView.h"

@implementation WKClassyVideoEffect

// 资源文件名（HEVC hvc1 / 720x1280 / 5.07s / ~573KB，放在 WuKongBase/Assets/Other/）
static NSString * const kClassyVideoName = @"classy_celebrate";
static NSString * const kClassyVideoExt  = @"mp4";

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
    // view frame 按视频原比例(9:16)摆，宽度 = effectView 宽（即屏宽）。
    // 这样 view 比例与视频帧比例完全一致，WKLumaKeyVideoView 内部 aspect-fill
    // 退化成 1:1 映射，左右两边不再被裁；高度按比例算后居中（iPhone 上上下会留透明边）。
    static const CGFloat kVideoAspect = 720.0 / 1280.0;  // = 0.5625
    CGFloat w = CGRectGetWidth(effectView.bounds);
    CGFloat h = w / kVideoAspect;
    CGFloat y = (CGRectGetHeight(effectView.bounds) - h) * 0.5;
    videoView.frame = CGRectMake(0, y, w, h);
    videoView.alpha = 0.0;
    // 黑底视频，直接复用 Dark 模式（默认）+ action_celebrate 同款参数：
    // 主体（黄脸/蓝紫电路/酒杯/"有品位"文字 luma 0.25~0.75）远超过阈值，完整保留；
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

    // 兜底：视频 ~5.07s + 余量
    [effectView scheduleRemovalAfterDelay:8.0];
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
