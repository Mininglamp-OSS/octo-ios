//
//  WKJoinGroupSuccessDialog.h
//  WuKongBase
//
//  YUJ-141 — 跨 Space 加群成功后的双行 Toast/Dialog。
//
//  对齐 Web PR#1068 `showJoinSuccessToast(crossSpace = true)`：
//    ┌─────────────────────────────────────┐
//    │  已加入 "{groupName}"                │
//    │  此群位于 {spaceName} Space          │
//    │                                     │
//    │  [取消]          [切换过去 #722ED1] │
//    └─────────────────────────────────────┘
//
//  交互：
//    - 「切换过去」→ onSwitchTapped() 回调，dialog 自行 dismiss。
//    - 「取消」/ 点遮罩 → 仅 dismiss，保持 viewer 在原 Space（硬约束）。
//    - 未交互自动消失：不走（用户可能被打扰离开屏幕再回来仍需看到）。
//

#import <UIKit/UIKit.h>
#import "WKJoinGroupSuccessHelper.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKJoinGroupSuccessDialog : UIView

/// 「切换过去」按钮回调。dismiss 由 dialog 自己完成，外部不需要再 hide。
@property(nonatomic,copy,nullable) void(^onSwitchTapped)(void);

/// 「取消」/点遮罩回调（可选）。
@property(nonatomic,copy,nullable) void(^onCancelTapped)(void);

/// 在 keyWindow 顶层显示一个跨 Space 加群成功 dialog。
/// `notice` 不能为 nil；`groupName` / `spaceName` 空时内部做兜底展示。
+(instancetype) showWithNotice:(WKJoinGroupSuccessNotice *)notice
                       onSwitch:(void(^)(void))onSwitch;

-(void) dismissAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
