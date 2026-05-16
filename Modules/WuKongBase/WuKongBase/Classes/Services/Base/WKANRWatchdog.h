// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//  WKANRWatchdog.h — 主线程卡死检测（临时调试工具，上线前删除）

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKANRWatchdog : NSObject

+ (instancetype)shared;

/// 启动监测，threshold 秒内主线程无响应则 dump 调用栈
- (void)startWithThreshold:(NSTimeInterval)threshold;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
