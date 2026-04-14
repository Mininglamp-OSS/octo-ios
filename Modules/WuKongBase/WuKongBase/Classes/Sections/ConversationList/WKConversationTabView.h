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
- (void)setGroupUnreadCount:(NSInteger)count;
- (void)setPrivateUnreadCount:(NSInteger)count;

/// 外部切换（带动画）
- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
