// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryPromptEditor.h
//  WuKongBase
//
//  自定义提示词编辑面板（cyber 风格，与 ActionMenu 同色系）。
//
//  视觉：dark glass 底 + cyan 描边 + magenta glow + cyan→magenta 渐变标题。
//  交互：键盘弹起时自动上移；外部 tap 收键盘；左 Cancel 右 Save。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAISummaryPromptEditor : NSObject

/// 弹出编辑器。
/// @param anchorView   弹出锚点
/// @param prefixHint   "提示词将以「{群名}{ 子区名 }」开头" 这类前缀提示
/// @param initialText  已保存的提示词，无则传 nil
/// @param onSave       保存回调（参数为用户输入的纯文本，可能为空字符串）；用户点取消传 nil
+ (void)presentFromView:(UIView *)anchorView
              prefixHint:(NSString *)prefixHint
             initialText:(nullable NSString *)initialText
                  onSave:(void (^)(NSString * _Nullable text))onSave;

@end

NS_ASSUME_NONNULL_END
