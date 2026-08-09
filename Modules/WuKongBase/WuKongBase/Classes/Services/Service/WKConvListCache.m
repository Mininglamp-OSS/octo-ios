//
//  WKConvListCache.m
//  WuKongBase
//

#import "WKConvListCache.h"

/// GC 参数：每空间保留的归属条数、孤儿会话行的保留天数。
static const NSInteger kWKConvCacheKeepPerSpace = 1000;
static const NSInteger kWKConvCacheOrphanKeepDays = 30;

/// 归属索引版本。提升它会让下一次启动把整张 conversation_space 推平重建
/// （见 +prepareMembershipIfNeeded）。
///   v1：首版。会把 isConversationInCurrentSpace 的 fail-open 放行结论也写进归属，
///       导致跨空间污染被永久固化 —— 所以 v2 必须推平重建。
///   v2：推平 v1 的索引后重建。归属的判定沿用 WKConversationListVC
///       -isConversationInCurrentSpace:（**注意：它是 fail-open 的**，无 space_id 的
///       DM 会被放行）；曾经尝试过更严的"只接受正向证据"规则，但那会让 DM 整片消失，
///       已回退，见 WKConversationListVC 对应注释。残留污染由 prune/sweep 在拿到
///       负向证据后清理。
///
/// ⚠️ 灰度（见 +enabled）**关过一段时间后再打开**时，必须同时 +1 这个版本号。
/// 关闭期间所有写路径都 early-return，归属表停在关闭那一刻的快照，而读路径一旦恢复
/// 作用域过滤就会拿这批过期行去 EXISTS —— 关闭期间新增的会话全部不在表里，列表会被
/// 截断成旧快照，要等下一次权威 full sync 才补回。+1 版本号能让启动时先
/// deleteAllSpaceMembership 再按 WKLastLoadedSpaceId backfill，绕开这个空窗。
static const NSInteger kWKConvSpaceIndexVersion = 2;

/// recordMembershipBatch 的去重缓存 —— key 为 "space|type:channelId"。
/// 只读写在 gRecordedLock 保护下；applyScopeForSpace: 切换空间时整块清掉
/// （新空间的归属需要重新确认一次，而且这块内存不该无界增长）。
static NSMutableSet<NSString *> *gRecordedKeys = nil;
static NSLock *gRecordedLock = nil;
/// 校验型 sync 的重入深度（复用 gRecordedLock 保护）。见 +beginVerificationOnlySync。
static NSInteger gVerificationOnlyDepth = 0;

@implementation WKConvListCache

+ (void)initialize {
    if (self == [WKConvListCache class]) {
        gRecordedKeys = [NSMutableSet set];
        gRecordedLock = [[NSLock alloc] init];
    }
}

+ (BOOL)enabled {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"OCTO_CONV_CACHE_ENABLED"];
    if (v == nil) {
        // 默认开启。用 NSUserDefaults 或启动参数 `-OCTO_CONV_CACHE_ENABLED 0` 一键关闭。
        //
        // 已知残留风险（PR #70 review / issue #69）：`conversation` 表主键只有
        // (channel_id, channel_type)，`unread_count` 是单行共享的，所以"同一个 channel 属于
        // 两个空间"时两边读到同一个 unread。
        //
        // 为什么判断这个风险可接受：
        //   - 唯一有依据的多对多场景是**外部群**（见 202608051200.sql 注释：以 external
        //     member 身份加入别的空间的群，会同时在两个空间可见）。而外部群在两个空间里是
        //     同一个群会话，"我在这个群的未读"本来就是一个数 —— 共享 unread_count 是
        //     **正确行为，不是泄漏**。
        //   - 要真出问题，需要"未加前缀的 DM 同时出现在两个空间的 sync 响应里、且服务端对
        //     它给出不同的 unread"。这个场景不在迁移注释里，也**尚未在真机 / 后端上验证过**。
        //
        // 偏差方向（万一发生）：已读水位夹取只把 unread 往 0 压、不会往上抬 → 表现是
        // **漏红点**（用户以为没消息），不是虚报。等真实用户反馈再处理。
        //
        // 真要复核 / 修，两条路子：
        //   1. 真机确认实际重叠的是什么类型：
        //        select channel_id, channel_type, count(distinct space_id) c
        //        from conversation_space group by 1,2 having c > 1;
        //      只有 channel_type=2（群）→ 风险清零。
        //   2. 最小修法（**不是** conversation_space_state 大迁移）：给 conversation_space
        //      加一列 unread_count，默认 -1 = "未知，用 conversation 行的值"。权威写入点只有
        //      一处（WKDataSourceModule 遍历 syncConversationModels 的循环，那里就有
        //      m.unread），读路径本来就按 space join 这张表。没被写到的行行为与今天完全一致。
        return YES;
    }
    return [v boolValue];
}

+ (nullable NSString *)currentSpaceId {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    return spaceId.length > 0 ? spaceId : nil;
}

+ (void)applyScopeForSpace:(nullable NSString *)spaceId {
    [gRecordedLock lock];
    [gRecordedKeys removeAllObjects];
    [gRecordedLock unlock];
    if (![self enabled]) {
        // 关闭时把作用域清空 —— 读路径回到"DB 里的会话全都算当前空间"的老语义，
        // 配合调用点保留的 deleteAllConversation 就是完整的现网行为。
        [[WKSDK shared].conversationManager setSpaceScope:nil];
        return;
    }
    [[WKSDK shared].conversationManager setSpaceScope:spaceId.length > 0 ? spaceId : nil];
}

+ (void)applyMembership:(NSArray<WKChannel *> *)channels
               forSpace:(nullable NSString *)spaceId
               fullSync:(BOOL)fullSync {
    if (![self enabled]) return;
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return;
    if (fullSync) {
        // 全量覆盖会把不在响应里的旧归属清掉。去重缓存必须一起清 —— 否则某个被
        // tombstone 掉的 channel 后续再来实时消息时会被 "已记录" 误判而不再落库。
        [gRecordedLock lock];
        [gRecordedKeys removeAllObjects];
        [gRecordedLock unlock];
    }
    [[WKSDK shared].conversationManager applySpaceMembership:channels ?: @[] forSpace:sid fullSync:fullSync];
}

+ (void)recordMembership:(WKChannel *)channel forSpace:(nullable NSString *)spaceId {
    if (![self enabled]) return;
    if (!channel || channel.channelId.length == 0) return;
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return;
    [[WKSDK shared].conversationManager addSpaceMembership:channel forSpace:sid];
    [gRecordedLock lock];
    [gRecordedKeys addObject:[self recordKeyForChannel:channel space:sid]];
    [gRecordedLock unlock];
}

+ (NSString *)recordKeyForChannel:(WKChannel *)channel space:(NSString *)spaceId {
    return [NSString stringWithFormat:@"%@|%d:%@", spaceId, channel.channelType, channel.channelId];
}

+ (void)recordMembershipBatch:(NSArray<WKChannel *> *)channels forSpace:(nullable NSString *)spaceId {
    [self recordMembershipBatch:channels forSpace:spaceId synchronous:NO];
}

+ (void)recordMembershipBatch:(NSArray<WKChannel *> *)channels
                     forSpace:(nullable NSString *)spaceId
                  synchronous:(BOOL)synchronous {
    if (![self enabled] || channels.count == 0) return;
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return;

    NSMutableArray<WKChannel *> *pending = [NSMutableArray array];
    [gRecordedLock lock];
    for (WKChannel *ch in channels) {
        if (ch.channelId.length == 0) continue;
        NSString *key = [self recordKeyForChannel:ch space:sid];
        if ([gRecordedKeys containsObject:key]) continue;
        [gRecordedKeys addObject:key];
        [pending addObject:ch];
    }
    [gRecordedLock unlock];
    if (pending.count == 0) return;

    if (synchronous) {
        [[WKSDK shared].conversationManager applySpaceMembership:pending forSpace:sid fullSync:NO];
        return;
    }
    // 后台批量写：调用点是 onConversationUpdate（主线程、可能高频），不能在那里开事务。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[WKSDK shared].conversationManager applySpaceMembership:pending forSpace:sid fullSync:NO];
    });
}

#pragma mark - 校验型 sync 标记

+ (void)beginVerificationOnlySync {
    [gRecordedLock lock];
    gVerificationOnlyDepth += 1;
    [gRecordedLock unlock];
}

+ (void)endVerificationOnlySync {
    [gRecordedLock lock];
    if (gVerificationOnlyDepth > 0) gVerificationOnlyDepth -= 1;
    [gRecordedLock unlock];
}

+ (BOOL)isVerificationOnlySync {
    [gRecordedLock lock];
    BOOL v = gVerificationOnlyDepth > 0;
    [gRecordedLock unlock];
    return v;
}

+ (NSSet<NSString *> *)channelIdsForSpace:(nullable NSString *)spaceId channelType:(uint8_t)channelType {
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return [NSSet set];
    return [[WKSDK shared].conversationManager spaceChannelIdsForSpace:sid channelType:channelType];
}

+ (BOOL)hasMembership {
    if (![self enabled]) return NO;
    return [[WKSDK shared].conversationManager hasSpaceMembership];
}

+ (BOOL)hasMembershipForSpace:(nullable NSString *)spaceId {
    if (![self enabled]) return NO;
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return NO;
    return [[WKSDK shared].conversationManager hasSpaceMembershipForSpace:sid];
}

+ (void)removeMembership:(NSArray<WKChannel *> *)channels forSpace:(nullable NSString *)spaceId {
    if (![self enabled] || channels.count == 0) return;
    NSString *sid = spaceId.length > 0 ? spaceId : [self currentSpaceId];
    if (sid.length == 0) return;
    [[WKSDK shared].conversationManager removeSpaceMembership:channels forSpace:sid];
    // 去重缓存里对应的键也要清掉，否则这些 channel 后续再来实时消息时会被
    // "已记录" 误判而不再落库（即便它之后真的被判定属于本空间）。
    [gRecordedLock lock];
    for (WKChannel *ch in channels) {
        if (ch.channelId.length == 0) continue;
        [gRecordedKeys removeObject:[self recordKeyForChannel:ch space:sid]];
    }
    [gRecordedLock unlock];
}

+ (void)prepareMembershipIfNeeded {
    if (![self enabled]) return;
    static NSString * const kVersionKey = @"OCTO_CONV_SPACE_INDEX_VERSION";
    // v1 那一版没有版本号，只写了一个 BOOL 完成标记。不认它的话，真正需要推平重建的
    // 用户（跑过 v1、索引里已经混入 fail-open 结论）反而不会触发重建。
    static NSString * const kV1DoneKey = @"OCTO_CONV_SPACE_LEGACY_BACKFILL_DONE";
    NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:kVersionKey];
    if (stored == 0 && [[NSUserDefaults standardUserDefaults] boolForKey:kV1DoneKey]) {
        stored = 1;
    }
    if (stored >= kWKConvSpaceIndexVersion) return;

    // 归属的空间取"老版本最后一次加载的空间"：老代码在 loadCurrentSpace /
    // performSwitchToSpaceId 里每次都写 WKLastLoadedSpaceId，且写之前刚清过库，
    // 所以 DB 里现存的行就是这个空间的。它缺失时退回 currentSpaceId。
    NSString *legacySpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"WKLastLoadedSpaceId"];
    if (legacySpaceId.length == 0) {
        legacySpaceId = [self currentSpaceId];
    }
    if (legacySpaceId.length == 0) {
        // 还没有空间上下文（未登录 / 空间引导未完成）→ 不落版本号，下次启动再来。
        // 这里返回前不能清表：没有可归属的空间，清了就纯粹是数据损失。
        return;
    }

    if (stored > 0) {
        // 已经存在旧版本的归属索引 —— 它可能是被写坏的（v1 会把 fail-open 的放行结论
        // 当成归属写进来，导致跨空间污染固化）。与其带着脏数据自愈，直接推平重建：
        // 各空间退回"从未同步过"，第一次进入时列表为空、sync 回来即重建。
        NSLog(@"[SpaceIndex] 归属索引版本 %ld → %ld，推平重建",
              (long)stored, (long)kWKConvSpaceIndexVersion);
        [[WKSDK shared].conversationManager deleteAllSpaceMembership];
    }

    [[WKSDK shared].conversationManager backfillSpaceMembershipFromExistingConversationsForSpace:legacySpaceId];
    [[NSUserDefaults standardUserDefaults] setInteger:kWKConvSpaceIndexVersion forKey:kVersionKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kV1DoneKey]; // 已被版本号取代
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)runGarbageCollectionIfNeeded {
    if (![self enabled]) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            // 归属表为空时**绝对不能**跑 GC：GC 删的是"不属于任何空间的会话行"，
            // 表为空意味着每一行都符合这个条件 —— 会把整个缓存清光，正好是本次
            // 改造要避免的事。表为空只说明"第一次全量 sync 还没落地"（老版本升级
            // 上来的首次启动 / 弱网），等下次启动再 GC 即可。
            if (![[WKConversationSpaceDB shared] hasAnyMembership]) {
                NSLog(@"[SpaceIndex] GC 跳过：归属表为空（首次 sync 尚未落地）");
                return;
            }
            // 归属先裁再清孤儿：裁剪产出的"无归属会话行"这一轮就能被回收。
            [[WKConversationSpaceDB shared] gcTrimMembershipPerSpaceKeep:kWKConvCacheKeepPerSpace];
            // last_msg_timestamp 单位是秒（对齐 WKMessage.timestamp）
            NSInteger cutoff = (NSInteger)[[NSDate date] timeIntervalSince1970]
                                - kWKConvCacheOrphanKeepDays * 24 * 3600;
            [[WKConversationSpaceDB shared] gcOrphanConversationsBefore:cutoff];
        });
    });
}

@end
