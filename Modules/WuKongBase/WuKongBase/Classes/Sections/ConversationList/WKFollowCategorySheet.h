// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowCategorySheet.h
//  WuKongBase
//
//  会话列表 / 通讯录 共用的「选择分组」底部 sheet。从 WKConversationListVC 的
//  presentFollowCategorySheetWithTitle:... 拆出来，纯 UI 类，不绑 VC，
//  以便其它模块（通讯录长按"添加到关注"）能用上同款视觉。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class WKCategoryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface WKFollowCategorySheet : NSObject

/// 弹出底部 sheet。约定：
///  - 用户点某行 → 调 onPick(categoryId, categoryName) 后自动 dismiss
///  - 用户点 "+ 新建分组" → 调 onCreateRequested() 后自动 dismiss
///    （调用方负责弹自家的"创建分组"流程，并在新分组创建成功后再决定下一步动作）
///  - 用户点 ✕ / 半透明遮罩 → 仅 dismiss，不回调
///  - selectedCategoryId 非空时，相应行前面会画 ✓（用于"移动分组"展示当前归属）
///
/// 同款 sheet 已在 keyWindow 上时会先 remove 再重建，避免叠层。
+ (void)showWithTitle:(NSString *)title
            categories:(NSArray<WKCategoryEntity *> *)categories
    selectedCategoryId:(nullable NSString *)selectedCategoryId
         showCreateRow:(BOOL)showCreateRow
                onPick:(nullable void (^)(NSString *categoryId, NSString *categoryName))onPick
      onCreateRequested:(nullable void (^)(void))onCreateRequested;

/// 主动关闭当前 sheet。未弹则 no-op。回调不会触发。
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
