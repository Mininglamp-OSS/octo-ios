//
//  UIBarButtonItem+SXCreate.m
//  UINavigation-SXFixSpace
//
//  Created by charles on 2017/9/8.
//  Copyright © 2017年 None. All rights reserved.
//

#import "UIBarButtonItem+WK.h"
#import "UIImage+WKShortCut.h"
#import "WKApp.h"
@implementation UIBarButtonItem (WK)

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image {
  return [self itemWithTarget:target
                            action:action
                        nomalImage:image
                  higeLightedImage:nil
                   imageEdgeInsets:UIEdgeInsetsZero];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {
  return [self itemWithTarget:target
                            action:action
                        nomalImage:image
                  higeLightedImage:nil
                   imageEdgeInsets:imageEdgeInsets];
}
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              buttonType:(UIButtonType)buttonType
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {
  return [self itemWithTarget:target
                            action:action
                        buttonType:buttonType
                             title:nil
                   imageEdgeInsets:imageEdgeInsets];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   image:(UIImage *)image
                                   title:(NSString *)title
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {
  return [self itemWithTarget:target
                            action:action
                        nomalImage:image
                  higeLightedImage:nil
                             title:title
                   imageEdgeInsets:imageEdgeInsets];
}
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              nomalImage:(UIImage *)nomalImage
                        higeLightedImage:(UIImage *)higeLightedImage
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {

  UIButton *button =
      [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40.0f, 40.0f)];
  [button addTarget:target
                action:action
      forControlEvents:UIControlEventTouchUpInside];
  [button setImage:[nomalImage imageScaledToSize:CGSizeMake(30.0f, 30.0f)]
          forState:UIControlStateNormal];
  if (higeLightedImage) {
    [button setImage:higeLightedImage forState:UIControlStateHighlighted];
  }
  button.imageEdgeInsets = imageEdgeInsets;
  return [[UIBarButtonItem alloc] initWithCustomView:button];
}
+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              nomalImage:(UIImage *)nomalImage
                        higeLightedImage:(UIImage *)higeLightedImage
                                   title:(NSString *)title
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {

  UIButton *button;
  if (!nomalImage) {
    button = [UIButton buttonWithType:UIButtonTypeContactAdd];
  } else {
    button = [UIButton buttonWithType:UIButtonTypeSystem];
  }
  [button addTarget:target
                action:action
      forControlEvents:UIControlEventTouchUpInside];

  if (nomalImage) {
    [button
        setImage:[nomalImage
                     imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
        forState:UIControlStateNormal];
  }
  if (higeLightedImage) {
    [button setImage:higeLightedImage forState:UIControlStateHighlighted];
  }
  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
  button.titleLabel.font = [WKApp shared].config.navBarTitleFont;
  button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  //    [button sizeToFit];
  if (button.bounds.size.width < 40) {
    CGFloat width = 40 / button.bounds.size.height * button.bounds.size.width;
    button.bounds = CGRectMake(0, 0, 60, 40);
  }
  if (button.bounds.size.height > 40) {
    CGFloat height = 40 / button.bounds.size.width * button.bounds.size.height;
    button.bounds = CGRectMake(0, 0, 60, height);
  }
  button.titleEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 0);

  if (title.length > 0 || ![title isEqualToString:@""]) {
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 0);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, 0);
  } else {
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    button.bounds = CGRectMake(0, 0, 40, button.bounds.size.height);
  }
  button.backgroundColor = [UIColor clearColor];
  return [[UIBarButtonItem alloc] initWithCustomView:button];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                              buttonType:(UIButtonType)buttonType
                                   title:(NSString *)title
                         imageEdgeInsets:(UIEdgeInsets)imageEdgeInsets {

  UIButton *button = [UIButton buttonWithType:buttonType];
  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
  button.titleLabel.font = [WKApp shared].config.navBarTitleFont;
  button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  //    [button sizeToFit];
  if (button.bounds.size.width < 40) {
    CGFloat width = 40 / button.bounds.size.height * button.bounds.size.width;
    button.bounds = CGRectMake(0, 0, 60, 40);
  }
  if (button.bounds.size.height > 40) {
    CGFloat height = 40 / button.bounds.size.width * button.bounds.size.height;
    button.bounds = CGRectMake(0, 0, 60, height);
  }
  button.titleEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 0);

  if (title.length > 0 || ![title isEqualToString:@""]) {
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 0);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, 0);
  } else {
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    button.bounds = CGRectMake(0, 0, 40, button.bounds.size.height);
  }
  button.backgroundColor = [UIColor clearColor];
  return [[UIBarButtonItem alloc] initWithCustomView:button];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title {
  return [self itemWithTarget:target
                            action:action
                             title:title
                              font:nil
                        titleColor:nil
                  highlightedColor:nil
                   titleEdgeInsets:UIEdgeInsetsZero];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title
                              titleColor:(UIColor *)titleColor
                         titleEdgeInsets:(UIEdgeInsets)titleEdgeInsets {
  return [self itemWithTarget:target
                            action:action
                             title:title
                              font:nil
                        titleColor:titleColor
                  highlightedColor:nil
                   titleEdgeInsets:titleEdgeInsets];
}

+ (UIBarButtonItem *)itemWithTarget:(id)target
                                  action:(SEL)action
                                   title:(NSString *)title
                                    font:(UIFont *)font
                              titleColor:(UIColor *)titleColor
                        highlightedColor:(UIColor *)highlightedColor
                         titleEdgeInsets:(UIEdgeInsets)titleEdgeInsets {

  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button addTarget:target
                action:action
      forControlEvents:UIControlEventTouchUpInside];

  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.textAlignment = NSTextAlignmentRight;
  button.contentHorizontalAlignment = NSTextAlignmentRight;
    button.titleLabel.font = [UIFont systemFontOfSize:17.0f];
  button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  [button setTitleColor:titleColor ? titleColor : [WKApp shared].config.navBarButtonColor
               forState:UIControlStateNormal];
  [button setTitleColor:highlightedColor ? highlightedColor : nil
               forState:UIControlStateHighlighted];

  [button sizeToFit];
  if (button.bounds.size.width < 40) {
    CGFloat width = 50 / button.bounds.size.height * button.bounds.size.width;
    button.bounds = CGRectMake(0, 0, 60, 40);
  }
  if (button.bounds.size.height > 40) {
    CGFloat height = 40 / button.bounds.size.width * button.bounds.size.height;
    button.bounds = CGRectMake(0, 0, 60, height);
  }
  button.titleEdgeInsets = titleEdgeInsets;
  button.bounds = CGRectMake(0, 0, 80, button.bounds.size.height);
  button.backgroundColor = [UIColor clearColor];

  return [[UIBarButtonItem alloc] initWithCustomView:button];
}

+ (UIBarButtonItem *)fixedSpaceWithWidth:(CGFloat)width {

  UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                           target:nil
                           action:nil];
  fixedSpace.width = width;
  return fixedSpace;
}

@end
