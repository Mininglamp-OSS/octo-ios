//
//  UIImage+ATImage.h
//  Common
//
//  Created by tt on 2018/9/12.
//

#import <UIKit/UIKit.h>

@interface UIImage (WK)

+ (UIImage *)lim_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;

/**
 *  <#Description#>
 *
 *  @param originSize                   图片原始大小
 *  @param maxLength 图片最长边的长度
 *
 *  @return <#return value description#>
 */
+ (CGSize)lim_sizeWithImageOriginSize:(CGSize)originSize
                             maxLength:(CGFloat)imageMaxLength;

+ (CGSize)lim_sizeWithImageOriginSize:(CGSize)originSize;

@end
