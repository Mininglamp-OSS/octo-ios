// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKTextMessageCell.h
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKMessageCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKTextMessageCell : WKMessageCell

/// 重置分段渲染标记，深浅色切换时调用以强制重建分段内容
-(void) invalidateSegments;

@end

NS_ASSUME_NONNULL_END
