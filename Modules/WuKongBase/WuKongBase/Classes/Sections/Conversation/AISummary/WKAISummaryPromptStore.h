// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryPromptStore.h
//  WuKongBase
//
//  AI 一键总结的本地持久化：
//    - customPrompt：用户自定义提示词（按 channel 隔离）
//    - lastRange：上次选过的时间档位（按 channel 隔离），下次打开菜单时作为默认高亮
//
//  channel 隔离粒度：channelType + channelId（群和子区天然不同 key）。
//  存储位置：NSUserDefaults，单 key 下挂一个 NSDictionary。
//

#import <Foundation/Foundation.h>
@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

@interface WKAISummaryPromptStore : NSObject

#pragma mark - 自定义提示词

/// 取该 channel 的自定义提示词；nil 或空字符串都视作"未设置"。
+ (nullable NSString *)customPromptForChannel:(WKChannel *)channel;

/// 保存自定义提示词；传 nil 或空字符串等同于删除。
+ (void)saveCustomPrompt:(nullable NSString *)prompt forChannel:(WKChannel *)channel;

/// 是否有有效自定义提示词
+ (BOOL)hasCustomPromptForChannel:(WKChannel *)channel;

#pragma mark - 上次选的时间档位

/// 取上次保存的时间档位；返回 0 表示"未保存过"，调用方应自行 fallback（未读 / 1 天）。
+ (NSInteger)lastRangeForChannel:(WKChannel *)channel;

/// 保存上次选过的时间档位（秒数；调用方约定 0=未读 / NSIntegerMax=全部 / 86400=1 天 等）。
+ (void)saveLastRange:(NSInteger)range forChannel:(WKChannel *)channel;

@end

NS_ASSUME_NONNULL_END
