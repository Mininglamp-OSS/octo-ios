// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  CWChangeVoiceView.h
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWVoiceChangePlayView.h"
//----------------------变声界面---------------------------------//
@interface CWChangeVoiceView : UIView

@property (nonatomic,weak) id<CWVoiceChangePlayViewDelegate> delegate;
@end
