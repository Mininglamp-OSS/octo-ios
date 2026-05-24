//
//  WKFloatingMenu.h
//  WuKongBase
//
//  会话列表 / 子区列表共用的浮层菜单：长按 cell 弹出，与项目其他自定义弹窗
//  （cellBackgroundColor / 圆角 / 阴影 / 字号）保持一致。
//  从 WKConversationListVC.m 拆出来，让 WKThreadListVC 等也能复用，避免风格走样。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFloatingMenu : NSObject

/// items: 每项一个 NSDictionary
///   @"title": NSString           — 菜单文案（必填）
///   @"icon" : UIImage  (可选)    — 左侧 20pt template 图标
///   @"isDestructive": @YES (可选) — 红色高亮
///   @"action": void(^)(void)     — 点击 handler（必填）
/// point: window 坐标系的锚点（菜单优先显示在锚点上方，空间不足时落到下方）
+ (void)showItems:(NSArray<NSDictionary *> *)items atPoint:(CGPoint)point;

/// 主动关掉浮层（点击其他菜单 / 路由切换时调用，未弹则 no-op）
+ (void)dismiss;

#pragma mark - 内置 follow / unfollow 图标（与会话列表菜单同款，便于跨 VC 复用）

+ (UIImage *)iconFollow;
+ (UIImage *)iconUnfollow;

@end

NS_ASSUME_NONNULL_END
