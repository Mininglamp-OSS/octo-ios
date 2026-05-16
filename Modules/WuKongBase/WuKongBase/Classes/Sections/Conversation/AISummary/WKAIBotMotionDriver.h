// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAIBotMotionDriver.h
//  WuKongBase
//
//  把 UIScrollView 的滚动事件桥接到 WKAIBotRiveView 的走/停状态：
//    起走 debounce 80ms：避免轻微 flick 立刻走起来
//    停走 debounce 250ms：包含手指抬起后的减速阶段
//  本驱动 *不* 占用 scrollView.delegate；用 KVO contentOffset 监听，零侵入。
//

#import <Foundation/Foundation.h>
@class WKAIBotRiveView;

NS_ASSUME_NONNULL_BEGIN

@interface WKAIBotMotionDriver : NSObject

- (instancetype)initWithBot:(WKAIBotRiveView *)bot
                 scrollView:(UIScrollView *)scrollView;

/// 开始观察。重复调用安全。
- (void)attach;

/// 停止观察 + 复位状态。dealloc 时也会自动调用。
- (void)detach;

@end

NS_ASSUME_NONNULL_END
