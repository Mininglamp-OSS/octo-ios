// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMenusBtn.h
//  WuKongBase
//
//  Created by tt on 2021/10/14.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMenusBtn : UIButton

@property(nonatomic,assign) BOOL openMenus;

@property(nonatomic,copy) void(^onClick)(BOOL open);

-(void) changeStatus;

@end

NS_ASSUME_NONNULL_END
