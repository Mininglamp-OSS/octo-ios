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

+ (BOOL)wk_isAnimatedImageData:(NSData *)data {
    if (!data || data.length < 16) {
        return NO;
    }

    JLImageFormat fmt = [self jl_imageFormatWithImageData:data];

    if (fmt == JLImageFormatGIF) {
        return YES;
    }

    if (fmt == JLImageFormatPNG) {
        // APNG: 8 字节 PNG 签名后，扫 chunks，命中 acTL 即动画 PNG；
        // 命中 IDAT 之前都没看到 acTL 就是静态 PNG。
        const uint8_t *bytes = data.bytes;
        NSUInteger length = data.length;
        NSUInteger offset = 8; // skip PNG signature
        while (offset + 8 <= length) {
            uint32_t chunkLen =
                ((uint32_t)bytes[offset]     << 24) |
                ((uint32_t)bytes[offset + 1] << 16) |
                ((uint32_t)bytes[offset + 2] << 8)  |
                ((uint32_t)bytes[offset + 3]);
            const uint8_t *type = bytes + offset + 4;
            if (memcmp(type, "acTL", 4) == 0) {
                return YES;
            }
            if (memcmp(type, "IDAT", 4) == 0) {
                return NO;
            }
            // 4 (len) + 4 (type) + chunkLen + 4 (CRC)
            NSUInteger advance = (NSUInteger)chunkLen + 12;
            if (advance < 12 || offset + advance < offset) {
                return NO; // overflow guard
            }
            offset += advance;
        }
        return NO;
    }

    if (fmt == JLImageFormatWebp) {
        // RIFF (4) + size (4) + WEBP (4) = 12 bytes header，
        // 紧接 chunk header (type 4 + size 4)。若第一个 chunk 是 VP8X，
        // 其 payload 第一个字节 bit1 (0x02) 即 ANIM 标志位。
        if (data.length < 21) {
            return NO;
        }
        const uint8_t *bytes = data.bytes;
        if (memcmp(bytes + 12, "VP8X", 4) != 0) {
            return NO;
        }
        uint8_t flags = bytes[20]; // 12 + 4 (type) + 4 (chunk size) = 20
        return (flags & 0x02) != 0;
    }

    return NO;
}

@end
