//
//  WKHeartEffect.h
//  WuKongBase
//
//  ❤️ / 💗 / 💕 / 💖 → 爱心心形绽放
//  从触发气泡中心爆出，飞散组合成一颗心形，心跳脉冲后沿径向飘散淡出

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKHeartEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
