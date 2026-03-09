//
//  UIImage+Compression.h
//  JLImageCompression
//
//  Created by Rong Mac mini on 2017/9/9.
//  Copyright © 2017年 Ronginet. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSData+ImageFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (Compression)


+ (NSData *)jl_compressImageSize:(UIImage *)image toByte:(NSUInteger)maxLength;
/**
 压缩图片,压缩 JPEG,PNG,GIF  TODO: 暂时注释掉此方法 因为GIF压缩内存爆炸
 @param imageData 压缩前图片的data
 @param size 期望压缩后的大小,单位:MB
 @return 压缩后的图片
 */
//+ (UIImage *)jl_compressWithImage:(NSData *)imageData specifySize:(CGFloat)size;


// 只压缩GIF
+ (void)jl_compressWithImageGIF:(NSData *)imageData targetSize:(CGSize)targetSize targetByte:(NSUInteger)targetByte handler:(void (^)(NSData * _Nullable compressedData, CGSize gifImageSize, NSError * _Nullable error))handler;

@end


NS_ASSUME_NONNULL_END
