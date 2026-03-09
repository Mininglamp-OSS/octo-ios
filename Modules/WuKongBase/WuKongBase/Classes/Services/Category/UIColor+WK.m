//
//  UIColor+WK.m
//  WuKongBase
//
//  Created by tt on 2021/8/23.
//

#import "UIColor+WK.h"

@implementation UIColor (WK)


+ (UIColor *)colorWithHexString:(NSString *)stringToConvert {
    if (stringToConvert.length == 0) {
        return [UIColor blackColor];
    }
    if ([stringToConvert hasPrefix:@"#"]) {
        stringToConvert = [stringToConvert substringFromIndex:1];
    }
    if ([stringToConvert containsString:@"0x"]) {
        stringToConvert = [stringToConvert stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    }
    
    if ([stringToConvert containsString:@"0X"]) {
        stringToConvert = [stringToConvert stringByReplacingOccurrencesOfString:@"0X" withString:@""];
    }
    
    if (stringToConvert.length==3) {
        stringToConvert = [NSString stringWithFormat:@"%c%c%c%c%c%c",
                           [stringToConvert characterAtIndex:0],
                           [stringToConvert characterAtIndex:0],
                           [stringToConvert characterAtIndex:1],
                           [stringToConvert characterAtIndex:1],
                           [stringToConvert characterAtIndex:2],
                           [stringToConvert characterAtIndex:2]];
    }
    if (stringToConvert.length==4) {
        stringToConvert = [NSString stringWithFormat:@"%c%c%c%c%c%c%c%c",
                           [stringToConvert characterAtIndex:0],
                           [stringToConvert characterAtIndex:0],
                           [stringToConvert characterAtIndex:1],
                           [stringToConvert characterAtIndex:1],
                           [stringToConvert characterAtIndex:2],
                           [stringToConvert characterAtIndex:2],
                           [stringToConvert characterAtIndex:3],
                           [stringToConvert characterAtIndex:3]];
    }
    
    
    if (stringToConvert.length==8) {
        NSScanner *scanner = [NSScanner scannerWithString:stringToConvert];
               
               unsigned hexNum;
               
               if(![scanner scanHexInt:&hexNum]) {
                   return nil;
               }
               
               return [UIColor colorWithRGBAlphaHex:hexNum];
        
    }else if (stringToConvert.length==6) {
        NSScanner *scanner = [NSScanner scannerWithString:stringToConvert];
        
        unsigned hexNum;
        
        if(![scanner scanHexInt:&hexNum]) {
            return nil;
        }
        
        return [UIColor colorWithRGBHex:hexNum];
    }else{
        return nil;
    }
}

+ (UIColor *)colorWithHexString:(NSString *)stringToConvert withAlpha:(CGFloat)alpha{
    if (stringToConvert.length == 0) {
        return [UIColor blackColor];
    }
    if ([stringToConvert hasPrefix:@"#"]) {
        stringToConvert = [stringToConvert substringFromIndex:1];
    }
    if ([stringToConvert containsString:@"0x"]) {
        stringToConvert = [stringToConvert stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    }
    
    if ([stringToConvert containsString:@"0X"]) {
        stringToConvert = [stringToConvert stringByReplacingOccurrencesOfString:@"0X" withString:@""];
    }
    NSScanner *scanner = [NSScanner scannerWithString:stringToConvert];
    
    unsigned hexNum;
    
    if(![scanner scanHexInt:&hexNum]) {
        return nil;
    }
    
    return [UIColor colorWithRGBHex:hexNum withAlpha:alpha];
}

+ (UIColor *)colorWithRGBHex:(UInt32)hex {
    
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;
    return [UIColor colorWithRed:r /255.0f
                         green:g /255.0f
                          blue:b /255.0f
                         alpha:1.0f];
}

+ (UIColor *)colorWithRGBAlphaHex:(UInt32)hex {
    
    int r = (hex >> 24) & 0xFF;
    int g = (hex >> 16) & 0xFF;
    int b = (hex>> 8) & 0xFF;
    int alpha = hex & 0xFF;
    return [UIColor colorWithRed:r /255.0f
                         green:g /255.0f
                          blue:b /255.0f
                           alpha:alpha/255.0f];
}

+ (UIColor *)colorWithRGBHex:(UInt32)hex withAlpha:(CGFloat)alpha{
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;
    return [UIColor colorWithRed:r /255.0f
                           green:g /255.0f
                            blue:b /255.0f
                           alpha:alpha];
}


- (NSString *)toHexRGB{
    if (CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor)) != kCGColorSpaceModelRGB)
    {
        if ([self isEqual:[UIColor clearColor]]) {
            return @"#000000FF";
        }
        else if ([self isEqual:[UIColor whiteColor]]){
            return @"#FFFFFF";
        }else{
            return @"000000";
        }
        return [NSString stringWithFormat:@"#FFFFFF"];
    }
    
    if (CGColorGetNumberOfComponents(self.CGColor) < 4)
    {
        const CGFloat *components = CGColorGetComponents(self.CGColor);
        CGFloat r = components[0];//红色
        CGFloat g = components[1];//绿色
        CGFloat b = components[2];//蓝色
        return [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
        
    }
    
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    CGFloat a = components[3];
  if (a==1) {
        return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
                lroundf(r * 255),
                lroundf(g * 255),
                lroundf(b * 255)] ;
    }
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX%02lX",
            lroundf(r * 255),
            lroundf(g * 255),
            lroundf(b * 255),
            lroundf(a * 255)];
}


@end
