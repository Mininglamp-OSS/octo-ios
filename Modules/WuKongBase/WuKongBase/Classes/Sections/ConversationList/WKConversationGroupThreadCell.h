//
//  WKConversationGroupThreadCell.h
//  WuKongBase
//
//  群组+子区预览的专用 Cell
//

#import "SwipeTableCell.h"
#import "WKConversationWrapModel.h"

@class WKThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationGroupThreadCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;

/// 计算 cell 高度
+(CGFloat) heightForModel:(WKConversationWrapModel*)model;

/// 关注 tab 视角下该群可见的子区列表 —— model.threadPreviews 过滤掉
/// 不在 WKFollowedKeysStore.followedKeys 里的子区。store 为空（未加载完）时
/// 返回 model.threadPreviews 原样，避免冷启动瞬间全部清空。
+ (NSArray<WKThreadModel *> *)visibleThreadPreviewsFor:(WKConversationWrapModel*)model;
/// 关注 tab 视角下该群"已关注子区"总数（含未在 previews 里的）
+ (NSInteger)visibleThreadCountFor:(WKConversationWrapModel*)model;

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
