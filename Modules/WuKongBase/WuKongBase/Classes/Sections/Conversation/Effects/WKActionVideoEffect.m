//
//  WKActionVideoEffect.m
//  WuKongBase
//

#import "WKActionVideoEffect.h"
#import "WKLumaKeyVideoView.h"
#import "WKMessageEffectView.h"

@implementation WKActionVideoEffect

// 资源文件名（放在 WuKongBase/Assets/Other/，随 WuKongBase_resources.bundle 打包）
static NSString * const kActionVideoName = @"action_celebrate";
static NSString * const kActionVideoExt  = @"mp4";

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect {
    if (!effectView) return;
    (void)sourceRect;  // 本特效固定居中悬浮，不依赖气泡位置

    NSURL *url = [self locateVideoURL];
    if (!url) {
#if DEBUG
        NSLog(@"[ActionVideo] ❌ 找不到资源 %@.%@", kActionVideoName, kActionVideoExt);
#endif
        return;
    }

    static const NSTimeInterval kFadeIn = 0.45;  // 淡入
    static const NSTimeInterval kFadeOut = 0.6;  // 淡出

    // 全屏铺满（9:16 视频 aspect-fill 填满整个 effectView）。
    // 不再叠单色遮罩：新视频背景本身是渐变（四角近黑 → 底部蓝光晕），
    // 单色遮罩会与渐变对不上反而出边界。背景由 shader 的"亮度驱动半透明纱"处理：
    // 暗处更透（露出聊天页）、亮处（底部光晕）保留更多 → 像发光薄纱浮在 App 页面上。
    WKLumaKeyVideoView *videoView = [[WKLumaKeyVideoView alloc] initWithVideoURL:url];
    videoView.frame = effectView.bounds;
    videoView.alpha = 0.0;
    // 中间脸/眼睛区域不抠
    videoView.centerProtectRadius = 0.30;
    videoView.centerProtectSoftness = 0.14;
    // 背景半透明纱：暗→更透(floor)，亮→保留多(ceil)
    videoView.backgroundAlphaFloor = 0.05;
    videoView.backgroundAlphaCeil = 0.45;
    [effectView addSubview:videoView];

    // 淡入
    [UIView animateWithDuration:kFadeIn delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        videoView.alpha = 1.0;
    } completion:nil];

    __weak typeof(effectView) weakEffect = effectView;
    [videoView playWithCompletion:^{
        // 播完淡出，再移除整个 effectView
        __strong typeof(weakEffect) strongEffect = weakEffect;
        [UIView animateWithDuration:kFadeOut delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            videoView.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (strongEffect) {
                [strongEffect scheduleRemovalAfterDelay:0.0];
            }
        }];
    }];

    // 兜底：万一 completion 因异常未回调，按视频时长 + 余量强制清理（视频 ~3.2s）
    [effectView scheduleRemovalAfterDelay:6.0];
}

#pragma mark - 资源定位

/// 在 WuKongBase 资源 bundle 里找视频。打包路径与 cheer_short.m4a 一致：
/// WuKongBase_resources.bundle 的 Other/ 子目录。逐级防御性查找。
/// （参考 WKConfettiView.swift:locateCheerSoundURL）
+ (nullable NSURL *)locateVideoURL {
    NSBundle *mainBundle = [NSBundle bundleForClass:self];

    // 1) bundle 根 + Other/ 子目录（防御性，万一打包方式变了）
    NSURL *url = [mainBundle URLForResource:kActionVideoName withExtension:kActionVideoExt];
    if (url) return url;
    url = [mainBundle URLForResource:kActionVideoName withExtension:kActionVideoExt subdirectory:@"Other"];
    if (url) return url;

    // 2) WuKongBase_resources.bundle 子 bundle（实际打包路径）
    NSURL *resBundleURL = [mainBundle URLForResource:@"WuKongBase_resources" withExtension:@"bundle"];
    if (resBundleURL) {
        NSBundle *resBundle = [NSBundle bundleWithURL:resBundleURL];
        url = [resBundle URLForResource:kActionVideoName withExtension:kActionVideoExt subdirectory:@"Other"];
        if (url) return url;
        url = [resBundle URLForResource:kActionVideoName withExtension:kActionVideoExt];
        if (url) return url;
    }
    return nil;
}

@end
