// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationListCell.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"
#import "SwipeTableCell.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKConversationListCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;

/// 子区预览展开/折叠回调
@property(nonatomic,copy,nullable) void(^onToggleThreadPreview)(NSString *channelId);

@end

NS_ASSUME_NONNULL_END
