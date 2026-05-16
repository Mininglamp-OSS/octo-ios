// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceModel.h
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import <Foundation/Foundation.h>
#import "WKSpaceEntity.h"
#import <PromiseKit/PromiseKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceModel : NSObject

+ (instancetype)shared;

// 获取我的所有 Space
- (AnyPromise *)getMySpaces;

// 创建 Space
- (AnyPromise *)createSpaceWithName:(NSString *)name description:(NSString *)desc;

// 获取 Space 详情
- (AnyPromise *)getSpaceDetail:(NSString *)spaceId;

// 获取 Space 成员列表
- (AnyPromise *)getMembers:(NSString *)spaceId;

// 创建邀请码
- (AnyPromise *)createInvite:(NSString *)spaceId;

// 加入 Space
- (AnyPromise *)joinSpace:(NSString *)inviteCode;

// 离开 Space
- (AnyPromise *)leaveSpace:(NSString *)spaceId;

// 解散 Space
- (AnyPromise *)disbandSpace:(NSString *)spaceId;

// 移除成员
- (AnyPromise *)removeMembers:(NSString *)spaceId uids:(NSArray<NSString *> *)uids;

// 修改成员角色
- (AnyPromise *)changeMemberRole:(NSString *)spaceId uid:(NSString *)uid role:(NSInteger)role;

// 清除缓存
- (void)invalidateCache;

@end

NS_ASSUME_NONNULL_END
