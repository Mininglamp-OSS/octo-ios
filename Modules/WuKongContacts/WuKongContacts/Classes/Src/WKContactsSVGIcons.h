// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKContactsSVGIcons : NSObject

+ (UIImage *)iconNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color strokeWidth:(CGFloat)strokeWidth;

+ (UIImage *)iconNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
