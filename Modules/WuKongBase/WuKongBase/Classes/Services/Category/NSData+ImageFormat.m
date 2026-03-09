//
//  NSData+ImageFormat.m
//  JLImageCompression
//
//  Created by Rong Mac mini on 2017/9/9.
//  Copyright © 2017年 Ronginet. All rights reserved.
//

#import "NSData+ImageFormat.h"

@implementation NSData (ImageFormat)

+ (JLImageFormat)jl_imageFormatWithImageData:(nullable NSData *)data {
    if (!data) {
        return JLImageFormatUndefined;
    }
    
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return JLImageFormatJPEG;
            
        case 0x89:
            return JLImageFormatPNG;
            
        case 0x47:
            return JLImageFormatGIF;
            
        case 0x40:
        case 0x4D:
            return JLImageFormatTIFF;
            
        case 0x52:
            if (data.length < 12) {
                return JLImageFormatUndefined;
            }
            
            NSString *str = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([str hasPrefix:@"RIFF"] && [str hasSuffix:@"WEBP"]) {
                return JLImageFormatWebp;
            }
    }
    return JLImageFormatUndefined;
}

@end
