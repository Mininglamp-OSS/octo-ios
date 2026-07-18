//
//  UIColor+GrayColor.m
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 06/11/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "UIColor+GrayColor.h"

@implementation UIColor (GrayColor)

+ (UIColor *)grayColorWithValue:(NSInteger)value {
    // Clamp value to 0-255 range
    NSInteger clampedValue = MAX(0, MIN(255, value));
    CGFloat normalizedValue = clampedValue / 255.0;
    
    return [UIColor colorWithRed:normalizedValue
                           green:normalizedValue
                            blue:normalizedValue
                           alpha:1.0];
}

@end