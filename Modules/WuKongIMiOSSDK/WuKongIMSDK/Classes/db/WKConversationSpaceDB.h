//
//  WKConversationSpaceDB.h
//  WuKongIMSDK
//
//  会话 ↔ 空间归属索引 (conversation_space 表, migration 202608051200).
//
//  为什么需要它: 群聊消息不带 space_id, 上层原先靠
//  `deleteAllConversation + 全量 sync` 来保证 "DB 里只有当前空间的会话",
//  代价是每次冷启动 / 切空间都把本地缓存丢掉, 断网时列表全空。
//  把归属落成一张索引表后, DB 可以同时持有多个空间的会话, 读路径按当前
//  空间作用域过滤 (见 WKConversationDB.spaceScopeId) 即可, 不必清库。
//
//  归属是 many-to-many: 外部群 (我以 external member 身份加入别的空间的群)
//  会同时在两个空间可见, 单值 space_id 列会判错。
//
//  归属的三个写入方 (都是上层已有的"这条会话属于哪个空间"判定点):
//    1. conversation/sync?space_id=X 的响应 —— 权威。version=0 的全量响应是该
//       空间的完整会话集, 用 replaceMembership: 覆盖(自带 tombstone, 顶替原来
//       deleteAllConversation 的自愈作用); 增量响应用 addMembership:。
//    2. 实时会话更新 —— WKConversationListVC.filterConversationsBySpace 判定通过的。
//    3. 显式白名单 —— 建群/进群 (addGroupToWhitelist) 与后台核验
//       (verifyAndAddGroupsToList)。
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import <FMDB/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationSpaceDB : NSObject
+ (instancetype) shared;

/// 全量覆盖某空间的归属集合(一个 transaction 内 delete + insert)。
/// 只应在拿到该空间的 **完整** 会话集时调用(version=0 的 conversation/sync 响应),
/// 因为不在 channels 里的旧归属会被删掉 —— 这正是退群 / 删会话 / 被移出的自愈路径。
-(void) replaceMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId;

/// 增量补充归属, 不删任何已有记录。增量 sync / 实时更新 / 白名单写入走这里。
///
/// ⚠️ 理想情况下只该用"有正向证据"的判定结果调用 —— 归属是持久的, 把一次猜测写进来就等于
/// 把跨空间污染永久固化(下次冷启动仍然认为它属于这个空间)。
/// **但当前上层实际的判定入口 WKConversationListVC -isConversationInCurrentSpace: 是
/// fail-open 的**（无 space_id 的 DM 会被放行）—— 更严的"只接受正向证据"规则试过，会让
/// DM 整片消失，已回退。所以这里会收到 fail-open 的结论，残留污染依赖 prune/sweep 在拿到
/// 负向证据后清理；对"永远拿不到负向证据"的无前缀 DM 仍是已知缺口（issue #69）。
-(void) addMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId;

/// 删除归属。用于"明确判定某 channel 不属于该空间"的自愈路径
/// (WKConversationListVM 的 pruneNonCurrentSpaceGroups / pruneNonCurrentSpaceBots /
/// sweepForeignToSpace) —— 让此前写错的归属能被纠正, 而不是一直挂着。
-(void) removeMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId;

/// 一次性迁移: 把 conversation 表里**现有**的行全部归属到 spaceId。
///
/// 为什么需要: 老版本靠 `deleteAllConversation + 全量 sync` 保证"DB 里只有当前空间的
/// 会话", 所以升级那一刻 DB 中的行确实都属于 spaceId(= 老版本最后一次加载的空间)。
/// 有了这次回填, 归属表就不会存在"整表为空"的状态, 读路径的空间作用域可以一直精确 ——
/// 否则得留一个"表空 → 不过滤"的兼容态, 而那个兼容态在"升级后首次全量 sync 落地前就
/// 切空间"时会把上一个空间的会话整片漏进新空间。
///
/// 只插入不删除, 且不覆盖已有归属。返回写入的行数。
-(NSInteger) backfillMembershipFromExistingConversationsForSpace:(NSString*)spaceId;

/// 清空整张归属表。用于"归属索引可能已被写坏"时的一次性重建
/// (见 WKConvListCache.prepareMembershipIfNeeded)。
/// 清完后各空间会退回"从未同步过"状态: 第一次进入时列表为空 → sync 回来后重建,
/// 与清库时代的行为一致, 代价是一次性的首帧空列表, 换来"绝不继承脏归属"。
-(void) deleteAllMembership;

/// 某空间下指定 channelType 的 channelId 集合。上层用它水化
/// WKConversationListVM.syncedGroupChannelIds, 让空间白名单从第一帧起就非 nil。
-(NSSet<NSString*>*) channelIdsForSpace:(NSString*)spaceId channelType:(uint8_t)channelType;

/// 某空间下所有归属(不分 channelType), key 为 "channelType:channelId"。
-(NSSet<NSString*>*) channelKeysForSpace:(NSString*)spaceId;

/// 表里是否有任何归属记录。
/// 仅用于日志 / 诊断。**不要**再用它当"作用域是否生效"的判据 —— 那个"表空就不过滤"的
/// 兼容态会让升级后首次 sync 落地前切空间时漏出上一个空间的会话, 已经改由
/// backfillMembershipFromExistingConversationsForSpace: 消除。
/// 结果在内存里缓存, 写操作时失效。
-(BOOL) hasAnyMembership;

/// 该空间是否已经有归属数据(= 至少被完整同步过一次)。
/// 上层用它区分"这个空间从没进过(白名单按未初始化处理, 保持首次 sync 前不过滤的语义)"
/// 与"这个空间有缓存(白名单严格生效)"。
-(BOOL) hasMembershipForSpace:(NSString*)spaceId;

/// channel 是否归属于该空间。
-(BOOL) isChannel:(WKChannel*)channel inSpace:(NSString*)spaceId;

/// GC: 清掉不属于任何空间、且 last_msg_timestamp 早于 beforeTimestamp 的会话行,
/// 以及没有对应会话行的孤儿归属记录。返回删除的会话行数。
/// DB 不再被 deleteAllConversation 清空后, 需要有这么一个有界化的出口。
-(NSInteger) gcOrphanConversationsBefore:(NSInteger)beforeTimestamp;

/// GC: 删掉"指不到任何活着的会话行"的归属（会话行已不存在, 或 is_deleted=1）。
/// 返回删除的归属记录数。
///
/// ⚠️ 刻意**不**提供"每空间只保留最新 N 条"的裁剪。列表读是 EXISTS(conversation_space)
/// 作用域连接, 裁掉有效归属 = 那条会话立刻从列表消失; 会话数超过 N 的空间里被裁的是
/// 最旧那批, 用户视角是"启动 20s 后列表凭空少一截"(下次冷启动的强制全量 sync 会重建,
/// 于是变成反复抖动)。而一行归属只有几十字节, 用隐藏用户数据换这点空间不成立。
/// 有界化由本方法 + gcOrphanConversationsBefore: 承担, 它们删的都是不可见的死数据。
-(NSInteger) gcDanglingMembership;

@end

NS_ASSUME_NONNULL_END
