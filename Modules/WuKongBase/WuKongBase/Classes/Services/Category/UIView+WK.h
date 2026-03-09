//
//  UIView+NIM.h
//  NIMKit
//
//  Created by chris.
//  Copyright (c) 2015年 NetEase. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (WK)

@property (nonatomic) CGFloat lim_left;

/**
 * Shortcut for frame.origin.y
 *
 * Sets frame.origin.y = top
 */
@property (nonatomic) CGFloat lim_top;


/// 相对于父类视图X居中
@property(nonatomic,assign) UIView *lim_centerX_parent;

/// 相对于父类视图Y居中
@property(nonatomic,assign) UIView *lim_centerY_parent;

/**
 * Shortcut for frame.origin.x + frame.size.width
 *
 * Sets frame.origin.x = right - frame.size.width
 */
@property (nonatomic) CGFloat lim_right;

/**
 * Shortcut for frame.origin.y + frame.size.height
 *
 * Sets frame.origin.y = bottom - frame.size.height
 */
@property (nonatomic) CGFloat lim_bottom;

/**
 * Shortcut for frame.size.width
 *
 * Sets frame.size.width = width
 */
@property (nonatomic) CGFloat lim_width;

/**
 * Shortcut for frame.size.height
 *
 * Sets frame.size.height = height
 */
@property (nonatomic) CGFloat lim_height;

/**
 * Shortcut for center.x
 *
 * Sets center.x = centerX
 */
@property (nonatomic) CGFloat lim_centerX;

/**
 * Shortcut for center.y
 *
 * Sets center.y = centerY
 */
@property (nonatomic) CGFloat lim_centerY;

-(CGFloat) lim_centerY:(UIView*)parent;
/**
 * Shortcut for frame.origin
 */
@property (nonatomic) CGPoint lim_origin;

/**
 * Shortcut for frame.size
 */
@property (nonatomic) CGSize lim_size;

//找到自己的vc
- (UIViewController *)lim_viewController;



@end
