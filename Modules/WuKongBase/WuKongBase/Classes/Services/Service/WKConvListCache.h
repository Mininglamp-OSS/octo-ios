//
//  WKConvListCache.h
//  WuKongBase
//
//  会话列表「每空间持久缓存」的统一门面 + 灰度开关。
//
//  背景：冷启动 / 切空间原先都会 `deleteAllConversation` + `VM reset`，把本来就存在的
//  本地缓存（SDK 会话 DB）整个清掉再等 sync 回灌 —— 列表先空一下再填，断网时甚至全空。
//  清库的唯一理由是"群聊消息不带 space_id，无法判断会话属于哪个空间"，于是用清库来替代
//  归属信息。把归属落成 conversation_space 表（见 WKConversationSpaceDB）之后，DB 可以
//  同时持有多个空间的会话，读路径按空间作用域过滤即可，不必清库。
//
//  这个类只做三件事：
//    1. 灰度开关 —— 关掉后所有调用点回到"清库 + 等 sync"的老行为。
//    2. 作用域切换 —— 启动 / 切空间时把 WKConversationDB 的作用域指到目标空间。
//    3. 归属写入的统一入口 —— 让散落在 sync / 实时更新 / 白名单三处的调用点保持干净。
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConvListCache : NSObject

/// 灰度开关（默认开启）。用 NSUserDefaults 或启动参数 `-OCTO_CONV_CACHE_ENABLED 0`
/// 一键关闭 → 恢复"冷启动/切空间清库 + 等 sync"的现网行为，用于线上应急回退。
+ (BOOL)enabled;

/// 当前空间 id（NSUserDefaults 的 currentSpaceId），可能为空。
+ (nullable NSString *)currentSpaceId;

/// 把会话读路径的空间作用域切到 spaceId。开关关闭时无操作（作用域置空 = 老行为）。
/// 启动、切空间都要调；必须在任何 loadConversationList 之前。
+ (void)applyScopeForSpace:(nullable NSString *)spaceId;

/// 记录一批会话归属于某空间。
/// fullSync=YES 只能用于 version=0 的 conversation/sync 响应（该空间的完整会话集），
/// 会覆盖式写入，不在集合里的旧归属被清掉 —— 退群 / 删会话 / 被移出的自愈路径。
+ (void)applyMembership:(NSArray<WKChannel *> *)channels
               forSpace:(nullable NSString *)spaceId
               fullSync:(BOOL)fullSync;

/// 单条归属补充（实时会话更新判定通过 / 建群进群白名单）。spaceId 传 nil 时取当前空间。
+ (void)recordMembership:(WKChannel *)channel forSpace:(nullable NSString *)spaceId;

/// 批量版本，给实时更新这类高频路径用：
///   - 按 (space, channel) 在内存里去重，同一 channel 反复来消息不会每次都写 DB；
///   - 真正需要写的部分放到后台队列做一次批量事务，不阻塞主线程。
/// 去重缓存在 applyScopeForSpace: 切换作用域时清空。
+ (void)recordMembershipBatch:(NSArray<WKChannel *> *)channels forSpace:(nullable NSString *)spaceId;

/// 同上，但可要求同步写完再返回。
/// App 进后台时必须用同步版本：异步写有可能还没执行进程就被挂起，那一刻恰好是
/// "用户最后看到的列表"最需要被记下来的时候。
+ (void)recordMembershipBatch:(NSArray<WKChannel *> *)channels
                     forSpace:(nullable NSString *)spaceId
                  synchronous:(BOOL)synchronous;

#pragma mark - 校验型 sync 标记

/// 「这次 conversation/sync 只是用来核验，不代表状态同步」。
///
/// 背景：`WKConversationListVC.verifyAndAddGroupsToList:` 会用 `provider(0, @"")` 拉一份
/// 当前空间的会话集来核验"某个未知群是否属于本空间"。它的 version 也是 0，如果按
/// "version==0 即权威全量"处理就会触发覆盖式归属写入 —— 而这个调用在收到未知群消息时
/// 就会触发（很高频），响应一旦有任何缩水，归属就被截断，表现为下次冷启动列表只剩系统
/// bot。所以核验期间强制降级为"只补充不删除"。
///
/// 计数式（可重入）。与真实 sync 并发时最坏结果是"少做一次 tombstone"（良性），
/// 而不是"把归属删空"（致命），方向上是安全的。
+ (void)beginVerificationOnlySync;
+ (void)endVerificationOnlySync;
+ (BOOL)isVerificationOnlySync;

/// 某空间下指定 channelType 的 channelId 集合，供 VM 水化空间白名单。
+ (NSSet<NSString *> *)channelIdsForSpace:(nullable NSString *)spaceId channelType:(uint8_t)channelType;

/// 归属表是否已有数据（仅诊断用，作用域不再依赖它）。
+ (BOOL)hasMembership;

/// 指定空间是否已有归属数据（= 至少被完整同步过一次）。
/// VM 用它区分「这个空间从没进过 → 白名单按未初始化处理，保持首次 sync 前不过滤的语义」
/// 与「这个空间有缓存 → 白名单严格生效」。
+ (BOOL)hasMembershipForSpace:(nullable NSString *)spaceId;

/// 明确判定某些 channel 不属于该空间时删掉归属（prune / sweep 的自愈路径）。
/// 归属写错过一次就会一直挂着，必须给它一条纠正通道。
+ (void)removeMembership:(NSArray<WKChannel *> *)channels forSpace:(nullable NSString *)spaceId;

/// 归属索引的一次性准备 / 重建（按版本号驱动，幂等，任何读之前调用）。
///
/// 做两件事：
/// 1. **回填**：把 conversation 表现有的行归属到"老版本最后一次加载的空间"
///    （WKLastLoadedSpaceId，缺失时退回 currentSpaceId）。老版本靠「清库 + 全量 sync」
///    保证 DB 只含当前空间的会话，升级那一刻 DB 里的行确实都属于那个空间。
///    没有这次回填，归属表会存在"整表为空"的状态，而那个状态下读路径只能选择
///    "不过滤"（漏出所有空间 = 用户实测到的跨空间污染）或"全过滤"（列表空白）。
/// 2. **重建**：存储的索引版本低于当前版本时，先把整张归属表清空再回填。
///    用于"上一版把 fail-open 结论写进了归属、索引可能已脏"的场景 —— 与其带着脏数据
///    自愈，不如一次性推平，让各空间的 sync 重新建立归属。代价是每个空间第一次进入
///    时列表为空（等同清库时代的行为），换来绝不继承脏归属。
///
/// 提升 kWKConvSpaceIndexVersion 即可在下个版本再强制重建一次。
+ (void)prepareMembershipIfNeeded;

/// 有界化：DB 不再被清空后需要 GC。冷启动后延迟在后台跑一次即可（内部自带单次闸门）。
///   - 清掉没有对应会话行的孤儿归属
///   - 每空间只保留最近 1000 条归属
///   - 物理删除"不属于任何空间且 30 天没动静"的会话行
+ (void)runGarbageCollectionIfNeeded;

@end

NS_ASSUME_NONNULL_END
