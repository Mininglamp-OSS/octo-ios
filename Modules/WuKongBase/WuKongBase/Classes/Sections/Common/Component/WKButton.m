//
//  WKButton.m
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import "WKButton.h"


// 按钮背景颜色
#define ATC_Button_bgColor  [UIColor colorWithRed:81.0/255.0f green:169.0/255.0f blue:56.0/255.0f alpha:1.0f]

@interface WKButton (){
    WKButtonStyle _style;
}
@end

@implementation WKButton


-(instancetype) initWithStyle:(WKButtonStyle)style{
    self = [super init];
    if (!self) return nil;
    
    _style = style;
    self.backgroundColor = ATC_Button_bgColor;
    self.layer.masksToBounds=YES;
    self.layer.cornerRadius = 2.0f;
    //[self setBackgroundImage:[self imageWithColor:AT_BUTTON_MASTER_COLOR] forState:UIControlStateNormal];
    //[self setBackgroundImage:[self imageWithColor:AT_Color_Font_Gray] forState:UIControlStateHighlighted];
    return self;
}

//  颜色转换为背景图片
-(UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
