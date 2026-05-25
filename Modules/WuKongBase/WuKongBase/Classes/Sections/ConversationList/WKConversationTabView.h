//
//  WKConversationTabView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationTabView : UIView

@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy, nullable) void(^onTabChanged)(NSInteger index);

/// 设置各 tab 的未读数
- (void)setFollowUnreadCount:(NSInteger)count;
- (void)setRecentUnreadCount:(NSInteger)count;

/// 外部切换（带动画）
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;

/// 设置各 tab 的 @提醒标识（[有人@我]）
/// 关注/最近 tab 各自独立 —— 同一条 @我 消息会出现在其归属集合对应的 tab 旁边,
/// 同时属于两个集合时两边都亮。
- (void)setFollowHasMention:(BOOL)hasMention;
- (void)setRecentHasMention:(BOOL)hasMention;

@end

NS_ASSUME_NONNULL_END
