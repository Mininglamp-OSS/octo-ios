//
//  UIColor+GrayColor.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 06/11/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (GrayColor)

/**
 * Creates a gray UIColor from an integer value (0-255)
 * @param value The gray value (0-255, automatically clamped)
 * @return A UIColor with the specified gray value
 */
+ (UIColor *)grayColorWithValue:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END