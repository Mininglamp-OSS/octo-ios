// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowedKeysStore.m
//  WuKongBase
//

#import "WKFollowedKeysStore.h"
#import "WKSidebarService.h"
#import "WKLoginInfo.h"

NSNotificationName const kWKFollowedKeysStoreDidUpdateNotification = @"kWKFollowedKeysStoreDidUpdateNotification";

@interface WKFollowedKeysStore ()
@property (atomic, assign, readwrite) BOOL loaded;
@property (atomic, assign, readwrite) NSInteger followVersion;
@property (atomic, strong, readwrite) NSSet<NSString *> *followedKeys;
@property (atomic, strong, readwrite) NSDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *itemsByCategory;
@property (atomic, strong, readwrite) NSSet<NSString *> *followedGroupNos;
@property (atomic, assign) BOOL retryScheduled;
/// 切 Space / 切账号会调 reset，但 reload 是异步的，旧 Space 在飞的请求若 reset
/// 之后才回包，applyItems: 会拿旧 Space 的数据覆盖刚 reset 完的状态 —— 破坏空间
/// 隔离，Follow tab 看到上一个 Space 的关注项（PR review #12 critical）。
/// generation 在每次 reset 时 +1，reload 在发起时捕获 myGen，then/catch/retry
/// 三条回调路径全部先比对 myGen == 当前 generation，不匹配就静默丢弃。
@property (atomic, assign) NSInteger generation;
@end

@implementation WKFollowedKeysStore

+ (instancetype)shared {
    static WKFollowedKeysStore *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKFollowedKeysStore alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _followVersion = 0;
        _followedKeys = [NSSet set];
        _itemsByCategory = @{};
        _followedGroupNos = [NSSet set];
    }
    return self;
}

#pragma mark - Query

- (BOOL)isFollowedWithType:(WKFollowTargetType)type targetId:(NSString *)targetId {
    if (targetId.length == 0) return NO;
    NSString *key = [NSString stringWithFormat:@"%ld::%@", (long)type, targetId];
    return [self.followedKeys containsObject:key];
}

#pragma mark - Mutators

- (void)bumpVersion {
    self.followVersion = self.followVersion + 1;
}

- (AnyPromise *)reload {
    NSString *deviceUUID = [WKLoginInfo shared].deviceUUID ?: @"";
    // 捕获本次 reload 发起时的 generation；reset 期间 +1，回包时 mismatch 就丢弃
    NSInteger myGen = self.generation;
    return [[WKSidebarService shared] syncWithTab:WKSidebarTabFollow
                                          version:0
                                      lastMsgSeqs:@""
                                       deviceUUID:deviceUUID].then(^(WKSidebarSyncResponse *resp) {
        if (myGen != self.generation) {
            // 切 Space / reset 已发生，旧 Space 的响应不允许污染当前状态
            return (id)nil;
        }
        [self applyItems:resp.items followVersion:resp.follow_version];
        return (id)nil;
    }).catch(^(NSError *error) {
        if (myGen != self.generation) return; // 同上：旧 gen 的失败也不通知/重试
        // 失败也通知 — 让观察者有机会切回兜底状态/重试
        [[NSNotificationCenter defaultCenter] postNotificationName:kWKFollowedKeysStoreDidUpdateNotification
                                                            object:self
                                                          userInfo:@{ @"error": error ?: [NSNull null] }];
        // 单次 5s 延迟兜底重试（不做无限循环）：避免单次网络抖动把用户卡到下次
        // viewDidAppear 的 30s debounce 才能恢复 — 这种情况下用户视角是"分组下面
        // 一直没有会话"。重试只跑一次，再失败就交给上层定时刷新链路。
        if (!self.retryScheduled) {
            self.retryScheduled = YES;
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.retryScheduled = NO;
                if (myGen != strongSelf.generation) return; // reset 后旧 gen 的 retry 也丢
                if (strongSelf.loaded) return; // 期间被别的路径成功 reload 过了，不再重试
                [strongSelf reload];
            });
        }
    });
}

- (void)reset {
    // 先 +1 generation：所有 myGen == 旧值的在飞 reload 回包都会被 then/catch/retry
    // 三条路径上的 generation 校验丢弃，状态清零之后不会被旧 Space 数据再覆盖
    self.generation = self.generation + 1;
    self.followedKeys = [NSSet set];
    self.followedGroupNos = [NSSet set];
    self.itemsByCategory = @{};
    self.followVersion = 0;
    self.loaded = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:kWKFollowedKeysStoreDidUpdateNotification
                                                        object:self
                                                      userInfo:@{ @"reset": @YES }];
}

- (void)applyItems:(NSArray<WKSidebarItemEntity *> *)items followVersion:(NSInteger)version {
    NSMutableSet<NSString *> *keys = [NSMutableSet setWithCapacity:items.count];
    NSMutableSet<NSString *> *groupNos = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSMutableArray<WKSidebarItemEntity *> *> *buckets = [NSMutableDictionary dictionary];

    for (WKSidebarItemEntity *it in items) {
        if (it.target_id.length == 0) continue;
        // 守卫 is_followed：sidebar/sync 的 follow tab 当前只返回 followed 项，但 entity schema
        // 支持 follow/recent 共用 —— 任何 unfollowed 项混进来都不能被算成已关注（否则会污染
        // followedKeys / followedGroupNos / 桶展示，破坏菜单态、未读统计和 Follow tab 过滤）。
        if (!it.is_followed) continue;
        [keys addObject:[it followKey]];
        if (it.target_type == WKFollowTargetTypeChannel) {
            [groupNos addObject:it.target_id];
        }
        NSString *bucketKey = it.category_id ?: @"";
        NSMutableArray *bucket = buckets[bucketKey];
        if (!bucket) {
            bucket = [NSMutableArray array];
            buckets[bucketKey] = bucket;
        }
        [bucket addObject:it];
    }

    // 桶内按 follow_sort ASC，缺省值 NSIntegerMax 已在 entity 兜底
    NSMutableDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *sortedBuckets = [NSMutableDictionary dictionaryWithCapacity:buckets.count];
    [buckets enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSMutableArray<WKSidebarItemEntity *> *arr, BOOL *stop) {
        [arr sortUsingComparator:^NSComparisonResult(WKSidebarItemEntity *a, WKSidebarItemEntity *b) {
            if (a.follow_sort < b.follow_sort) return NSOrderedAscending;
            if (a.follow_sort > b.follow_sort) return NSOrderedDescending;
            // 平手按 timestamp 倒序，与最近活跃优先一致
            if (a.timestamp > b.timestamp) return NSOrderedAscending;
            if (a.timestamp < b.timestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        sortedBuckets[k] = [arr copy];
    }];

    self.followedKeys = [keys copy];
    self.followedGroupNos = [groupNos copy];
    self.itemsByCategory = [sortedBuckets copy];
    self.followVersion = version;
    self.loaded = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kWKFollowedKeysStoreDidUpdateNotification
                                                        object:self
                                                      userInfo:nil];
}

@end
