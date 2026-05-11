//
//  WKRocketLaunchEffect.h
//  WuKongBase
//
//  🚀 [使命必达] — 代码绘制的火箭从气泡位置发射升空。
//  参考 CodePen chingy/OJMLodv 的结构（鼻锥 / 机身 / 舷窗 / 尾翼 / 喷口 / 火焰），
//  用 CAShapeLayer + CAGradientLayer + CAEmitterLayer 原生实现，不依赖图片资源。
//
//  舷窗里会嵌入发送者头像 → 像是发送者坐着火箭起飞。
//

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKRocketLaunchEffect : NSObject

/// 带头像的完整接口：舷窗内会嵌入 avatarImage（半透明 → 玻璃感）
+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
       avatarImage:(nullable UIImage *)avatarImage;

/// 兼容旧调用：内部转调 avatar=nil
+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
