//
//  GGGIFCompressUtil.h
//
//
//  Created by PoloChen on 2019/3/25.
//  Copyright © 2019 Polo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GGGIFCompressUtil : NSObject


/**
 初始化压缩对象
 @param imageData 原始gif data
 @param targetSize 目标尺寸（像素）
 @param targetByte 目标大小（单位B）
 */
- (instancetype)initWithImageData:(NSData *)imageData targetSize:(CGSize)targetSize targetByte:(NSUInteger)targetByte;

- (void)compressAsynchronouslyWithCompletionHandler:(void (^)(NSData * _Nullable compressedData, CGSize gifImageSize, NSError * _Nullable error))handler;

@end

NS_ASSUME_NONNULL_END
