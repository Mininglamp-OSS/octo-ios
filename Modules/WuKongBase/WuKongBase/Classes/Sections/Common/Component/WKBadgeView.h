//
//  WKBadgeView.h
//  WuKongBase
//
//  Created by tt on 2020/1/5.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// ========== 统一的未读 / @我 配色 ==========
// 取色采自 UI 提供的徽章图：文字 #F54A45，背景 = 同色 ~15% alpha (白底合成 #FDE4E2)。
// 用 alpha 形式让暗色模式下背景跟着色调走，不至于过亮。
// @我 标识独立使用 WeChat 风格 #FA5151 红底白字，强调"被点名"优先级。
static inline UIColor *WKUnreadBadgeFgColor(void) {
    return [UIColor colorWithRed:245.0f/255.0f green:74.0f/255.0f blue:69.0f/255.0f alpha:1.0f];
}
static inline UIColor *WKUnreadBadgeBgColor(void) {
    return [UIColor colorWithRed:245.0f/255.0f green:74.0f/255.0f blue:69.0f/255.0f alpha:0.15f];
}
static inline UIColor *WKMentionBadgeBgColor(void) {
    return [UIColor colorWithRed:250.0f/255.0f green:81.0f/255.0f blue:81.0f/255.0f alpha:1.0f];
}

@interface WKBadgeView : UIView

@property (strong) UIColor *badgeBackgroundColor;
@property (nonatomic, strong) UIColor *badgeTextColor; // 默认 white；调用方需要"浅底深字"风格时显式覆盖
@property (nonatomic, copy) NSString *badgeValue;

+ (instancetype)viewWithBadgeTip:(NSString *)badgeValue;
+ (instancetype)viewWithoutBadgeTip;

@end

NS_ASSUME_NONNULL_END
