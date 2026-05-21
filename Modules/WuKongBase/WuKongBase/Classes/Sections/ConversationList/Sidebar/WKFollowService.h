// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowService.h
//  WuKongBase
//
//  关注/取消关注 + 排序。对齐 web FollowService.ts。
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import "WKSidebarItemEntity.h"   // for WKFollowTargetType

NS_ASSUME_NONNULL_BEGIN

/// follow/sort 的单条 payload
@interface WKFollowSortItem : NSObject
@property (nonatomic, assign) WKFollowTargetType target_type;
@property (nonatomic, copy)   NSString *target_id;
@property (nonatomic, assign) NSInteger sort;
- (NSDictionary *)toDict;
@end

@interface WKFollowService : NSObject

+ (instancetype)shared;

/// 关注 DM 或把已关注 DM 移到指定分组（覆盖语义）。category_id 传 nil 落到默认分组
- (AnyPromise *)followDM:(NSString *)peerUid categoryId:(nullable NSString *)categoryId;
/// 取消 DM 关注
- (AnyPromise *)unfollowDM:(NSString *)peerUid;

/// 取消群关注
- (AnyPromise *)unfollowChannel:(NSString *)groupNo;
/// 重新关注群（用于"添加到关注"流程：refollow + moveGroup 链）
- (AnyPromise *)refollowChannel:(NSString *)groupNo;

/// 关注子区。后端 cascade follow 父群
- (AnyPromise *)followThread:(NSString *)threadChannelId;
/// 取消子区关注。不动父群
- (AnyPromise *)unfollowThread:(NSString *)threadChannelId;

/// 排序。version 传当前 follow_version 做 CAS。失败时 NSError.domain 携带后端 msg。
- (AnyPromise *)sortItems:(NSArray<WKFollowSortItem *> *)items version:(NSInteger)version;

/// 判断 sort 失败的 NSError 是否是 "version conflict"
+ (BOOL)isVersionConflictError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
