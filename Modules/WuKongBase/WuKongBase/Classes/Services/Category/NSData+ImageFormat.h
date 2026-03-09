//
//  NSData+ImageFormat.h
//  JLImageCompression
//
//  Created by Rong Mac mini on 2017/9/9.
//  Copyright © 2017年 Ronginet. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 图片类型
 */
typedef NS_ENUM(NSUInteger, JLImageFormat) {
    JLImageFormatUndefined = -1,
    JLImageFormatJPEG = 0,
    JLImageFormatPNG,
    JLImageFormatGIF,
    JLImageFormatTIFF,
    JLImageFormatWebp,
};

@interface NSData (ImageFormat)

/**
 根据图片的data数据,获取图片类型
 
 @param data 图片的data数据
 @return 图片类型
 */
+ (JLImageFormat)jl_imageFormatWithImageData:(nullable NSData *)data;

@end
