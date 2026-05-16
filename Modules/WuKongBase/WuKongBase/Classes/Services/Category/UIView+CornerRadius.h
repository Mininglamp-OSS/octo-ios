//
//  UIView+CornerRadius.h
//  WuKongBase
//
//  Created by tt on 2022/5/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView(CornerRadius)

- (UIView *)clipCornerWithView:(BOOL)topLeft
                   andTopRight:(BOOL)topRight
                 andBottomLeft:(BOOL)bottomLeft
                andBottomRight:(BOOL)bottomRight cornerRadii:(CGSize)cornerRadii;

@end

NS_ASSUME_NONNULL_END
