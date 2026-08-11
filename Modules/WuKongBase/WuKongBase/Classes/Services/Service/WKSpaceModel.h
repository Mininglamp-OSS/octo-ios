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
// 内存缓存 → 网络。网络失败且无内存缓存时，回落到磁盘缓存（断网也能拿到上次的列表）；
// 磁盘也没有才抛错。
- (AnyPromise *)getMySpaces;

/// 同步读磁盘缓存里某个 Space 的名字，没有返回 nil。
///
/// 为什么需要：会话列表的标题来自 `space/my` 这个**纯网络**接口，断网冷启动时它失败 →
/// currentSpaceName 为空 → 标题回退成 appName（"Octo"），用户看起来像"空间被切走了"。
/// 有了这个同步入口，标题第一帧就能显示上次的空间名。
- (nullable NSString *)cachedSpaceNameForSpaceId:(NSString *)spaceId;

/// 同步读磁盘缓存的 Space 列表，没有返回 nil。
- (nullable NSArray<WKSpaceEntity *> *)cachedSpacesFromDisk;

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
