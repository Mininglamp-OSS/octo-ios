//
//  WKActionVideoEffect.h
//  WuKongBase
//
//  [崇尚行动] → 抖音直播礼物式全屏透明视频特效。
//  素材是一个不带 alpha 的 mp4（深蓝背景金色发怒表情 + 光环 + 粒子），
//  由 WKLumaKeyVideoView 实时 lumakey 抠像成透明效果，居中悬浮播放一次。

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKActionVideoEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
