//
//  WKConversationListVM.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"

@class WKCategoryEntity;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKConversationFilterType) {
    WKConversationFilterFollow = 0, // 关注（含分组的群 + DM + 子区）
    WKConversationFilterRecent = 1, // 最近（全平铺时间序）
};

/// 会话列表展示项（可以是普通会话 或 分组 section header）
@interface WKConversationDisplayItem : NSObject
@property (nonatomic, strong, nullable) WKConversationWrapModel *conversation; // 普通会话
@property (nonatomic, assign) BOOL isSectionHeader;   // 是否为分组 header
@property (nonatomic, copy, nullable) NSString *sectionId;
@property (nonatomic, copy, nullable) NSString *sectionTitle;
@property (nonatomic, assign) BOOL isDefaultSection;  // 默认分组（不可管理）
@property (nonatomic, assign) NSInteger groupCount;   // 分组内群聊数量
@property (nonatomic, assign) NSInteger unreadCount;  // 分组内未读总数
@property (nonatomic, assign) BOOL hasMention;        // 分组内是否有@我提醒（折叠时显示）
+ (instancetype)itemWithConversation:(WKConversationWrapModel *)model;
+ (instancetype)sectionHeaderWithId:(NSString *)sectionId title:(NSString *)title isDefault:(BOOL)isDefault;
@end

@interface WKConversationListVM : NSObject

/// 当前过滤类型（群组/私聊）
@property (nonatomic, assign) WKConversationFilterType filterType;

+ (WKConversationListVM *)shared;


-(void) reset; // 重置数据

/// sync完成后调用：记录当前VM中的群聊channelId作为"当前空间合法群聊"白名单
/// shouldShowConversation: 中会用此白名单过滤其他空间的群聊
-(void) snapshotSyncedGroupIds;

/// 将群聊添加到当前空间白名单（用于群聊创建后立即显示在会话列表）
-(void) addGroupToWhitelist:(NSString*)channelId;

/// 检查群聊是否在当前空间白名单中
/// 白名单未初始化（首次sync前）时返回YES（暂不过滤）
-(BOOL) isGroupInWhitelist:(NSString*)channelId;

/// 白名单是否已被 snapshot/sync 初始化过。
/// : 新消息路径需要区分「白名单 nil（race / 重置中）」vs「白名单空集（明确无群）」——
/// 前者不能再作 fail-open 默认通过，必须走 verifyAndAddGroupsToList 回兜，
/// 否则外部群新消息会在 Space 切换瞬态窗口里绕过 SpaceFilter 污染当前 Space 列表。
-(BOOL) isGroupWhitelistInitialized;

/// : 从当前 VM 的 conversationWrapModels 中裁剪掉当前 Space 不应展示的群聊。
/// 扫描所有 WK_GROUP 条目，对每一条调 WKSpaceFilter —— 拿到 Skip 就移除残留，
/// 避免「访问过群后内存层 / SDK cache 残留 → 新消息路径将其浮到当前 Space 列表顶部」。
/// 在 Space 切换完成（snapshotSyncedGroupIds 之后）和 filter 批次结束时调用。
/// 返回被移除的 channelId 列表（便于 caller 触发 UI 刷新 / 记日志）。
-(NSArray<NSString*>*) pruneNonCurrentSpaceGroups;

/// YUJ-bot-isolation: 清掉 VM 中"已 robot=YES 但不属于指定 Space my_bots∪space_bots 集合"的 Bot 行。
/// 与 web 不同：iOS 上 Bot DM 的 channel_id 不带 `s{spaceId}_` 前缀、消息 payload 也不带
/// space_id（实测线上服务端如此），因此前缀 / 消息字段三层信号都失效，必须靠
/// WKSpaceBotRegistry 的服务端权威列表兜底。在 WKSpaceBotRegistryDidLoadNotification
/// 触发时调用。返回被移除的 channelId 列表。
-(NSArray<NSString*>*) pruneNonCurrentSpaceBotsForSpace:(NSString*)spaceId;

/// Space 切换/sync 完成后的兜底总清扫 —— 把 conversationWrapModels +
/// threadWrapModels 里凡是不属于指定 Space 的条目全部移除。覆盖 4 类:
///   - WK_GROUP：WKSpaceFilter.Skip → 移除
///   - WK_PERSON Bot：WKSpaceBotRegistry.NotMember → 移除
///   - WK_PERSON 非 Bot：lastMessage.space_id 明确不匹配 → 移除（保守，缺 space_id 保留）
///   - WK_COMMUNITY_TOPIC：parentGroupNo 不在 syncedGroupChannelIds → 移除
/// 调用时机：Space 切换 sync 完成 callback 末尾（snapshot/prune 之后），
/// 兜住"切换瞬间通过 fail-open 漏入的会话"。
/// outRemovedCount / outRemovedThreadCount 可传 NULL。
-(void) sweepForeignToSpace:(NSString*)spaceId
                removedCount:(nullable NSInteger*)outRemovedCount
         removedThreadCount:(nullable NSInteger*)outRemovedThreadCount;

/// : 后端 sync 在当前 Space 不返回 botfather 时本地兜底合成占位 conversation，
/// 保证用户能看到系统 bot 入口（对齐 Android Round-3 Fix C）。
/// 调用时机：sync 完成 / Space 切换后的 loadConversationList 之后，
/// 即在 snapshotSyncedGroupIds + pruneNonCurrentSpaceGroups 之后 / UI 刷新之前。
/// 硬约束：
///   1. 只挂在 VM 层 conversationWrapModels，不写入 WKSDK conversationManager / DB —
///      避免污染 修复的持久化层（群聊 cache 清理策略针对 DB，不影响此 VM-only
///      合成条目）；占位 conversation 随下次 reset / loadConversationList 自然丢弃。
///   2. 尊重 WKBotFatherHidden_<spaceId> 用户隐藏标记 — 已删除过的 Space 不自动恢复，
///      对齐 shouldShowConversation / filterConversationsBySpace 的既有语义。
///   3. 已存在 botfather entry（sync 正常返回 / 新消息路径先到）时无操作。
/// 返回 YES 表示实际合成了 entry（caller 可据此决定是否额外刷新 UI）。
-(BOOL) ensureSystemBotsVisible;
/**
 加载最近会话列表
 */
-(void) loadConversationList:(void(^)(void)) finished;


/**
 最近会话数量

 @return <#return value description#>
 */
-(NSInteger) conversationCount;


/**
 最近会话列表数据

 @return <#return value description#>
 */
-(NSArray<WKConversationWrapModel*> *) conversationList;


/**
 排序
 */
-(void) sortConversationList;
/**
 获取频道会话的下表

 @param channel <#channel description#>
 @return <#return value description#>
 */
-(NSInteger) indexAtChannel:(WKChannel*)channel;


/**
 获取频道对应的z最近会话对象

 @param channel <#channel description#>
 @return <#return value description#>
 */
-(WKConversationWrapModel*) modelAtChannel:(WKChannel*) channel;

-(WKConversationWrapModel*) modelAtIndex:(NSInteger)index;

/**
 取代频道最近会话model

 @param model <#model description#>
 @param channel <#channel description#>
 */
-(void) replaceAtChannel:(WKConversationWrapModel*)model atChannel:(WKChannel*)channel;

-(void) replaceObjectAtIndex:(NSInteger)index withObject:(WKConversationWrapModel*)model;
/**
 移除指定频道的会话

 @param channel <#channel description#>
 */
-(void) removeAtChannnel:(WKChannel*)channel;

-(void) removeAtIndex:(NSInteger)index;


/// 移除所有会话
-(void) removeAll;
/**
 插入会话

 @param model <#model description#>
 @param insert <#insert description#>
 */
-(void) insert:(WKConversationWrapModel*)model atIndex:(NSInteger)insert;

-(NSInteger) insert:(WKConversationWrapModel*)model;


/**
  获取真正需要显示的conversation对象（如果最近会话属于某个最近会话的子类 其实真正要显示的是这个父类的最近会话信息）
 */
-(WKConversationWrapModel*) getRealShowConversationWrap:(WKConversationWrapModel*) wrapModel;
/**
  获取插入位置
 */
-(NSInteger) findInsertPlace:(WKConversationWrapModel*)model;

/**
 获取指定下标的最近会话对象

 @param index <#index description#>
 @return <#return value description#>
 */
-(WKConversationWrapModel*) conversationAtIndex:(NSInteger)index;


/// 移除最近会话
/// @param index <#index description#>
-(void) removeConversationAtIndex:(NSInteger)index;


/// 拉取所有群组的子区数量
-(void) fetchThreadCountsForGroups;

/// 重建过滤列表（filterType 变更或数据增删后调用）
-(void) rebuildFilteredList;

/// 全量会话列表（不受 tab 过滤影响，用于跨 tab 检测@提醒等）
-(NSArray<WKConversationWrapModel*> *) allConversations;

/// 关注 tab 未读数
-(NSInteger) getFollowUnreadCount;

/// 最近 tab 未读数（DM + 3 天内活跃的群 + 子区，全部 !mute）
-(NSInteger) getRecentUnreadCount;

/// 子区独立 wrap models — 用于"最近 tab 平铺、子区独立成行"。
/// 与 conversationWrapModels 互不重叠：后者只有 PERSON+GROUP，前者只有 COMMUNITY_TOPIC。
@property(nonatomic,copy,readonly,nullable) NSArray<WKConversationWrapModel*> *threadWrapModels;

/// 同 modelAtChannel: 但子区也会被找到（先查 channelIndex，再扫 threadWrapModels）。
/// 用于 unread / channelInfo 这类更新场景。
-(nullable WKConversationWrapModel*) anyModelAtChannel:(WKChannel*) channel;

/// 3 天内无活动的群判定。最近 tab 用：列表过滤 + 未读统计都用同一谓词避免不一致。
/// DM/子区 不参与该过滤。
+ (BOOL)isInactiveGroup:(WKConversationWrapModel*)model;

/// 子区会话增量更新（来自 onConversationUpdate）。最近 tab 调，用于刷新
/// threadWrapModels 集合并触发 rebuildFilteredList。不动 conversationWrapModels。
- (void)applyThreadConversationUpdates:(NSArray<WKConversation*>*)threadConversations;

/// 刷新指定群组的子区数量
-(void) refreshThreadCountForGroups:(NSSet<NSString*>*)groupNos;

/// 子区预览展开状态
-(BOOL) isThreadExpanded:(NSString*)channelId;
-(void) toggleThreadExpanded:(NSString*)channelId;
-(void) restoreExpandedThreadGroups;

/// 有会话置顶
-(BOOL) hasConversationTop;

/**
 获取所有未读数量

 @return <#return value description#>
 */
-(NSInteger) getAllUnreadCount;

#pragma mark - Category (分组)

/// 分组列表
@property (nonatomic, strong) NSArray<WKCategoryEntity *> *categoryList;

/// 折叠状态
@property (nonatomic, strong) NSMutableSet<NSString *> *collapsedSections;

/// 加载分组数据
-(void) loadCategoriesWithCompletion:(nullable void(^)(void))completion;

/// 构建群聊 tab 的展示列表（含 section header），同时计算全局 hasMention 状态
-(NSArray<WKConversationDisplayItem *> *) buildGroupDisplayList;

/// buildGroupDisplayList 计算出的 tab 级 @提醒状态，分关注 / 最近两个集合：
///   - Follow:  与 getFollowUnreadCount 同口径（DM/Channel/Thread 走 WKFollowedKeysStore）
///   - Recent:  与 getRecentUnreadCount 同口径（DM 全部；Group 非 3 天 stale；Thread 走
///              threadWrapModels 排除 placeholder）
/// 同一会话可能同时落在两个集合（例如关注的 3 天活跃群），这种情况下两个字段都会为 YES。
@property (nonatomic, assign, readonly) BOOL lastBuildFollowHasMention;
@property (nonatomic, assign, readonly) BOOL lastBuildRecentHasMention;

/// 从缓存获取指定群聊下子区的未读数和 @提醒状态（供 cell 渲染用，无 DB 查询）
-(void) getThreadIndicatorForGroup:(NSString *)groupNo threadUnread:(NSInteger *)outUnread threadHasMention:(BOOL *)outHasMention;

/// 同上，但允许排除一组 channelId（例如已经作为预览行单独显示红点的子区）。
/// 用于"+N个子区"badge 的计算，避免把预览行已经展示的未读数重复计入。
-(void) getThreadIndicatorForGroup:(NSString *)groupNo
               excludingChannelIds:(nullable NSSet<NSString *> *)excluded
                      threadUnread:(NSInteger *)outUnread
                  threadHasMention:(BOOL *)outHasMention;

/// 保存折叠状态
-(void) saveCollapsedSections;

/// 恢复折叠状态
-(void) restoreCollapsedSections;

@end

NS_ASSUME_NONNULL_END
