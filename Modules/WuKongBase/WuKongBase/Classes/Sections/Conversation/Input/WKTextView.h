// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKTextView.h
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import <UIKit/UIKit.h>
#import "UITextView+WKPlaceholder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKTextView : UITextView

@property(nonatomic,weak,nullable) UIResponder * overrideNextResponder;

@end

NS_ASSUME_NONNULL_END
