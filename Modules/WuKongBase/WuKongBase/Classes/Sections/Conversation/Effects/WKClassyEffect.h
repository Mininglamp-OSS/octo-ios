//
//  WKClassyEffect.h
//  WuKongBase
//
//  [有品位] → 直接锚在气泡内表情图位置：**自己发的气泡从左侧伸手，别人发的从右侧伸手**。
//           肤色卡通手臂从图片一侧伸出（mask 反向揭示 + 沿路径粒子）→ 拳头滑出到手臂末端
//           → 拳头平滑变成竖起大拇指（拳头 knuckles 融化，thumb 从掌上抬起）→ 淡出。
//

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKClassyEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView
        sourceRect:(CGRect)sourceRect
          fromSelf:(BOOL)fromSelf;

@end

NS_ASSUME_NONNULL_END
