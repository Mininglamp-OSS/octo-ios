// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  YBIBVideoTopBar.h
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/7/11.
//  Copyright © 2019 杨波. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKVideoTopBar : UIView

@property (nonatomic, strong, readonly) UIButton *cancelButton;

+ (CGFloat)defaultHeight;

@end

NS_ASSUME_NONNULL_END
