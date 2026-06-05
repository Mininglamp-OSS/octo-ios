// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextMentionPickerVC.h
//  WuKongBase
//
//  图文 caption 编辑页里的 @ 成员选择器：典型微信/TG 全屏 modal 列表，含 @所有人 /
//  @所有AI / 真实成员，复用 WKConversationContextImpl 的 searchMembers + sentinel
//  装配规则。caption 输入框检测到 '@' 或用户点 @ 按钮时弹起；选完单击成员则把
//  WKMentionUserCellModel 通过 onSelect 回传给 caption VC（caption 自己拼文本 +
//  累积 WKInputMentionItem 入 mention list）。
//

#import <UIKit/UIKit.h>

@class WKChannel;
@class WKMentionUserCellModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKRichTextMentionPickerVC : UIViewController

/// @param channel 当前会话 channel（用来 searchMembers）；DM 仅显示 @所有AI（无成员可 @）。
/// @param keyword '@' 后已经键入的关键字（picker 自身仍带搜索框做二次过滤；'' = 显示所有）
- (instancetype)initWithChannel:(WKChannel *)channel keyword:(nullable NSString *)keyword;

/// 选中回调；nil = 取消（用户下滑/Cancel 关闭）。dismiss 后再触发。
@property(nonatomic, copy, nullable) void (^onSelect)(WKMentionUserCellModel *_Nullable model);

@end

NS_ASSUME_NONNULL_END
