//
//  UIBarButtonItem+SXCreate.h
//  UINavigation-SXFixSpace
//
//  Created by charles on 2017/9/8.
//  Copyright © 2017年 None. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIBarButtonItem (WK)

/**
 根据图片生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param image image
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image;
/**
 根据图片生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param image image
 @param imageEdgeInsets 图片偏移
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets;
/**
 根据图片生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param buttonType 默认按钮的样式
 @param imageEdgeInsets 图片偏移
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              buttonType:(UIButtonType)buttonType
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets;

/**
 根据图片生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param image image
 @param imageEdgeInsets 图片偏移
 @param title 标题
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image
                                   title:(NSString *)title
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets;

/**
 根据图片生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param nomalImage nomalImage
 @param higeLightedImage higeLightedImage
 @param imageEdgeInsets 图片偏移
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              nomalImage:(UIImage *)nomalImage
                        higeLightedImage:(UIImage *)higeLightedImage
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets;

/**
 根据文字生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param title title
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title;

/**
 根据文字生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param title title
 @param titleEdgeInsets 文字偏移
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title
                              titleColor:(UIColor *)titleColor
                         titleEdgeInsets:(UIEdgeInsets)titleEdgeInsets;

/**
 根据文字生成UIBarButtonItem

 @param target target对象
 @param action 响应方法
 @param title title
 @param font font
 @param titleColor 字体颜色
 @param highlightedColor 高亮颜色
 @param titleEdgeInsets 文字偏移
 @return 生成的UIBarButtonItem
 */
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title
                                    font:(UIFont *)font
                              titleColor:(UIColor *)titleColor
                        highlightedColor:(UIColor *)highlightedColor
                         titleEdgeInsets:(UIEdgeInsets)titleEdgeInsets;

/**
 用作修正位置的UIBarButtonItem

 @param width 修正宽度
 @return 修正位置的UIBarButtonItem
 */
+(UIBarButtonItem *)fixedSpaceWithWidth:(CGFloat)width;

@end
