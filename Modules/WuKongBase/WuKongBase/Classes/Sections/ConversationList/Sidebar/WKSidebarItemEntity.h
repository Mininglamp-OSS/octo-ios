// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKSidebarItemEntity.h
//  WuKongBase
//
//  /v1/sidebar/sync 返回的会话项；关注 / 最近 双 tab 共用。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// follow 目标类型 — 与 web FollowService.FollowTargetType 对齐
typedef NS_ENUM(NSInteger, WKFollowTargetType) {
    WKFollowTargetTypeDM      = 1,
    WKFollowTargetTypeChannel = 2,
    WKFollowTargetTypeThread  = 5,
};

@interface WKSidebarItemEntity : NSObject

@property (nonatomic, assign) WKFollowTargetType target_type;
@property (nonatomic, copy)   NSString *target_id;
@property (nonatomic, assign) NSInteger channel_type;
@property (nonatomic, copy)   NSString *channel_id;
@property (nonatomic, assign) int64_t   timestamp;
@property (nonatomic, assign) NSInteger unread;
@property (nonatomic, assign) BOOL      is_pinned;
@property (nonatomic, assign) BOOL      is_followed;

/// nil = 未归类（"" 在 follow tab 当默认分组隐藏处理）
@property (nonatomic, copy, nullable)   NSString *category_id;
/// 后端 group_category.sort — 跨分组顺序
@property (nonatomic, assign) NSInteger category_sort;
/// 后端 group_setting.follow_sort — 桶内手工顺序；缺省用 NSIntegerMax 兜底
@property (nonatomic, assign) NSInteger follow_sort;
/// 仅 thread 有值；指向父群 channelID
@property (nonatomic, copy, nullable)   NSString *parent_channel_id;

+ (instancetype)fromDict:(NSDictionary *)dict;
+ (NSArray<WKSidebarItemEntity *> *)fromDictArray:(NSArray *)array;

/// 唯一键 — 用于 WKFollowedKeysStore，形如 "{target_type}::{target_id}"
- (NSString *)followKey;

@end

NS_ASSUME_NONNULL_END
