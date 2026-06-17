//
//  WKThreadCreatePopupView.h
//  WuKongBase
//
//  创建子区弹窗 — 替代 UIAlertController，与项目内长按菜单卡片视觉一致：
//  浅/深色自适应卡片 + 半透明遮罩 + 圆角 + 阴影。
//
//  当 sourceMessage 非空时，弹窗中部会渲染该消息的预览气泡（直接复用聊天详情
//  消息 cell registry，外观与原气泡完全一致），让用户在创建子区前确认引用对象。
//
//  入口签名故意收窄成单一静态方法，三处调用方（消息长按 / 文本选区 / 子区列表
//  "+" 按钮）共享同一份 createThread + joinThread + 跳页面流程。
//

#import <UIKit/UIKit.h>

@class WKMessageModel;
@class WKThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadCreatePopupView : UIView

/// 弹出创建子区对话框。
/// @param groupNo       父群编号
/// @param sourceMessage 引用源消息；nil 表示从子区列表 "+" 入口创建（无预览）
/// @param defaultName   输入框默认值（消息长按一般传 digest 前 10 字；文本选区
///                      传选中文字前 50 字；列表入口传 nil）
/// @param onCreated     创建成功（含 join 完成）后的回调；调用方自己决定是否
///                      进一步 navigate 到新子区。回调内 popup 已关闭。
+ (void)showWithGroupNo:(NSString *)groupNo
          sourceMessage:(nullable WKMessageModel *)sourceMessage
            defaultName:(nullable NSString *)defaultName
              onCreated:(nullable void(^)(WKThreadModel *thread))onCreated;

@end

NS_ASSUME_NONNULL_END
