//
//  WKConvListCache.m
//  WuKongBase
//

#import "WKConvListCache.h"
#import "WKLoginInfo.h"   // 账号闸门用（见 recordMembershipBatch:）


/// 归属索引版本。提升它会让下一次启动把整张 conversation_space 推平重建
/// （见 +prepareMembershipIfNeeded）。
///   v1：首版。会把 isConversationInCurrentSpace 的 fail-open 放行结论也写进归属，
///       导致跨空间污染被永久固化 —— 所以 v2 必须推平重建。
///   v3：**修 fe27bc3 造成的串空间事故**。v3 之前这里会跑一次"整张 conversation 表
///       无条件归给 WKLastLoadedSpaceId"的回填(backfillMembershipFromExistingConversations)。
///       它的前提是"老版本靠清库保证 DB 只有一个空间的会话"—— 那**只对 1.0.2 → 1.0.3
///       的那一次升级成立**。本 PR 取消清库之后，库里会合法地存着多个空间的会话，
///       此时再跑回填就是把所有空间的会话归给一个空间 = 列表串空间，且因为
///       hydrateSpaceScope: 的群白名单是从归属表水化的，别的空间会缺群 → 那些群的
///       子区被过滤 → 子区预览也空掉。
///       所以 v3 = 推平归属 + **不再回填**，交给权威全量 sync 重建
///       （冷启动首次 sync 强制 version=0，见 WKConnectionManager coldStartSyncDone →
///       applyMembership(fullSync=YES) → replaceMembership 按空间精确重建）。
///       代价：本版第一次启动时列表要等那次 sync 才出内容（断网则为空），仅一次。
///       这个代价换的是"绝不会把 A 的会话归到 B"，方向不能反。
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
/// deleteAllSpaceMembership 推平重建，绕开这个空窗。
/// ⚠️ **不要**在这里恢复"按 WKLastLoadedSpaceId 整表回填" —— 那正是 8431d8e 修掉的串空间
/// 成因（整表归一个空间）。推平之后归属由权威全量 sync 逐空间重建，代价是那次启动列表要
/// 等 sync（断网则空），仅一次。
static const NSInteger kWKConvSpaceIndexVersion = 3;

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
    // 账号闸门：applySpaceMembership: 在 block 执行时才解析 [WKDB sharedDB].dbQueue，而
    // switchDB: 会把该单例重定向到新账号的库。排队期间登出/登录，这批归属就会写进新账号
    // 的库里（与 conversation/sync 那条同类，见 WKDataSourceModule 的账号闸门注释）。
    // 丢弃安全：归属会在下一次会话更新 / 冷启动全量 sync 时重新落库。
    NSString *uidAtEnqueue = [WKLoginInfo shared].uid;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *uidNow = [WKLoginInfo shared].uid;
        if (!(uidAtEnqueue == uidNow || [uidAtEnqueue isEqualToString:uidNow])) {
            NSLog(@"[SpaceIndex] 丢弃归属批量写：账号已切换 %@ → %@", uidAtEnqueue ?: @"<nil>", uidNow ?: @"<nil>");
            return;
        }
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
    // 键必须按 uid 隔离 (@yujiawei P1-4): NSUserDefaults 是 App 级的, 而
    // conversation_space 活在 WKDB.switchDB: 会整体换掉的 per-uid 库里, 且
    // prepareMembershipIfNeeded 恰好就跑在换库那条路径上 (WKApp 的 LOGIN_SUCCESS)。
    // 不隔离的后果: 同设备两个账号都从老版本升上来 —— A 先启动跑完回填、把版本号写成 2,
    // 切到 B 时 `stored >= 2` 直接 return, B 的库永远不会被回填。而读路径**故意没有**
    // "归属表为空就不过滤"的兜底(WKConversationDB.m:134 的注释明确禁止), 于是 B 的
    // getConversationList 会一直返回空数组, 断网时永久空列表。
    NSString *uid = [WKLoginInfo shared].uid ?: @"";
    NSString *kVersionKey = [NSString stringWithFormat:@"OCTO_CONV_SPACE_INDEX_VERSION_%@", uid];
    // v1 那一版没有版本号，只写了一个 BOOL 完成标记。不认它的话，真正需要推平重建的
    // 用户（跑过 v1、索引里已经混入 fail-open 结论）反而不会触发重建。
    // 注: v1 那个键当年是不带 uid 的, 这里也按 uid 读 —— 读不到就当没跑过 v1,
    // 走一次干净的 v2 回填, 结果一致(v2 本身就要推平重建)。
    NSString *kV1DoneKey = [NSString stringWithFormat:@"OCTO_CONV_SPACE_LEGACY_BACKFILL_DONE_%@", uid];
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
        // 这里返回前不能清表：连当前空间都不知道，清了之后连"哪个空间该重建"都无从谈起。
        return;
    }

    // 一律推平（不再区分 stored > 0）：
    //   - v1 的索引混入过 fail-open 结论；
    //   - v2 期间可能已被那次"整表归一个空间"的回填写脏（fe27bc3 事故）。
    // 两种都只能推平重来，没有可自愈的中间态。
    NSLog(@"[SpaceIndex] 归属索引版本 %ld → %ld，推平重建（不回填，交给权威全量 sync）",
          (long)stored, (long)kWKConvSpaceIndexVersion);
    // 只有推平**确实成功**才盖版本号（@yujiawei round-11 P2-1）：删除失败（库被锁 / 磁盘
    // 压力）却把版本号盖上去的话，`stored >= 版本` 会让以后每次启动都短路，用户就被永久
    // 钉在这个迁移要逃离的那个脏索引状态上 —— 这是整个改动里唯一不可自愈的失败模式。
    // 失败就不盖章，下次启动重试。
    if(![[WKSDK shared].conversationManager deleteAllSpaceMembership]) {
        NSLog(@"[SpaceIndex] 推平归属失败，不盖版本号，下次启动重试");
        return;
    }

    // ⚠️ **不要**在这里调 backfillSpaceMembershipFromExistingConversationsForSpace:。
    // 那个回填是"整张 conversation 表无条件归给一个空间"，只在"库里确定只有一个空间的
    // 会话"时才成立 —— 本 PR 取消清库之后这个前提永远不再成立，跑它就是串空间。
    // 归属改由权威全量 sync 建立：冷启动首次 sync 强制 version=0
    // （WKConnectionManager coldStartSyncDone）→ applyMembership(fullSync=YES) →
    // replaceMembership 按 space_id 精确重建。
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
            // ⚠️ **不再清"孤儿会话行"**（@yujiawei round-11 P1）。
            //
            // gcOrphanConversationsBefore: 删的是 `not exists(归属) 且 30 天没动静` 的
            // conversation 行。它的安全前提是"归属表覆盖了库里所有该保留的会话"——
            // 这个前提由那次"整表回填"提供，而 8431d8e 已经把回填删掉了（它导致串空间）。
            //
            // 现在的实际状态：v3 推平全部归属后，冷启动的强制全量 sync **只重建当前空间**
            // （applyMembership → replaceMembership 是 forSpace:sid）。于是别的空间的会话
            // 一行归属都没有 → 全部符合"孤儿"条件 → 30 天以上的会被**物理删除**。
            // 而守卫 hasAnyMembership 是**全局**的（当前空间一有归属它就为真），挡不住。
            //
            // 为什么不用"这次启动做过迁移就跳过 GC"的标志（reviewer 建议的最小修法）：
            // 那只把问题推迟一次启动 —— 未访问过的空间在被访问前归属一直是空的，
            // 下一次启动 hasAnyMembership 仍为真，照样删。要真正判定安全，得知道
            // "库里每个空间都已被权威重建过"，而这个信息现在拿不到。
            //
            // 所以直接去掉这个破坏性操作：有界化只保留 gcDanglingMembership（删的是
            // 指不到任何活着会话行的归属，肉眼不可见的死数据，不可能删掉用户内容）。
            // 代价是"再也不会被访问的空间"的 conversation 行会长期留着 —— 一行几十字节
            // 的元数据，message 表本来也不由这条路径清理，与"静默删除用户本地缓存"
            // 相比这个代价可以忽略。
            // 什么时候能恢复：能按空间判定"归属已被权威重建"之后（见 issue #69）。
            [[WKConversationSpaceDB shared] gcDanglingMembership];
        });
    });
}

@end
