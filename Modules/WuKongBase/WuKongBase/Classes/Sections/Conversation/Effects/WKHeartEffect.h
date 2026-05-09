//
//  WKHeartEffect.h
//  WuKongBase
//
//  ❤️ / 💗 / 💕 / 💖 → 爱心上升效果
//  大量不同大小的爱心从屏幕底部缓慢飘升，经过气泡时气泡柔和脉冲

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKHeartEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
