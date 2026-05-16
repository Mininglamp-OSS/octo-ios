//
//  UIColor+Hex.h
//  JCVideoRecordDemo
//
//  Created by zhengjiacheng on 2017/9/28.
//  Copyright © 2017年 zhengjiacheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (Hex)
+ (UIColor *)colorWithHex:(long)hexColor;
+ (UIColor *)colorWithHex:(long)hexColor alpha:(float)opacity;
@end
