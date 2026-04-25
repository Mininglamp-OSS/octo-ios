//
//  WKConversationGroupThreadOnlyCell.h
//  WuKongBase
//
//  群组+仅 "+X个子区" 的专用 Cell（无活跃子区预览行）
//

#import "SwipeTableCell.h"
#import "WKConversationWrapModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationGroupThreadOnlyCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;

+(CGFloat) heightForModel:(WKConversationWrapModel*)model;

/// "+N个子区" 被点击
@property(nonatomic,copy,nullable) void(^onMoreThreadsTap)(NSString *groupNo);

/// 子区折叠回调
@property(nonatomic,copy,nullable) void(^onToggleThreadPreview)(NSString *channelId);

@end

NS_ASSUME_NONNULL_END
