//
//  WKConversationTabView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationTabView : UIView

@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, copy, nullable) void(^onTabChanged)(NSInteger index);

/// 双击某个 tab（index 语义同 onTabChanged：0=关注 1=最近）。
/// 消费方：WKConversationListVC 用它做「最近 tab 依次定位下一个未读会话」。
///
/// 双击手势是**按需安装**的 —— 只有设置了这个 block 才会创建 GR。本 view 还被
/// WKForwardSelectVC 复用，那边不设置 block，就一个多余手势都没有，行为零变化。
@property (nonatomic, copy, nullable) void(^onTabDoubleTapped)(NSInteger index);

/// 设置各 tab 的未读数
- (void)setFollowUnreadCount:(NSInteger)count;
- (void)setRecentUnreadCount:(NSInteger)count;

/// 外部切换（带动画）
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
