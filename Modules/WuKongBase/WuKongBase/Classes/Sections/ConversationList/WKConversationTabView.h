// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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

/// 设置群聊 tab 的 @提醒标识
- (void)setGroupHasMention:(BOOL)hasMention;

@end

NS_ASSUME_NONNULL_END
