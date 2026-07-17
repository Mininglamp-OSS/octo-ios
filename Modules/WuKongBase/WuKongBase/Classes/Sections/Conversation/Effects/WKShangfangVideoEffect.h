//
//  WKShangfangVideoEffect.h
//  WuKongBase
//
//  [尚方宝剑] → 抖音直播礼物式全屏透明视频特效。
//  素材：黑底 HEVC mp4（金色表情挥剑 + 光环粒子），
//  由 WKLumaKeyVideoView 实时 lumakey 抠像成透明效果，居中悬浮播放一次。
//  视频宽高比与 WKClassyVideoEffect 一致 (1764x3840)，实现基本照抄 Classy。

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKShangfangVideoEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
