//
//  WKDisplayLinkCalibration.h
//  WuKongBase
//
//  SDWebImage 的 SDAnimatedImagePlayer 用 SDDisplayLink.duration 累加每帧消耗时间。
//  其内部公式：CADisplayLink.duration * CADisplayLink.frameInterval。
//  iOS 10 起 frameInterval 被 deprecated，理论默认 1。实测在某些 iOS 版本上读取该
//  属性会返回非 1 值（观测到 4），导致 SDAnimatedImagePlayer 每帧累计的时间比墙钟
//  快若干倍，整张 GIF / APNG 实际播放速度比帧 delay 期望值快同等倍数。
//
//  本类做一次性探针：app 启动时读取 CADisplayLink.frameInterval 初值，算出补偿因子
//  `playbackRateCompensation`（= 1 / frameInterval）。WKImageView 在 init 时把它
//  喂给 `SDAnimatedImageView.playbackRate`，就把 player 内部"过多累积"抵消回正常速度。
//
//  其它直接用 SDAnimatedImageView 的地方（WKGIFMessageCell / WKAnimatedAvatarPreviewVC）
//  改用 WKImageView 即可同时拿到这道补偿。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKDisplayLinkCalibration : NSObject

/// 返回 SDAnimatedImageView.playbackRate 应被设置成的补偿因子。
/// frameInterval=1 (正常) → 1.0，frameInterval=4 (iOS 18 实测) → 0.25。
/// 线程安全，第一次调用做探针并缓存。
+ (double)playbackRateCompensation;

@end

NS_ASSUME_NONNULL_END
