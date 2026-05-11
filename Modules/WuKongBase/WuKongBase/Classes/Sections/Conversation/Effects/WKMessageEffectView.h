//
//  WKMessageEffectView.h
//  WuKongBase

#import <UIKit/UIKit.h>
@class WKBubbleSnapshot;

NS_ASSUME_NONNULL_BEGIN

@interface WKMessageEffectView : UIView

// 动画期间持有的 UIDynamicAnimator
@property (nonatomic, strong, nullable) UIDynamicAnimator *animator;

// 源宿主视图（WKMessageListView）。effectView 挂在 keyWindow 上，
// 通过弱引用回指宿主视图/表格做坐标转换。
// 气泡快照直接加在 tableView 内部（和真实 cell 同层），滚动时一起滚动，视觉不分层。
@property (nonatomic, weak, nullable) UIView *sourceHostView;
@property (nonatomic, weak, nullable) UITableView *tableView;

// 当前特效持有的气泡快照，兜底清理（页面退出或 effect 被取消时）
@property (nonatomic, strong, nullable) NSArray<WKBubbleSnapshot *> *snapshots;

- (void)scheduleRemovalAfterDelay:(NSTimeInterval)delay;

/// 恢复所有被隐藏的原始 cell，移除所有快照视图
- (void)cleanupSnapshots;

@end

NS_ASSUME_NONNULL_END
