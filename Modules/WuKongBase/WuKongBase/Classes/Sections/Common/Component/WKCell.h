// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCell.h
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCell : UITableViewCell


/**
 顶部分割线
 */
@property(nonatomic,strong) UIView *topLineView;

/**
 底部分割线
 */
@property(nonatomic,strong) UIView *bottomLineView;


/**
 UI初始化写在此方法内
 */
-(void) setupUI;

-(void) refresh:(id)cellModel;

/**
 cell的ID
 
 @return <#return value description#>
 */
+(NSString*) cellId;

// 线左边距离
@property(nonatomic,assign) CGFloat lineLeft;
@end

NS_ASSUME_NONNULL_END
