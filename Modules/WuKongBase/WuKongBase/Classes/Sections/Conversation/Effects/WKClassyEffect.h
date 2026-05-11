//
//  WKClassyEffect.h
//  WuKongBase
//
//  [有品位] → 多个 👍 从屏幕顶端按抛物线在可见气泡顶部逐个蹦跳而下
//

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKClassyEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
