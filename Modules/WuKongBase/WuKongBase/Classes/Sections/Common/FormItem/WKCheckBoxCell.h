// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCheckBoxCell.h
//  WuKongBase
//
//  Created by tt on 2023/9/28.
//

#import "WKViewItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKCheckBoxModel : WKViewItemModel

@property(nonatomic,assign) BOOL on;
@property(nonatomic,copy) void(^onCheck)(BOOL on);

@end



@interface WKCheckBoxCell : WKViewItemCell

@end

NS_ASSUME_NONNULL_END
