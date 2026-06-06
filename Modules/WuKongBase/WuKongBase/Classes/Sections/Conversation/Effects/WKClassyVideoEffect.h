//
//  WKClassyVideoEffect.h
//  WuKongBase
//
//  [有品位] → 抖音直播礼物式全屏透明视频特效。
//  素材是一个 **近纯黑背景** 的 mp4（黄脸 + 蓝紫电路环 + 王冠/礼帽/酒杯 + "有品位"文字 + 粒子光环），
//  由 WKLumaKeyVideoView 实时 lumakey 抠像（暗→透明、亮→不透明）成透明效果，
//  居中悬浮播放一次。
//

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKClassyVideoEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
