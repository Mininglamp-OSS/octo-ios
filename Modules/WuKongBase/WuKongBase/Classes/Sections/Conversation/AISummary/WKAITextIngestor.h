// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAITextIngestor.h
//  WuKongBase
//
//  从当前可见的群聊文字气泡里随机抓取短片段，让它们以半透明 fade-in/scale-down
//  的方式从原始位置飞向 AI 总结按钮中心 —— 把"信息汇入 = 总结"的隐喻视觉化。
//
//  与按钮解耦：文字片段被加在 messageListView 上（与 cell、按钮同坐标系），
//  按钮自身不感知本类存在。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAITextIngestor : NSObject

/// @param messageListView   托管文字粒子的视图（必须是 cell 与按钮的共同祖先）
/// @param tableView         消息 tableView，用于读 indexPathsForVisibleRows
/// @param destination       飞行终点：AI 按钮（取 center 在 messageListView 内的坐标）
- (instancetype)initWithMessageListView:(UIView *)messageListView
                              tableView:(UITableView *)tableView
                             destination:(UIView *)destination;

/// active=YES 时生成频率翻倍。
@property(nonatomic, assign) BOOL active;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
