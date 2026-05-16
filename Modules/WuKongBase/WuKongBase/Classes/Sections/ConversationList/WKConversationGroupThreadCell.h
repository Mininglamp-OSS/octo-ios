// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationGroupThreadCell.h
//  WuKongBase
//
//  群组+子区预览的专用 Cell
//

#import "SwipeTableCell.h"
#import "WKConversationWrapModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationGroupThreadCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;

/// 计算 cell 高度
+(CGFloat) heightForModel:(WKConversationWrapModel*)model;

/// 子区预览被点击
@property(nonatomic,copy,nullable) void(^onThreadPreviewTap)(NSString *threadChannelId);

/// "+N个子区" 被点击
@property(nonatomic,copy,nullable) void(^onMoreThreadsTap)(NSString *groupNo);

/// 子区预览行被长按
@property(nonatomic,copy,nullable) void(^onThreadPreviewLongPress)(NSString *threadChannelId, NSString *threadName, CGPoint pointInWindow);

/// 子区预览折叠回调
@property(nonatomic,copy,nullable) void(^onToggleThreadPreview)(NSString *channelId);

/// 生成子区矢量 # 图标
+ (UIImage *)channelHashIconWithSize:(CGSize)size color:(UIColor *)color;

/// 生成带指示器的子区图标（0=无指示器, 1=小红点, 2=@符号）
+ (UIImage *)threadToggleIconWithSize:(CGSize)size
                            baseColor:(UIColor *)baseColor
                        indicatorType:(NSInteger)type
                       indicatorColor:(UIColor *)indicatorColor;

@end

NS_ASSUME_NONNULL_END
