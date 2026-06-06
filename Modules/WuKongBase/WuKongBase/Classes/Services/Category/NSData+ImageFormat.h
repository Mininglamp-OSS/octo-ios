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

/**
 检测图片字节是否是动图 (GIF / APNG / 动画 WebP)，纯 magic-bytes 嗅探，不依赖扩展名。
 - GIF: GIF87a / GIF89a 头
 - APNG: PNG 头 + 第一个 IDAT 之前出现 acTL chunk
 - 动 WebP: RIFF....WEBP 容器内 VP8X chunk 的 flags 字节 ANIM 位 (0x02) 置位
 */
+ (BOOL)wk_isAnimatedImageData:(nullable NSData *)data;

@end
