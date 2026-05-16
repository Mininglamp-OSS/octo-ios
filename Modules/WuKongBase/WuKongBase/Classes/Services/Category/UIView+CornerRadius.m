//
//  UIView+CornerRadius.m
//  WuKongBase
//
//  Created by tt on 2022/5/4.
//

#import "UIView+CornerRadius.h"

@implementation UIView (CornerRadius)

- (UIView *)clipCornerWithView:(BOOL)topLeft
                   andTopRight:(BOOL)topRight
                 andBottomLeft:(BOOL)bottomLeft
                andBottomRight:(BOOL)bottomRight cornerRadii:(CGSize)cornerRadii
{
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:(topLeft==YES ? UIRectCornerTopLeft : 0) |
                                                                     (topRight==YES ? UIRectCornerTopRight : 0) |
                                                                     (bottomLeft==YES ? UIRectCornerBottomLeft : 0) |
                                                                     (bottomRight==YES ? UIRectCornerBottomRight : 0)
                                                         cornerRadii:cornerRadii];
    // 创建遮罩层
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;   // 轨迹
    self.layer.mask = maskLayer;

    return self;
}

@end
