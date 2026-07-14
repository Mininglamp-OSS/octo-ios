//
//  WKClassyVideoEffect.h
//  WuKongBase
//
//  [有品位] → 抖音直播礼物式透明视频特效。
//  素材是一个 **近纯黑背景** 的 mp4，由 WKLumaKeyVideoView 实时 lumakey 抠像
//  （暗→透明、亮→不透明）合成透明效果；播放时宽度铺满屏幕、垂直居中，播放一次。
//

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKClassyVideoEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
