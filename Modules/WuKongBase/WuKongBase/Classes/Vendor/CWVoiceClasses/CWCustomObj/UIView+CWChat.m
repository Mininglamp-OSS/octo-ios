//
//  UIView+CWChat.m
//  CWChatDemo
//
//  Created by chavez on 2017/8/10.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import "UIView+CWChat.h"

@implementation UIView (CWChat)

- (CGFloat)cw_left {
    return self.frame.origin.x;
}


- (void)setCw_left:(CGFloat)x {
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}


- (CGFloat)cw_top {
    return self.frame.origin.y;
}


- (void)setCw_top:(CGFloat)y {
    CGRect frame = self.frame;
    frame.origin.y = y;
    self.frame = frame;
}


- (CGFloat)cw_right {
    return self.frame.origin.x + self.frame.size.width;
}


- (void)setCw_right:(CGFloat)right {
    CGRect frame = self.frame;
    frame.origin.x = right - frame.size.width;
    self.frame = frame;
}



- (CGFloat)cw_bottom {
    return self.frame.origin.y + self.frame.size.height;
}


- (void)setCw_bottom:(CGFloat)bottom {
    CGRect frame = self.frame;
    frame.origin.y = bottom - frame.size.height;
    self.frame = frame;
}


- (CGFloat)cw_centerX {
    return self.center.x;
}


- (void)setCw_centerX:(CGFloat)centerX {
    self.center = CGPointMake(centerX, self.center.y);
}


- (CGFloat)cw_centerY {
    return self.center.y;
}


- (void)setCw_centerY:(CGFloat)centerY {
    self.center = CGPointMake(self.center.x, centerY);
}


- (CGFloat)cw_width {
    return self.frame.size.width;
}


- (void)setCw_width:(CGFloat)width {
    CGRect frame = self.frame;
    frame.size.width = width;
    self.frame = frame;
}

- (CGFloat)cw_height {
    return self.frame.size.height;
}


- (void)setCw_height:(CGFloat)height {
    CGRect frame = self.frame;
    frame.size.height = height;
    self.frame = frame;
}

- (CGPoint)cw_origin {
    return self.frame.origin;
}


- (void)setCw_origin:(CGPoint)origin {
    CGRect frame = self.frame;
    frame.origin = origin;
    self.frame = frame;
}



- (CGSize)cw_size {
    return self.frame.size;
}


- (void)setCw_size:(CGSize)size {
    CGRect frame = self.frame;
    frame.size = size;
    self.frame = frame;
}


- (UIViewController *)cw_viewController{
    for (UIView* next = self; next; next = next.superview) {
        UIResponder* nextResponder = [next nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            return (UIViewController*)nextResponder;
        }
    }
    return nil;
}


@end
