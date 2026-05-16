// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryActionMenu.h
//  WuKongBase
//
//  AI 总结按钮长按弹出的赛博朋克风格 ActionMenu。
//
//  与 WKAISummaryFloatingButton 同色系：dark glass 底 + cyan 描边 + 渐变标题。
//  itemId 由调用方约定（直接传 NSInteger），便于和 EntryController 的时间档位常量配合。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 菜单 item 的语义类型 —— EntryController 据此路由不同的处理函数。
typedef NS_ENUM(NSInteger, WKAISummaryActionKind) {
    WKAISummaryActionKindRange = 0,        // itemId = 时间档位秒数；0=未读、NSIntegerMax=全部
    WKAISummaryActionKindCustomPrompt,     // 使用已保存的自定义提示词
    WKAISummaryActionKindEditPrompt,       // 打开提示词编辑器
    WKAISummaryActionKindDeletePrompt,     // 删除已保存的提示词
    WKAISummaryActionKindSwitchBot,        // 进入 Bot picker
    WKAISummaryActionKindBotPick,          // itemId = bot index
};

@interface WKAISummaryActionItem : NSObject
@property(nonatomic, assign) WKAISummaryActionKind kind;
@property(nonatomic, assign) NSInteger      itemId;
@property(nonatomic, copy)   NSString      *title;
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, assign) BOOL            highlighted;
@property(nonatomic, assign) BOOL            destructive;       // 红色（删除）

+ (instancetype)itemWithKind:(WKAISummaryActionKind)kind
                      itemId:(NSInteger)itemId
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                 highlighted:(BOOL)highlighted;
@end

@interface WKAISummaryActionMenu : NSObject

/// @param anchorView 弹出锚点（通常是浮动按钮）
/// @param title      标题（如 "AI 一键总结"）
/// @param subtitle   小字副标题（如 "AssistantBot · 2 个可用"）
/// @param items      菜单项
/// @param footerItem 可选的底部"切换 Bot"按钮（nil 表示没有）
/// @param select     用户选择某项（含 footer）的回调；item 为 nil 表示外部点击取消
+ (void)presentFromView:(UIView *)anchorView
                  title:(NSString *)title
               subtitle:(nullable NSString *)subtitle
                  items:(NSArray<WKAISummaryActionItem *> *)items
             footerItem:(nullable WKAISummaryActionItem *)footerItem
              onSelect:(void (^)(WKAISummaryActionItem * _Nullable item))select;

@end

NS_ASSUME_NONNULL_END
