//
//  WKImageView.m
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import "WKImageView.h"
#import <SDWebImage/SDWebImage.h>
#import "WKResource.h"
#import "WKApp.h"
#import "UIImageView+WK.h"

@implementation WKImageView


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
-(void) loadImage:(NSURL*)url placeholderImage:(UIImage*)placeholderImage{
    [self lim_setImageWithURL:url placeholderImage:placeholderImage];
    
}

-(void) loadImage:(NSURL*)url{
    UIImage *placeholdeImg =   [WKApp.shared loadImage:@"Common/Index/Placeholder" moduleID:@"WuKongBase"];
    
    [self lim_setImageWithURL:url placeholderImage:placeholdeImg];
}
@end
