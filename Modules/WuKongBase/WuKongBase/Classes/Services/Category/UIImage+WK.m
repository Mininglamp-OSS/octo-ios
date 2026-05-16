//
//  UIImage+ATImage.m
//  Common
//
//  Created by tt on 2018/9/12.
//

#import "UIImage+WK.h"

@implementation UIImage (WK)

+ (UIImage *)lim_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle  {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
    return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
#elif __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_8_0
    return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
#else
    if ([UIImage respondsToSelector:@selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
        return [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
    } else {
        return [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
    }
#endif
}

+ (CGSize)lim_sizeWithImageOriginSize:(CGSize)originSize
                             maxLength:(CGFloat)imageMaxLength{
    CGSize actSize = originSize;
    
    imageMaxLength = imageMaxLength*([UIScreen mainScreen].bounds.size.width/375.0f);
    if(originSize.width>originSize.height){ //横图
        
        if(originSize.width>imageMaxLength){
            CGFloat rate = imageMaxLength/originSize.width;
            actSize.width = imageMaxLength;
            actSize.height = originSize.height*rate;
        }
        
    }else if(originSize.width<originSize.height){ //竖图
        
        if(originSize.height>imageMaxLength){
            
            CGFloat rate = imageMaxLength/originSize.height;
            actSize.height = imageMaxLength;
            actSize.width = originSize.width*rate;
            //长图的时候图特别长显示的宽度比会变形
            if (actSize.width<75.0f) {
                actSize.width = 75.0f;
            }
        }
        
    }else if(originSize.width==originSize.height){ //正方形
        
        if(originSize.width>imageMaxLength){
            
            actSize.width = imageMaxLength;
            CGFloat rate = imageMaxLength/originSize.width;
            actSize.height =rate*originSize.height;
        }
        
    }
    return actSize;
}

+(CGSize) lim_sizeWithImageOriginSize:(CGSize)originSize{
    CGFloat imageMaxLength = 400.0f/2;
    return [UIImage lim_sizeWithImageOriginSize:originSize maxLength:imageMaxLength];
}

@end
