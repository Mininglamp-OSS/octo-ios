// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKBotAvatarVC.h
//  WuKongBase
//
//  Bot 头像全屏页 + 创建者编辑入口（参考 Android `UserDetailActivity` 的功能，
//  但 UX 与 `WKMeAvatarVC`（个人头像页）对齐：右上 3-dots → 修改头像）。
//
//  使用方：`WKUserInfoVC.avatarPressed:` 检测 `info.robot && loginUid == botCreatorUid`
//  时 push 本 VC，并设置 `canEdit = YES`。其他情况保持原 `YBImageBrowser` 不变。
//

#import "WuKongBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKBotAvatarVC : WKBaseVC

/// 目标 Bot 的 uid。必传。
@property(nonatomic, copy) NSString *botUid;

/// 是否允许编辑：仅在当前登录者为 Bot 的创建者时为 YES（控制 3-dots 按钮可见性）。
/// 默认为 NO（仅查看）。
@property(nonatomic, assign) BOOL canEdit;

@end

NS_ASSUME_NONNULL_END
