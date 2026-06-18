// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMainTabController.h
//  Octo
//
//  Created by tt on 2019/12/7.
//  Copyright 2026 MININGLAMP Technology and the OCTO contributors
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMainTabController : UITabBarController

/// 设置底部"消息" tab item icon 右上角的未读角标。0 隐藏，>99 显示 99+。
/// 样式与会话列表 cell 同源（粉色背景 + 红色文字，详见 WKBadgeView/WKUnreadBadge*Color）。
/// 由 WKConversationListVC.refreshBadge 在 150ms coalesce 内统一驱动。
-(void) setMessageUnreadCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
