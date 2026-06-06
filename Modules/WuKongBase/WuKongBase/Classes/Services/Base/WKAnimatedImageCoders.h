//
//  WKAnimatedImageCoders.h
//  WuKongBase
//
//  对 SDWebImage 默认动图 coder 的"延时矫正"封装。
//  问题：SDWebImage 默认对 GIF / APNG 只在帧 delay ≤ 10ms 时才兜底到 100ms，
//  其它原始 delay 全部直接采用 (`SDImageIOAnimatedCoder.m:182`)。
//  这意味着 unclampedDelayTime=20ms 的"快帧" GIF 在 SDAnimatedImageView 里会真按
//  50fps 播，而 Photos.app / Safari / 微信按 WebKit 的现代规范 ≤ 20ms 一律 clamp
//  到 100ms，所以同一张 GIF 看着我们这边快了 1–2 倍。
//
//  WK_ANIMATED_DELAY_MIN 设为 0.02 秒 (20ms)：≤ 20ms 的帧 delay 强制 100ms，
//  > 20ms 的保持原值。
//
//  使用方式：App 启动时在 SDImageCodersManager 顶部插一遍（见 WKApp.configSDWebImage）。
//
//  动 WebP 暂未覆盖（需要 libwebp 头），如果后续发现 .webp 动图速度也异常再加。
//
//  回退路径：注释掉 WKApp.m 里相关 addCoder: 两行，即恢复 SDWebImage 默认行为。
//

#import <SDWebImage/SDImageGIFCoder.h>
#import <SDWebImage/SDImageAPNGCoder.h>

NS_ASSUME_NONNULL_BEGIN

/// ≤ 该秒数的帧 delay 视为"非法"，强制矫正为 100ms。
/// 0.02 = 20ms (50fps)，匹配现代 WebKit / Chrome / Photos.app 的行为。
static const NSTimeInterval WK_ANIMATED_DELAY_MIN = 0.02;

@interface WKImageGIFCoder : SDImageGIFCoder
@end

@interface WKImageAPNGCoder : SDImageAPNGCoder
@end

NS_ASSUME_NONNULL_END
