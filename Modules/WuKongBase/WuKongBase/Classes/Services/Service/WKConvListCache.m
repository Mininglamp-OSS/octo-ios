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
///   v2：归属只接受"正向证据"（见 WKConversationListVC.isConversationPositivelyInSpace:）。
///
/// ⚠️ **重新打开灰度（见 +enabled）时必须同时 +1 这个版本号。**
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
        // 1.0.3 默认**关闭**（PR #70 review 结论，见 issue #69）。
        //
        // 为什么关：`conversation` 表主键只有 (channel_id, channel_type)，unread_count /
        // last_client_msg_no / is_deleted 是单行共享的。同一个 DM 同属 Space A/B 时两边
        // 互相覆盖 unread，而 loadConversationList 的已读水位夹取只把 unread 往 0 压、
        // 不会往上抬 —— 所以偏差方向是**漏红点**（用户以为没消息），增量 sync 下还可能
        // 长时间不回正。旧实现每次切空间 deleteAllConversation 把这个建模缺口掩盖了，
        // 停止清库之后它就暴露出来。
        // 缓存是体验优化（进空间先看到上次的列表），漏红点是功能正确性，两者不该在同一个
        // release 里对赌 —— 所以先关，等 conversation_space_state 把"会话状态"从
        // "会话身份"里拆出来（issue #69）之后再开。
        //
        // 关闭后的行为已逐条核过 = 现网行为：applyScopeForSpace: 在关闭时把 SDK 作用域
        // 置 nil（读路径回到 SQL_ALL 不过滤），loadCurrentSpace / performSwitchToSpaceId
        // 走 reset + deleteAllConversation 的 else 分支；viewDidLoad 里 loadCurrentSpace
        // 在 loadConversationList 之前、且 deleteAllConversation 是同步的，所以第一帧
        // 不会漏出上个版本留在库里的多空间会话。
        // 代价：切空间 / 冷启动换空间先空一下等 sync（断网是空白页），关注 tab 的分组 +
        // 关注集合磁盘缓存也一起关（同一个 flag，见 WKCategoryService / WKFollowedKeysStore）。
        //
        // ⚠️ 重新打开时必须同时 +1 kWKConvSpaceIndexVersion，理由见那里的注释。
        return NO;
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
