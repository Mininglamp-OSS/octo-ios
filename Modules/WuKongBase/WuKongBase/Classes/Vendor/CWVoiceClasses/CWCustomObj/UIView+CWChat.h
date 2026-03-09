//
//  UIView+CWChat.h
//  CWChatDemo
//
//  Created by chavez on 2017/8/10.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import <UIKit/UIKit.h>

#define UIColorFromRGBA(R,G,B,A) [UIColor  colorWithRed: R /255.0 green: G /255.0 blue: B/255.0 alpha:A]

#define kSelectBackGroudColor UIColorFromRGBA(83, 178, 232, 1.0)
#define kNormalBackGroudColor UIColorFromRGBA(119, 119, 119, 1.0)

@interface UIView (CWChat)


@property (nonatomic) CGFloat cw_left;

/**
 * Shortcut for frame.origin.y
 *
 * Sets frame.origin.y = top
 */
@property (nonatomic) CGFloat cw_top;

/**
 * Shortcut for frame.origin.x + frame.size.width
 *
 * Sets frame.origin.x = right - frame.size.width
 */
@property (nonatomic) CGFloat cw_right;

/**
 * Shortcut for frame.origin.y + frame.size.height
 *
 * Sets frame.origin.y = bottom - frame.size.height
 */
@property (nonatomic) CGFloat cw_bottom;

/**
 * Shortcut for frame.size.width
 *
 * Sets frame.size.width = width
 */
@property (nonatomic) CGFloat cw_width;

/**
 * Shortcut for frame.size.height
 *
 * Sets frame.size.height = height
 */
@property (nonatomic) CGFloat cw_height;

/**
 * Shortcut for center.x
 *
 * Sets center.x = centerX
 */
@property (nonatomic) CGFloat cw_centerX;

/**
 * Shortcut for center.y
 *
 * Sets center.y = centerY
 */
@property (nonatomic) CGFloat cw_centerY;
/**
 * Shortcut for frame.origin
 */
@property (nonatomic) CGPoint cw_origin;

/**
 * Shortcut for frame.size
 */
@property (nonatomic) CGSize cw_size;

//找到自己的vc
- (UIViewController *)cw_viewController;


@end
