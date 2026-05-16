// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryFloatingButton.h
//  WuKongBase
//
//  AI 一键总结按钮（赛博朋克风）。
//
//  纯 CALayer/UIBezierPath 实现，无第三方依赖。
//  形状：六边形 56×56；右边缘半嵌入屏幕；neon cyan + magenta 渐变。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAISummaryFloatingButton : UIControl

/// active=YES 时进入"高活跃群"模式：呼吸频率加快，AI 字色饱和拉满。
@property(nonatomic, assign) BOOL active;

/// 触发一次 RGB chroma-split glitch 动画（外部如收到 @ 自己时可调）。
- (void)playGlitchOnce;

/// 入场动画：从右边外滑入 + 阴影 flash。
- (void)playEntranceAnimation;

/// 充能动画：中心 ✦ 大幅膨胀、halo 爆光、外圈冲击波。
/// 与外部"可见气泡飞入"动画并行播放即营造"信息汇入 + 充能"的合成感。
- (void)playChargeUp;

@end

NS_ASSUME_NONNULL_END
