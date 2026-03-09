//
//  UIImage+ShortCut.h
//  ShourCut
//
//  Created by mac  on 14-1-14.
//  Copyright (c) 2014年 Sky. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (WKShortCut)

//=============================================================================
/// @name Create image
///=============================================================================
/**
 *  将色值返回为1x1像素的png图片
 *
 *  @param color UIColor
 *
 *  @return 返回为1x1像素的png图片
 */
+ (UIImage *)imageWithColor:(UIColor *)color;

/**
 *   重置图片大小
 *
 *  @param size 大小
 *
 *  @return 新的图片
 */
- (UIImage *)imageScaledToSize:(CGSize)size;

///=============================================================================
/// @name Get info from image
///=============================================================================

/**
 *  获取该图片的某像素点的颜色
 *
 *  @param point 点坐标
 *
 *  @return 返回UIColor 或者错误(nil)
 */
- (UIColor *)colorAtPoint:(CGPoint)point;
/**
 *  返回该图片是否有透明度通道
 *
 *  @return YES, NO
 */
- (BOOL)hasAlphaChannel;

/**
 *  九宫格图片拉伸
 *
 *  @return UIImage
 */
- (UIImage *)ImageWithLeftCapWidth;

//指定宽度按比例缩放
+ (UIImage *)imageCompressForWidthScale:(UIImage *)sourceImage
                                 targetWidth:(CGFloat)defineWidth;
//按比例缩放,size 是你要把图显示到 多大区域
+ (UIImage *) imageCompressFitSizeScale:(UIImage *)sourceImage targetSize:(CGSize)size;
@end
