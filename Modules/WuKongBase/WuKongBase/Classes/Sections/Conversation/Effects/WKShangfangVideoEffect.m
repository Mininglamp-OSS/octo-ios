//
//  WKShangfangVideoEffect.m
//  WuKongBase
//

#import "WKShangfangVideoEffect.h"
#import "WKLumaKeyVideoView.h"
#import "WKMessageEffectView.h"

@implementation WKShangfangVideoEffect

// 资源文件名（HEVC / 1764x3840 / ~3.5s，放在 WuKongBase/Assets/Other/）
static NSString * const kShangfangVideoName = @"shangfang_celebrate";
static NSString * const kShangfangVideoExt  = @"mp4";
// 视频宽高比 (width / height)：换素材时同步更新，否则 videoView 高度算错会拉伸抠像。
static const CGFloat kShangfangVideoAspect = 1764.0 / 3840.0;

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    if (!effectView) return;
    (void)sourceRect;  // 居中悬浮，不依赖气泡位置

    NSURL *url = [self locateVideoURL];
    if (!url) {
#if DEBUG
        NSLog(@"[ShangfangVideo] ❌ 找不到资源 %@.%@", kShangfangVideoName, kShangfangVideoExt);
#endif
        return;
    }

    static const NSTimeInterval kFadeIn = 0.45;
    static const NSTimeInterval kFadeOut = 0.6;

    WKLumaKeyVideoView *videoView = [[WKLumaKeyVideoView alloc] initWithVideoURL:url];
    // 宽度铺满屏幕、高度按视频比例等比、垂直居中（与 Classy 同款布局）。
    CGFloat vw = effectView.bounds.size.width;
    CGFloat vh = vw / kShangfangVideoAspect;
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
    // 保护区分两部分（见 WKLumaKeyVideoView 的 eyeProtect / centerProtectStartTime 说明）：
    //   1) 眼部小圈：全程常驻，只补住主体那两只与黑背景 luma 无法区分的深色眼睛/眉毛。
    //   2) 中心大盘（0.30）：延时到 600ms 后才淡入出现。
    //      早期（表情从左下甩剑入场、光环尚未铺满）若就用完整大盘，盘子会罩在尚未被亮部填满的
    //      空黑背景上，浅色模式下呈现为"浮在画面中间的黑圈"（就是最初反馈的问题）；
    //      600ms 后徽标定格、亮部/光环铺满，盘内黑色被主体盖住，边缘完整不残缺，也无孤立黑圈。
    // 中心盘半径/软度用回原始默认 0.30 / 0.12；两个圆心位置由帧实测（归一化，原点左上）。
    videoView.centerProtectRadius = 0.30;
    videoView.centerProtectSoftness = 0.12;
    videoView.centerProtectCenter = CGPointMake(0.54, 0.41);  // 大盘：徽标偏画面右上，X 0.54、Y 0.41
    videoView.eyeProtectCenter = CGPointMake(0.60, 0.42);
    videoView.eyeProtectRadius = 0.13;    // 相对画面短边比例，覆盖双眼 + 眉毛
    videoView.eyeProtectSoftness = 0.05;
    videoView.centerProtectStartTime = 0.6;      // 0.6s 前中心盘不出现（此阶段只靠眼部小圈补眼睛）
    videoView.centerProtectRampDuration = 0.65;  // 0.6~1.25s 中心盘缓慢淡入到全强度（放慢，避免一下打开到完整形态）
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

    // 兜底：视频 ~3.5s + fadeIn/fadeOut + 余量
    [effectView scheduleRemovalAfterDelay:6.0];
}

#pragma mark - 资源定位

+ (nullable NSURL *)locateVideoURL {
    NSBundle *mainBundle = [NSBundle bundleForClass:self];

    NSURL *url = [mainBundle URLForResource:kShangfangVideoName withExtension:kShangfangVideoExt];
    if (url) return url;
    url = [mainBundle URLForResource:kShangfangVideoName withExtension:kShangfangVideoExt subdirectory:@"Other"];
    if (url) return url;

    NSURL *resBundleURL = [mainBundle URLForResource:@"WuKongBase_resources" withExtension:@"bundle"];
    if (resBundleURL) {
        NSBundle *resBundle = [NSBundle bundleWithURL:resBundleURL];
        url = [resBundle URLForResource:kShangfangVideoName withExtension:kShangfangVideoExt subdirectory:@"Other"];
        if (url) return url;
        url = [resBundle URLForResource:kShangfangVideoName withExtension:kShangfangVideoExt];
        if (url) return url;
    }
    return nil;
}

@end
