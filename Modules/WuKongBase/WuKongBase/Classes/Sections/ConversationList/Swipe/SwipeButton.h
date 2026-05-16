//
//  SwipeButton.h
//  WuKongBase
//
//  Created by tt on 2021/8/10.
//

#import <UIKit/UIKit.h>
#import <Lottie/Lottie.h>

typedef void(^TouchSwipeButtonBlock)(void);

@interface SwipeButton : UIButton

@property (nonatomic, strong) TouchSwipeButtonBlock touchBlock;
@property (nonatomic, strong) LOTAnimationView  *deleteAnimationView;

/**
 *  创建左滑或右滑时的button， button只有title没有Image
 *
 *  @param title button的标题
 *  @param font  button的字体大小 默认为15
 *  @param textColor button的字体颜色 默认黑色
 *  @param backgroundColor  button的背景颜色 默认白色
 */
+ (SwipeButton *)createSwipeButtonWithTitle:(NSString *)title backgroundColor:(UIColor *)backgroundColor touchBlock:(TouchSwipeButtonBlock)block;

+ (SwipeButton *)createSwipeButtonWithTitle:(NSString *)title font:(CGFloat)font textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor touchBlock:(TouchSwipeButtonBlock)block;


/**
 *   创建左滑或右滑时的button， button只有Image没有title
 */
+ (SwipeButton *)createSwipeButtonWithImage:(UIImage *)image backgroundColor:(UIColor *)color touchBlock:(TouchSwipeButtonBlock)block;

/**
 *  创建左滑或右滑时的button,文字图片同时存在，且image在上 title在下
 */
+ (SwipeButton *)createSwipeButtonWithTitle:(NSString *)title backgroundColor:(UIColor *)backgroundColor image:(UIImage *)image touchBlock:(TouchSwipeButtonBlock)block;

+ (SwipeButton *)createSwipeButtonWithTitle:(NSString *)title font:(CGFloat)font textColor:(UIColor *)textColor backgroundColor:(UIColor *)backgroundColor image:(UIImage *)image touchBlock:(TouchSwipeButtonBlock)block;


@end
