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

@end

NS_ASSUME_NONNULL_END
