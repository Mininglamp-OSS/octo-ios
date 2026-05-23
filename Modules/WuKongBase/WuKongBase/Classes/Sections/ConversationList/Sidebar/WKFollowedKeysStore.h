// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowedKeysStore.h
//  WuKongBase
//
//  关注状态的唯一可信源 + follow_version CAS 锚点。
//  对齐 web useFollowSidebar：禁止从 WKChannelInfo.follow / IM cache 推断 is_followed。
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import "WKSidebarItemEntity.h"

NS_ASSUME_NONNULL_BEGIN

/// 全量 reload 完成后 post（含失败也 post，以便观察方刷新 UI）
extern NSNotificationName const kWKFollowedKeysStoreDidUpdateNotification;

@interface WKFollowedKeysStore : NSObject

+ (instancetype)shared;

/// 是否已成功完成至少一次 sidebar/sync。区分"空"与"未加载"：
/// - NO：刚初始化 / 加载失败且从未成功过 → 调用方应回退到 legacy 数据（cat.groups）
/// - YES：至少成功过一次（即便当前 followedKeys 为空也是"用户没关注东西"）→ 调用方
///   应严格按 followedKeys 渲染，空就空
@property (atomic, readonly) BOOL loaded;

/// 当前 follow_version，CAS 锚点；写请求前同步读取
@property (atomic, readonly) NSInteger followVersion;

/// 关注集合的快照（不可变）。key = "{target_type}::{target_id}"
@property (atomic, readonly) NSSet<NSString *> *followedKeys;

/// 按 category_id 分桶后的关注项，桶内已按 follow_sort ASC 排好。
/// key 为 category_id 字符串，未归类项归到 @"" 桶。
@property (atomic, readonly) NSDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *itemsByCategory;

/// 已关注群的 group_no 集合（仅 target_type=Channel 的子集）
@property (atomic, readonly) NSSet<NSString *> *followedGroupNos;

/// 同步查询：某 target 是否在关注集合内
- (BOOL)isFollowedWithType:(WKFollowTargetType)type targetId:(NSString *)targetId;

/// 全量 reload（tab=follow，version=0）。失败也会 post 通知。
/// resolve 值：成功为 nil，失败为 NSError
- (AnyPromise *)reload;

/// 切空间等场景下把状态打回"未加载"——清空 followedKeys / followedGroupNos /
/// itemsByCategory / followVersion，loaded = NO，并 post 一次更新通知。
/// fail-closed：避免上一个 Space 的 followed 数据在新 Space 的 categoryList 下
/// 形成错位/残留。调用后必须紧跟一次 reload，否则 Follow tab 会持续空白。
- (void)reset;

/// 本地写成功后调用 — followVersion += 1。
/// 用于乐观更新场景；下一次 reload 会被服务器返回的值覆盖。
- (void)bumpVersion;

#pragma mark - Internal（暴露给单测，业务方不要直接调）

/// 用一组 SidebarItem + version 直接覆盖状态。
- (void)applyItems:(NSArray<WKSidebarItemEntity *> *)items followVersion:(NSInteger)version;

@end

NS_ASSUME_NONNULL_END
