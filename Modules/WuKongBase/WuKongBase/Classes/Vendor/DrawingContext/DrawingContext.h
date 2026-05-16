// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DrawingContext : NSObject

@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) int32_t bytesPerRow;
@property (nonatomic, readonly) void *bytes;

- (instancetype)initWithSize:(CGSize)size scale:(CGFloat)scale clear:(bool)clear;
- (UIImage *)generateImage;
- (void)withContext:(void (^)(CGContextRef))f;
- (void)withFlippedContext:(void (^)(CGContextRef))f;

@end

