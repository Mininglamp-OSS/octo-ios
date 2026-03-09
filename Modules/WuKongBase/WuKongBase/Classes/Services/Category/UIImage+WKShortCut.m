//
//  UIImage+ShortCut.m
//  ShourCut
//
//  Created by mac  on 14-1-14.
//  Copyright (c) 2014年 Sky. All rights reserved.
//

#import "UIImage+WKShortCut.h"

@implementation UIImage (WKShortCut)

+ (UIImage *)imageWithColor:(UIColor *)color {
  CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, color.CGColor);
  CGContextFillRect(context, rect);
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}
- (UIImage *)imageScaledToSize:(CGSize)size {
  if (UIGraphicsBeginImageContextWithOptions != NULL)
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
  else
    UIGraphicsBeginImageContext(size);

  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0.0, size.height);
  CGContextScaleCTM(context, 1.0, -1.0);
  CGContextSetBlendMode(context, kCGBlendModeCopy);
  CGContextDrawImage(context, CGRectMake(0.0, 0.0, size.width, size.height),
                     self.CGImage);
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}
- (UIColor *)colorAtPoint:(CGPoint)point {
  if (point.x < 0 || point.y < 0)
    return nil;

  CGImageRef imageRef = self.CGImage;
  NSUInteger width = CGImageGetWidth(imageRef);
  NSUInteger height = CGImageGetHeight(imageRef);
  if (point.x >= width || point.y >= height)
    return nil;

  unsigned char *rawData = malloc(height * width * 4);
  if (!rawData)
    return nil;

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  NSUInteger bytesPerPixel = 4;
  NSUInteger bytesPerRow = bytesPerPixel * width;
  NSUInteger bitsPerComponent = 8;
  CGContextRef context = CGBitmapContextCreate(
      rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace,
      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  if (!context) {
    free(rawData);
    return nil;
  }
  CGColorSpaceRelease(colorSpace);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
  CGContextRelease(context);

  int byteIndex = (bytesPerRow * point.y) + point.x * bytesPerPixel;
  CGFloat red = (rawData[byteIndex] * 1.0) / 255.0;
  CGFloat green = (rawData[byteIndex + 1] * 1.0) / 255.0;
  CGFloat blue = (rawData[byteIndex + 2] * 1.0) / 255.0;
  CGFloat alpha = (rawData[byteIndex + 3] * 1.0) / 255.0;

  UIColor *result = nil;
  result = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
  free(rawData);
  return result;
}
- (BOOL)hasAlphaChannel {
  CGImageAlphaInfo alpha = CGImageGetAlphaInfo(self.CGImage);
  return (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast ||
          alpha == kCGImageAlphaPremultipliedFirst ||
          alpha == kCGImageAlphaPremultipliedLast);
}

- (UIImage *)ImageWithLeftCapWidth {
  return [self stretchableImageWithLeftCapWidth:floorf(self.size.width / 2)
                                   topCapHeight:floorf(self.size.height / 2)];
}
//指定宽度按比例缩放
+ (UIImage *)imageCompressForWidthScale:(UIImage *)sourceImage
                                 targetWidth:(CGFloat)defineWidth {

  UIImage *newImage = nil;
  CGSize imageSize = sourceImage.size;
  CGFloat width = imageSize.width;
  CGFloat height = imageSize.height;
  CGFloat targetWidth = defineWidth;
  CGFloat targetHeight = height / (width / targetWidth);
  CGSize size = CGSizeMake(targetWidth, targetHeight);
  CGFloat scaleFactor = 0.0;
  CGFloat scaledWidth = targetWidth;
  CGFloat scaledHeight = targetHeight;
  CGPoint thumbnailPoint = CGPointMake(0.0, 0.0);

  if (CGSizeEqualToSize(imageSize, size) == NO) {

    CGFloat widthFactor = targetWidth / width;
    CGFloat heightFactor = targetHeight / height;

    if (widthFactor > heightFactor) {
      scaleFactor = widthFactor;
    } else {
      scaleFactor = heightFactor;
    }
    scaledWidth = width * scaleFactor;
    scaledHeight = height * scaleFactor;

    if (widthFactor > heightFactor) {

      thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;

    } else if (widthFactor < heightFactor) {

      thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
    }
  }

  UIGraphicsBeginImageContext(size);

  CGRect thumbnailRect = CGRectZero;
  thumbnailRect.origin = thumbnailPoint;
  thumbnailRect.size.width = scaledWidth;
  thumbnailRect.size.height = scaledHeight;

  [sourceImage drawInRect:thumbnailRect];

  newImage = UIGraphicsGetImageFromCurrentImageContext();

  if (newImage == nil) {

    NSLog(@"scale image fail");
  }
  UIGraphicsEndImageContext();
  return newImage;
}

//按比例缩放,size 是你要把图显示到 多大区域
+ (UIImage *)imageCompressFitSizeScale:(UIImage *)sourceImage
                                 targetSize:(CGSize)size {
  UIImage *newImage = nil;
  CGSize imageSize = sourceImage.size;
  CGFloat width = imageSize.width;
  CGFloat height = imageSize.height;
  CGFloat targetWidth = size.width;
  CGFloat targetHeight = size.height;
  CGFloat scaleFactor = 0.0;
  CGFloat scaledWidth = targetWidth;
  CGFloat scaledHeight = targetHeight;
  CGPoint thumbnailPoint = CGPointMake(0.0, 0.0);

  if (CGSizeEqualToSize(imageSize, size) == NO) {

    CGFloat widthFactor = targetWidth / width;
    CGFloat heightFactor = targetHeight / height;

    if (widthFactor > heightFactor) {
      scaleFactor = widthFactor;

    } else {

      scaleFactor = heightFactor;
    }
    scaledWidth = width * scaleFactor;
    scaledHeight = height * scaleFactor;

    if (widthFactor > heightFactor) {

      thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
    } else if (widthFactor < heightFactor) {

      thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
    }
  }

  UIGraphicsBeginImageContext(size);

  CGRect thumbnailRect = CGRectZero;
  thumbnailRect.origin = thumbnailPoint;
  thumbnailRect.size.width = scaledWidth;
  thumbnailRect.size.height = scaledHeight;

  [sourceImage drawInRect:thumbnailRect];

  newImage = UIGraphicsGetImageFromCurrentImageContext();
  if (newImage == nil) {
    NSLog(@"scale image fail");
  }

  UIGraphicsEndImageContext();
  return newImage;
}


@end
