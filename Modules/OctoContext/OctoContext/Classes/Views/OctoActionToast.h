//
//  OctoActionToast.h
//  OctoContext
//
//  带「Action 按钮」的轻量 toast。视觉上是底部浮起的胶囊,
//  左侧文字 + 右侧紫色 action label, 整体停留 3.5s 给用户反应时间。
//
//  与 [UIView showMsg:] (CSToast) 的分工:
//    - showMsg:   —— 纯文本提示, 1.0s 自动消失, 不可点
//    - OctoActionToast —— 提示 + 一个动作 (查看/打开/重试/...), action 区可点
//
//  典型场景: 创建总结成功后提示「已开始生成总结」+ 「查看」跳列表;
//          收到邀请后提示 + 「去看看」跳详情; 等等。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OctoActionToast : NSObject

/// 在 keyWindow 上显示 (最常用). 文字 + 紫色 action 按钮的胶囊浮层。
/// action 点击后 toast 立即消失并触发 onAction; 点空白处不响应; 3.5s 自动消失。
+ (void)showText:(NSString *)text
     actionTitle:(NSString *)actionTitle
        onAction:(nullable void (^)(void))onAction;

/// 在指定 host view 上显示。用于 sheet / modal / 浮层之上, 传 sheet.view 自己。
+ (void)showInView:(UIView *)host
              text:(NSString *)text
       actionTitle:(NSString *)actionTitle
          onAction:(nullable void (^)(void))onAction;

@end

NS_ASSUME_NONNULL_END
