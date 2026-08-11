// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKFollowedKeysStore.m
//  WuKongBase
//

#import "WKFollowedKeysStore.h"
#import "WKSidebarService.h"
#import "WKLoginInfo.h"
#import "WKSpaceDiskCache.h"
#import "WKConvListCache.h"

NSNotificationName const kWKFollowedKeysStoreDidUpdateNotification = @"kWKFollowedKeysStoreDidUpdateNotification";

/// 磁盘缓存 namespace（文件名前缀）
static NSString * const kWKFollowCacheNamespace = @"follow";

@interface WKFollowedKeysStore ()
@property (atomic, assign, readwrite) BOOL loaded;
@property (atomic, assign, readwrite) BOOL loadedFromCache;
@property (atomic, assign, readwrite) NSInteger followVersion;
@property (atomic, strong, readwrite) NSSet<NSString *> *followedKeys;
@property (atomic, strong, readwrite) NSDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *itemsByCategory;
@property (atomic, strong, readwrite) NSSet<NSString *> *followedGroupNos;
@property (atomic, assign) BOOL retryScheduled;
/// applyItems: 这一次是"磁盘缓存水化"还是"服务端最新"。
/// 必须在 applyItems: 内部 post 通知**之前**就定好 —— 观察者
/// （onFollowedKeysStoreDidUpdate → buildGroupDisplayList）会同步读 loadedFromCache
/// 决定 placeholder 的红点要不要亮，post 之后再纠正就晚了一帧。
@property (atomic, assign) BOOL applyingFromCache;
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
    self.loadedFromCache = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:kWKFollowedKeysStoreDidUpdateNotification
                                                        object:self
                                                      userInfo:@{ @"reset": @YES }];
}

#pragma mark - 每空间磁盘缓存

- (void)resetAndHydrateForSpace:(NSString *)spaceId {
    // reset 里的 generation +1 仍然是必须的：旧空间在飞的 reload 回包不能污染新空间。
    // 它同时会 post 一次 reset 通知（观察者会看到一瞬间的空态），紧接着的水化会再
    // post 一次带内容的通知，UI 以后者为准。
    [self reset];
    if (![WKConvListCache enabled]) return;
    [self hydrateForSpace:spaceId];
}

- (BOOL)hydrateForSpace:(NSString *)spaceId {
    if (![WKConvListCache enabled] || spaceId.length == 0) return NO;
    // 已经是服务端最新（fresh）就不要用缓存往回盖
    if (self.loaded && !self.loadedFromCache) return NO;

    id cached = [WKSpaceDiskCache objectForNamespace:kWKFollowCacheNamespace spaceId:spaceId];
    if (![cached isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *dict = (NSDictionary *)cached;
    NSArray *rawItems = dict[@"items"];
    if (![rawItems isKindOfClass:[NSArray class]]) return NO;

    NSArray<WKSidebarItemEntity *> *items = [WKSidebarItemEntity fromDictArray:rawItems];
    NSInteger version = [dict[@"follow_version"] integerValue];
    // 标记这一轮 applyItems: 是缓存水化：它内部据此把 loadedFromCache 置 YES 并跳过
    // 回写磁盘（数据本来就是从磁盘读的）。必须在 applyItems: 之前设，见属性注释。
    self.applyingFromCache = YES;
    [self applyItems:items followVersion:version];
    self.applyingFromCache = NO;
    NSLog(@"[FollowCache] hydrate space=%@ items=%lu version=%ld",
          spaceId, (unsigned long)items.count, (long)version);
    return items.count > 0;
}

- (void)persistForSpace:(NSString *)spaceId {
    if (![WKConvListCache enabled] || spaceId.length == 0) return;
    NSMutableArray *rawItems = [NSMutableArray array];
    [self.itemsByCategory enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSArray<WKSidebarItemEntity *> *arr, BOOL *stop) {
        for (WKSidebarItemEntity *it in arr) {
            [rawItems addObject:[it toDict]];
        }
    }];
    [WKSpaceDiskCache setObject:@{ @"items": rawItems, @"follow_version": @(self.followVersion) }
                   forNamespace:kWKFollowCacheNamespace
                        spaceId:spaceId];
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
    self.loadedFromCache = self.applyingFromCache;

    // 落盘给下次进入本空间做首帧渲染用。写在 post 通知之前，保证"UI 看到的"和
    // "缓存里的"是同一份数据；实际写文件是异步的，不阻塞主线程。
    // 缓存水化那一轮不回写（数据本来就是从磁盘读出来的）。
    if (!self.applyingFromCache) {
        NSString *spaceId = [WKConvListCache currentSpaceId];
        if (spaceId.length > 0) {
            [self persistForSpace:spaceId];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kWKFollowedKeysStoreDidUpdateNotification
                                                        object:self
                                                      userInfo:nil];
}

@end
