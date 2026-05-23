//
//  WKConversationListVM.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationListVM.h"
#import "WuKongBase.h"
#import "WKProhibitwordsService.h"
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import "WKThreadCreatedContent.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
#import "WKFollowedKeysStore.h"
#import "WKSidebarItemEntity.h"
#import <WuKongIMSDK/WKReminderDB.h>
#import "WKSpaceFilter.h"
#import "WKSpaceBotRegistry.h"
#import "WKApp.h"
@interface WKConversationListVM ()
@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *conversationWrapModels;
@property(nonatomic,copy,readwrite,nullable) NSArray<WKConversationWrapModel*> *threadWrapModels; // 子区独立 wrap，最近 tab 用
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKConversationWrapModel*> *channelIndex; // channel key → model, O(1) lookup
@property(nonatomic,strong) NSArray<WKConversationWrapModel*> *filteredConversations; // 过滤后的列表
@property(nonatomic,strong) NSRecursiveLock *conversationsLock;
@property(nonatomic,strong) NSSet<NSString*> *syncedGroupChannelIds; // 当前空间的合法群聊白名单
@property(nonatomic,strong) NSMutableSet<NSString*> *expandedThreadGroups; // 子区预览展开的群 channelId
@property(nonatomic,copy) NSArray<WKConversation*> *cachedAllConversations; // loadConversationList 缓存，供 buildGroupDisplayList 复用
@property(nonatomic,strong) NSDictionary<NSString*, NSArray<WKConversation*>*> *cachedTopicsByGroup; // groupId → 子区会话列表
@property(nonatomic,strong) NSDictionary<NSString*, NSArray<WKReminder*>*> *cachedRemindersByChannelId; // 子区 channelId → reminder 列表
@property(nonatomic,strong) NSDictionary *cachedThreadData; // channelId → {previews, count}，跨 reset 保留
@property(nonatomic,assign,readwrite) BOOL lastBuildFollowHasMention;
@property(nonatomic,assign,readwrite) BOOL lastBuildRecentHasMention;

@end

@implementation WKConversationListVM


static WKConversationListVM *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKConversationListVM *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(instancetype) init {
    self = [super init];
    if(self) {
        self.conversationsLock = [[NSRecursiveLock alloc] init];
        self.channelIndex = [NSMutableDictionary dictionary];
        self.collapsedSections = [NSMutableSet set];
        self.expandedThreadGroups = [NSMutableSet set];
        self.categoryList = @[];
    }
    return self;
}

- (NSString *)channelKey:(WKChannel *)channel {
    return [NSString stringWithFormat:@"%@_%d", channel.channelId, (int)channel.channelType];
}

- (void)rebuildChannelIndex {
    [self.channelIndex removeAllObjects];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        self.channelIndex[[self channelKey:model.channel]] = model;
    }
}

- (void)reset {
    NSLog(@"[ConvDebug] VM reset called! clearing %lu models, callStack=%@", (unsigned long)self.conversationWrapModels.count, [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(5, [NSThread callStackSymbols].count - 1))]);
    [self.conversationWrapModels removeAllObjects];
    [self.channelIndex removeAllObjects];
    self.filteredConversations = @[];
    self.threadWrapModels = @[]; // 之前漏清 → space 切换 / 启动清理后旧子区行残留在 recent tab,
                                  // badge 也算它们；rebuildFilteredList 会把它们 append 进 filteredConversations。
                                  // 必须和 conversationWrapModels 一起清，等下次 loadConversationList 重建。
    self.syncedGroupChannelIds = nil;
    self.categoryList = @[];
    self.cachedAllConversations = nil;
    self.cachedTopicsByGroup = nil;
    self.cachedRemindersByChannelId = nil;
}

-(void) snapshotSyncedGroupIds {
    NSMutableSet *groupIds = [NSMutableSet set];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType == WK_GROUP) {
            [groupIds addObject:model.channel.channelId];
        }
    }
    self.syncedGroupChannelIds = [groupIds copy];
    NSLog(@"📋 已记录当前空间合法群聊白名单: %lu 个群", (unsigned long)groupIds.count);
}

-(void) addGroupToWhitelist:(NSString*)channelId {
    if(!channelId || channelId.length == 0) return;
    if(self.syncedGroupChannelIds) {
        NSMutableSet *mutable = [self.syncedGroupChannelIds mutableCopy];
        [mutable addObject:channelId];
        self.syncedGroupChannelIds = [mutable copy];
    } else {
        self.syncedGroupChannelIds = [NSSet setWithObject:channelId];
    }
    NSLog(@"📋 群聊 %@ 已添加到当前空间白名单", channelId);
}

-(BOOL) isGroupInWhitelist:(NSString*)channelId {
    if(!self.syncedGroupChannelIds) return YES; // 白名单未初始化（首次sync前），暂不过滤
    return [self.syncedGroupChannelIds containsObject:channelId];
}

-(BOOL) isGroupWhitelistInitialized {
    // : 在新消息路径 + Space 切换瞬态窗口中严格区分
    // "白名单尚未 snapshot（nil）" vs "已 snapshot 但该 Space 无群（非 nil 空集）"。
    // 前者 caller 应走 verifyAndAddGroupsToList 回兜，而不是裸放行。
    return self.syncedGroupChannelIds != nil;
}

-(NSArray<NSString*>*) pruneNonCurrentSpaceGroups {
    // : 清 VM 残留——对每个 WK_GROUP 查一次 SpaceFilter，
    // 明确 Skip 的群从 conversationWrapModels 踢出。Keep / FailOpen 保持不变。
    // 调用时机：Space 切换完成后 + 新消息 filter 批次结束前，确保单例内存不存"已归属
    // 其它 Space 的群"，防止下次 sort/refresh 再把它浮到顶部（Round-1 只覆盖
    // filter 入口一次，漏了残留清理）。
    NSMutableArray<NSString*> *removed = [NSMutableArray array];
    if(self.conversationWrapModels.count == 0) return removed;
    // 先拷贝一份 snapshot，避免遍历中修改原数组
    NSArray<WKConversationWrapModel*> *snapshot = [self.conversationWrapModels copy];
    for(WKConversationWrapModel *m in snapshot) {
        WKChannel *ch = m.channel;
        if(ch.channelType != WK_GROUP) continue;
        WKSpaceFilterDecision d = [[WKSpaceFilter shared] decideChannel:ch.channelId
                                                            channelType:ch.channelType];
        if(d == WKSpaceFilterDecisionSkip) {
            [self removeAtChannnel:ch];
            [removed addObject:ch.channelId];
        }
    }
    if(removed.count > 0) {
        NSLog(@"🧹 [] 清理当前 Space 不应展示的残留群聊 %lu 个: %@",
              (unsigned long)removed.count, removed);
    }
    return removed;
}

/// YUJ-bot-isolation: 清掉当前 Space 的 conversation list 里"不属于当前 Space 已添加 Bot"
/// 的 Bot 行。对应 web 没有此问题（web 的服务端 Bot DM 走不同 channel_id 形态）。
/// 调用时机：WKSpaceBotRegistry 加载完成后，由 VC 监听通知触发。
/// 数据源：WKSpaceBotRegistry（my_bots ∪ space_bots[status=added]）。
/// 三态语义：
///   - Member：保留
///   - NotMember：移除
///   - Unknown：保留（理论上加载完成后不应再有 Unknown，安全降级）
-(NSArray<NSString*>*) pruneNonCurrentSpaceBotsForSpace:(NSString*)spaceId {
    NSMutableArray<NSString*> *removed = [NSMutableArray array];
    if(spaceId.length == 0 || self.conversationWrapModels.count == 0) return removed;
    NSArray<WKConversationWrapModel*> *snapshot = [self.conversationWrapModels copy];
    NSArray<NSString*> *systemBotUIDs = [WKApp shared].config.systemBotUIDs;
    for(WKConversationWrapModel *m in snapshot) {
        WKChannel *ch = m.channel;
        if(ch.channelType != WK_PERSON) continue;
        // System bot（botfather/u_10000/fileHelper）全局可见，跳过。
        if(systemBotUIDs.count > 0 && [systemBotUIDs containsObject:ch.channelId]) continue;
        WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:ch];
        if(!info || !info.robot) continue; // 非 Bot 不参与本轮 prune
        WKSpaceBotMembership mem = [[WKSpaceBotRegistry shared] membershipForBotUID:ch.channelId inSpace:spaceId];
        if(mem == WKSpaceBotMembershipNotMember) {
            [self removeAtChannnel:ch];
            [removed addObject:ch.channelId];
        }
    }
    if(removed.count > 0) {
#if DEBUG
        NSLog(@"🧹 [BotSpaceTrace] pruneNonCurrentSpaceBots removed %lu bot(s) for space=%@: %@",
              (unsigned long)removed.count, spaceId, removed);
#endif
    }
    return removed;
}

/// Space 切换/sync 完成后的兜底总清扫 —— 把 conversationWrapModels + threadWrapModels
/// 里凡是不属于当前 Space 的条目全部移除。和 pruneNonCurrentSpaceGroups /
/// pruneNonCurrentSpaceBotsForSpace 互补：
///   - 群聊：仍走 WKSpaceFilter（Skip 移除，Keep/FailOpen 保留）
///   - Person Bot：仍走 WKSpaceBotRegistry（NotMember 移除，Member/Unknown 保留）
///   - Person 非 Bot：lastMessage.space_id 明确不匹配 → 移除
///   - 子区：parentGroupNo 不在 syncedGroupChannelIds → 从 threadWrapModels 移除
/// 调用时机：Space 切换 sync 完成 callback 末尾（snapshot/prune 之后），
/// 兜住"切换瞬间通过 fail-open 漏入的会话"。返回 (移除 WrapModel 数, 移除子区数)。
-(void) sweepForeignToSpace:(NSString*)spaceId removedCount:(NSInteger*)outRemovedCount removedThreadCount:(NSInteger*)outRemovedThreadCount {
    NSInteger removedConv = 0;
    NSInteger removedThread = 0;
    if(spaceId.length == 0) {
        if(outRemovedCount) *outRemovedCount = 0;
        if(outRemovedThreadCount) *outRemovedThreadCount = 0;
        return;
    }

    // 1) conversationWrapModels 扫描
    NSArray<WKConversationWrapModel*> *convSnapshot = [self.conversationWrapModels copy];
    NSArray<NSString*> *systemBotUIDs = [WKApp shared].config.systemBotUIDs;
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    NSString *systemUID = [WKApp shared].config.systemUID;
    NSString *fileHelperUID = [WKApp shared].config.fileHelperUID;

    for(WKConversationWrapModel *m in convSnapshot) {
        WKChannel *ch = m.channel;
        NSString *cid = ch.channelId;
        if(cid.length == 0) continue;
        // 全局可见频道：系统通知 / 文件助手 / botfather —— 永不移除
        if([cid isEqualToString:systemUID] || [cid isEqualToString:fileHelperUID]
           || (botfatherUID.length > 0 && [cid isEqualToString:botfatherUID])
           || (systemBotUIDs.count > 0 && [systemBotUIDs containsObject:cid])) {
            continue;
        }

        if(ch.channelType == WK_GROUP) {
            WKSpaceFilterDecision d = [[WKSpaceFilter shared] decideChannel:cid channelType:ch.channelType];
            if(d == WKSpaceFilterDecisionSkip) {
                [self removeAtChannnel:ch];
                removedConv++;
            }
            continue;
        }

        if(ch.channelType == WK_PERSON) {
            // 优先 SpaceFilter（前缀 / channelInfo.space_id）
            WKSpaceFilterDecision d = [[WKSpaceFilter shared] decideChannel:cid channelType:ch.channelType];
            if(d == WKSpaceFilterDecisionSkip) {
                [self removeAtChannnel:ch];
                removedConv++;
                continue;
            }
            // Bot：用 WKSpaceBotRegistry NotMember 兜底
            WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:ch];
            if(info && info.robot) {
                WKSpaceBotMembership mem = [[WKSpaceBotRegistry shared] membershipForBotUID:cid inSpace:spaceId];
                if(mem == WKSpaceBotMembershipNotMember) {
                    [self removeAtChannnel:ch];
                    removedConv++;
                    continue;
                }
            }
            // 非 Bot 普通 DM：看 lastMessage.space_id —— 明确跨 Space 才移除（保守:
            // 缺 space_id 的旧消息保留，避免误杀历史会话）
            WKMessage *lastMsg = m.lastMessage;
            if(lastMsg) {
                id v = lastMsg.content.contentDict[@"space_id"];
                if([v isKindOfClass:[NSString class]]) {
                    NSString *msgSpace = (NSString *)v;
                    if(msgSpace.length > 0 && ![msgSpace isEqualToString:spaceId]) {
                        [self removeAtChannnel:ch];
                        removedConv++;
                        continue;
                    }
                }
            }
        }
    }

    // 2) threadWrapModels 扫描 —— 父群不在白名单 → 移除
    NSSet<NSString*> *synced = self.syncedGroupChannelIds;
    if(synced && self.threadWrapModels.count > 0) {
        NSMutableArray<WKConversationWrapModel*> *kept = [NSMutableArray array];
        for(WKConversationWrapModel *t in self.threadWrapModels) {
            NSString *tcid = t.channel.channelId ?: @"";
            NSRange sep = [tcid rangeOfString:@"____"];
            if(sep.location == NSNotFound) {
                [kept addObject:t];
                continue;
            }
            NSString *parentGroupNo = [tcid substringToIndex:sep.location];
            if([synced containsObject:parentGroupNo]) {
                [kept addObject:t];
            } else {
                removedThread++;
            }
        }
        if(removedThread > 0) {
            self.threadWrapModels = [kept copy];
        }
    }

    if(removedConv > 0 || removedThread > 0) {
        NSLog(@"🧹 [SpaceSweep] sweepForeignToSpace=%@ removedConv=%ld removedThread=%ld",
              spaceId, (long)removedConv, (long)removedThread);
    }
    if(outRemovedCount) *outRemovedCount = removedConv;
    if(outRemovedThreadCount) *outRemovedThreadCount = removedThread;
}

-(BOOL) ensureSystemBotsVisible {
    // : 后端 sync 在当前 Space 不返回 botfather 时的本地兜底。
    // 对齐 Android Round-3 Fix C：只合成 VM 层占位条目，绝不写入 WKSDK cache / DB,
    // 以免与 的群聊 cache pollution 修复策略冲突（后者针对持久化层）。
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    if(!botfatherUID || botfatherUID.length == 0) {
        return NO;
    }

    // 尊重用户主动删除过 BotFather 的意图（hidden 标记与 shouldShowConversation 语义一致）。
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId.length > 0) {
        NSString *hiddenKey = [NSString stringWithFormat:@"WKBotFatherHidden_%@", currentSpaceId];
        if([[NSUserDefaults standardUserDefaults] boolForKey:hiddenKey]) {
            return NO;
        }
    }

    WKChannel *botfatherChannel = [WKChannel personWithChannelID:botfatherUID];
    // 已存在（sync 正常返回 / 新消息路径已 upsert）直接放行
    if([self modelAtChannel:botfatherChannel]) {
        return NO;
    }

    // 合成占位 conversation — 仅放在 VM 层；不调 [[WKSDK shared] conversationManager] 写入。
    // timestamp=0 会把它排到列表底部，与真实历史会话顺序不冲突。
    WKConversation *placeholder = [[WKConversation alloc] init];
    placeholder.channel = botfatherChannel;
    placeholder.unreadCount = 0;
    placeholder.lastMsgTimestamp = 0;
    WKConversationWrapModel *wrap = [[WKConversationWrapModel alloc] initWithConversation:placeholder];

    if(!self.conversationWrapModels) {
        self.conversationWrapModels = [NSMutableArray array];
    }
    [self.conversationWrapModels addObject:wrap];
    self.channelIndex[[self channelKey:botfatherChannel]] = wrap;
    [self sortConversationList]; // 内部会 rebuildFilteredList
    NSLog(@"🤖 [] 本地合成 BotFather 兜底 conversation（backend sync 未返回；spaceId=%@）",
          currentSpaceId ?: @"<none>");
    return YES;
}

-(void) loadConversationList:(void(^)(void)) finished {
    CFAbsoluteTime _lcStart = CFAbsoluteTimeGetCurrent();

    // 在主线程快照旧 threadPreviews/threadCount（后台线程不能读 self.conversationWrapModels）
    // reset 会清空 conversationWrapModels，所以同时用 cachedThreadData 兜底
    NSMutableDictionary *oldThreadData = [NSMutableDictionary dictionary];
    if (self.cachedThreadData) {
        [oldThreadData addEntriesFromDictionary:self.cachedThreadData];
    }
    for (WKConversationWrapModel *old in self.conversationWrapModels) {
        if (old.threadCount > 0) {
            oldThreadData[old.channel.channelId] = @{
                @"previews": old.threadPreviews ?: @[],
                @"count": @(old.threadCount)
            };
        }
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // ===== 后台线程：DB 查询 + 数据构建 =====
        CFAbsoluteTime _dbStart = CFAbsoluteTimeGetCurrent();
        NSArray<WKConversation*> *conversations = [[[WKSDK shared] conversationManager] getConversationList];
        NSLog(@"[TabPerf] loadConversationList(bg): DB query=%.1fms count=%lu",
              (CFAbsoluteTimeGetCurrent()-_dbStart)*1000, (unsigned long)conversations.count);

        NSMutableArray<WKConversationWrapModel*> *conversationWrapModels = [[NSMutableArray alloc] init];
        NSInteger filteredCount = 0;
        if(conversations) {
            for (WKConversation *conversation in conversations) {
                if(![strongSelf shouldShowConversation:conversation]) {
                    filteredCount++;
                    continue;
                }
                if(conversation.channel.channelType == WK_COMMUNITY_TOPIC) {
                    continue;
                }
                WKConversationWrapModel *wrapModel = [[WKConversationWrapModel alloc] initWithConversation:conversation];
                if(conversation.parentChannel) {
                    WKConversationWrapModel *parentConversationWrapModel = [strongSelf addOrCreateParentConversation:conversation.parentChannel newConversationWrapModel:wrapModel conversationWrapModels:conversationWrapModels];
                    if(parentConversationWrapModel) {
                        [strongSelf handleProhibitwords:parentConversationWrapModel];
                        [conversationWrapModels addObject:parentConversationWrapModel];
                    }
                } else {
                    [strongSelf handleProhibitwords:wrapModel];
                    [conversationWrapModels addObject:wrapModel];
                }
            }
        }

        // 从旧 model 继承 threadPreviews/threadCount
        for (WKConversationWrapModel *model in conversationWrapModels) {
            NSDictionary *data = oldThreadData[model.channel.channelId];
            if (data) {
                model.threadPreviews = data[@"previews"];
                model.threadCount = [data[@"count"] integerValue];
            }
        }

        // 恢复 reminders（DB 查询）
        for (WKConversationWrapModel *model in conversationWrapModels) {
            WKConversation *conv = [model getConversation];
            if (!conv.reminders || conv.reminders.count == 0) {
                NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
                if (reminders.count > 0) {
                    conv.reminders = reminders;
                }
            }
        }

        // 构建子区索引缓存（DB 查询）。空间隔离：子区按"父群在不在当前 Space
        // 白名单"过滤；缺这个 gate 会让另一个 Space 的子区会话漏到最近 tab 列表里。
        NSSet<NSString *> *syncedGroupsSnapshot = strongSelf.syncedGroupChannelIds;
        NSMutableDictionary<NSString*, NSMutableArray<WKConversation*>*> *topicsByGroup = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = [NSMutableDictionary dictionary];
        for (WKConversation *conv in conversations) {
            if (conv.channel.channelType != WK_COMMUNITY_TOPIC) continue;
            NSString *channelId = conv.channel.channelId;
            NSRange sep = [channelId rangeOfString:@"____"];
            if (sep.location == NSNotFound) continue;
            NSString *groupId = [channelId substringToIndex:sep.location];
            // 父群不在当前 Space 白名单 → 子区不收（白名单为 nil 表示首次 sync 前
            // 不过滤，与 shouldShowConversation: 同语义）
            if (syncedGroupsSnapshot && ![syncedGroupsSnapshot containsObject:groupId]) continue;
            NSMutableArray *topics = topicsByGroup[groupId];
            if (!topics) { topics = [NSMutableArray array]; topicsByGroup[groupId] = topics; }
            [topics addObject:conv];
            NSArray<WKReminder*> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
            if (reminders.count > 0) remindersByChannelId[channelId] = reminders;
        }
        // 最近 tab 子区独立行渲染源 threadWrapModels：严格按 parent.threadPreviews
        // （listThreads 拉回的真实结果）收集，与 syncThreadWrapModelsFromCachedTopics
        // 同款口径，确保 cell / badge 看到的子区集合一致。
        //
        // 之前是直接 wrap 所有 SDK cache 持有的 thread conversation（topicsByGroup 的副产品）,
        // 把 SDK cache 里早不活跃 / 跨 group / 归档 / 用户没 join 的 thread 全部塞进 threadWrapModels,
        // 实测 loadConversationList 把 threadWrapModels 从 20 涨到 185，后续
        // syncThreadWrapModelsFromCachedTopics 又按 parent.threadPreviews prune 回 20,
        // 中间这一波 badge 算上 165 个幽灵 thread 的 unread (94 条 = 866) → 闪到 872。
        // 现在 loadConversationList 一开始就用同款口径，根除 spike 来源。
        NSMutableArray<WKConversationWrapModel*> *threadWrapModels = [NSMutableArray array];
        for (WKConversationWrapModel *parent in conversationWrapModels) {
            if (parent.channel.channelType != WK_GROUP) continue;
            if (syncedGroupsSnapshot && ![syncedGroupsSnapshot containsObject:parent.channel.channelId]) continue;
            for (WKThreadModel *t in parent.threadPreviews) {
                if (t.channelId.length == 0) continue;
                WKChannel *threadChannel = [WKChannel channelID:t.channelId channelType:WK_COMMUNITY_TOPIC];
                WKConversation *conv = [[WKSDK shared].conversationManager getConversation:threadChannel];
                if (conv) {
                    [threadWrapModels addObject:[[WKConversationWrapModel alloc] initWithConversation:conv]];
                } else {
                    // SDK 没有 → 合成占位（与 syncThreadWrapModelsFromCachedTopics 同款），
                    // 等真实 conv 通过 onConversationUpdate 到达后 lastMessage 不再 nil,
                    // getRecentUnreadCount 才会算入（placeholder 已经 skip）。
                    WKConversation *placeholder = [[WKConversation alloc] init];
                    placeholder.channel = threadChannel;
                    placeholder.unreadCount = t.unreadCount;
                    [threadWrapModels addObject:[[WKConversationWrapModel alloc] initWithConversation:placeholder]];
                }
            }
        }

        // 排序（纯内存）
        [conversationWrapModels sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *obj1, WKConversationWrapModel *obj2) {
            if(obj1.stick && !obj2.stick) return NSOrderedAscending;
            if(!obj1.stick && obj2.stick) return NSOrderedDescending;
            if(obj1.lastMsgTimestamp > obj2.lastMsgTimestamp) return NSOrderedAscending;
            if(obj1.lastMsgTimestamp < obj2.lastMsgTimestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        NSLog(@"[TabPerf] loadConversationList(bg): total=%.1fms models=%lu",
              (CFAbsoluteTimeGetCurrent()-_lcStart)*1000, (unsigned long)conversationWrapModels.count);

        // ===== 主线程：赋值 + UI 回调 =====
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) mainSelf = weakSelf;
            if (!mainSelf) return;

            mainSelf.cachedAllConversations = conversations;
            mainSelf.conversationWrapModels = conversationWrapModels;
            mainSelf.threadWrapModels = threadWrapModels;
            [mainSelf rebuildChannelIndex];
            mainSelf.cachedTopicsByGroup = topicsByGroup;
            mainSelf.cachedRemindersByChannelId = remindersByChannelId;
            [mainSelf rebuildFilteredList];

            // 更新 threadData 缓存（跨 reset 保留，防止切空间时 threadPreviews 丢失）
            NSMutableDictionary *newThreadCache = [NSMutableDictionary dictionary];
            for (WKConversationWrapModel *m in conversationWrapModels) {
                if (m.threadCount > 0) {
                    newThreadCache[m.channel.channelId] = @{
                        @"previews": m.threadPreviews ?: @[],
                        @"count": @(m.threadCount)
                    };
                }
            }
            mainSelf.cachedThreadData = newThreadCache;

            NSLog(@"[TabPerf] loadConversationList: mainThread assign+callback, totalFromStart=%.1fms",
                  (CFAbsoluteTimeGetCurrent()-_lcStart)*1000);
            NSLog(@"[ThreadSync] loadConversationList done: groups+DMs=%ld threadWrapModels=%ld (来源 getConversationList)",
                  (long)conversationWrapModels.count, (long)threadWrapModels.count);

            if(finished) {
                finished();
            }
            [mainSelf fetchThreadCountsForGroups];
        });
    });
}

/// 通过 API 获取每个群组的子区真实数量（带完成回调）
-(void) fetchThreadCountsForGroupsWithCompletion:(void(^)(void))completion {
    NSMutableArray<WKConversationWrapModel *> *groupModels = [NSMutableArray array];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType == WK_GROUP) {
            [groupModels addObject:model];
        }
    }
    if (groupModels.count == 0) {
        if (completion) completion();
        return;
    }

    dispatch_group_t group = dispatch_group_create();

    for (WKConversationWrapModel *model in groupModels) {
        NSString *groupNo = model.channel.channelId;
        dispatch_group_enter(group);
        [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
            NSArray *sorted = [self sortThreadsByLocalTimestamp:threads];
            NSTimeInterval threeDaysAgo = [[NSDate date] timeIntervalSince1970] - 3 * 24 * 3600;
            NSMutableArray *recentPreviews = [NSMutableArray array];
            NSInteger inactiveCount = 0;
            for (WKThreadModel *t in sorted) {
                if (t.status != WKThreadStatusActive) continue;
                WKConversation *conv = [[WKSDK shared].conversationManager getConversation:[t toChannel]];
                NSTimeInterval ts = conv ? conv.lastMsgTimestamp : 0;
                if (!conv) {
                    // SDK 没缓存（冷启子区 lazy load）—— 必须放进 previews,
                    // 不然 syncThreadWrapModelsFromCachedTopics 那条"SDK miss → 合成
                    // placeholder"的代码路径根本走不到（它只遍历 parent.threadPreviews）,
                    // 子区在最近 tab 永远不出现。等真实 conv 到达 applyThreadConversationUpdates
                    // 会用 setConversation: 替换占位 wrap。
                    [recentPreviews addObject:t];
                } else if (ts > threeDaysAgo) {
                    [recentPreviews addObject:t];
                } else {
                    inactiveCount++;
                }
            }
            model.threadPreviews = [recentPreviews copy];
            model.threadCount = (NSInteger)recentPreviews.count + inactiveCount;
            dispatch_group_leave(group);
        }).catch(^(NSError *error) {
            dispatch_group_leave(group);
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 全量 fetch 完成后也同步 threadWrapModels — 否则 cold boot 走的是这条路径
        // （loadConversationList → fetchThreadCountsForGroups → 这里），子区永远进不
        // 了 threadWrapModels，最近 tab 一片空白
        [self syncThreadWrapModelsFromCachedTopics];
        if (completion) completion();
    });
}

/// 拉取所有群组的子区数量，完成后统一通知 VC 刷新（不再逐个发通知）
-(void) fetchThreadCountsForGroups {
    NSLog(@"[ThreadDebug] fetchThreadCountsForGroups START, groupCount=%ld", (long)[self groupModelCount]);
    [self fetchThreadCountsForGroupsWithCompletion:^{
        NSLog(@"[ThreadDebug] fetchThreadCountsForGroups DONE, posting WKThreadCountBatchUpdated");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountBatchUpdated" object:nil];
    }];
}

-(NSInteger) groupModelCount {
    NSInteger count = 0;
    for (WKConversationWrapModel *m in self.conversationWrapModels) {
        if (m.channel.channelType == WK_GROUP) count++;
    }
    return count;
}

/// 刷新指定群组的子区数量（批量请求，统一刷新）
-(void) refreshThreadCountForGroups:(NSSet<NSString*>*)groupNos {
    NSMutableArray<WKConversationWrapModel *> *models = [NSMutableArray array];
    for (NSString *groupNo in groupNos) {
        WKConversationWrapModel *model = [self modelAtChannel:[WKChannel groupWithChannelID:groupNo]];
        if (model) [models addObject:model];
    }
    if (models.count == 0) return;

    dispatch_group_t batchGroup = dispatch_group_create();

    for (WKConversationWrapModel *model in models) {
        NSString *groupNo = model.channel.channelId;
        dispatch_group_enter(batchGroup);
        [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
            NSArray *sorted = [self sortThreadsByLocalTimestamp:threads];
            NSTimeInterval threeDaysAgo = [[NSDate date] timeIntervalSince1970] - 3 * 24 * 3600;
            NSMutableArray *recentPreviews = [NSMutableArray array];
            NSInteger inactiveCount = 0;
            for (WKThreadModel *t in sorted) {
                if (t.status != WKThreadStatusActive) continue;
                WKConversation *conv = [[WKSDK shared].conversationManager getConversation:[t toChannel]];
                NSTimeInterval ts = conv ? conv.lastMsgTimestamp : 0;
                if (!conv) {
                    // 同 fetchThreadCountsForGroupsWithCompletion: SDK miss 必须收进 previews,
                    // 否则下游合成 placeholder 路径走不到。
                    [recentPreviews addObject:t];
                } else if (ts > threeDaysAgo) {
                    [recentPreviews addObject:t];
                } else {
                    inactiveCount++;
                }
            }
            WKConversationWrapModel *currentModel = [self modelAtChannel:[WKChannel groupWithChannelID:groupNo]];
            if (!currentModel) currentModel = model;
            currentModel.threadPreviews = [recentPreviews copy];
            currentModel.threadCount = (NSInteger)recentPreviews.count + inactiveCount;
            for (WKThreadModel *t in recentPreviews) {
                if (t.channelId.length > 0) {
                    [WKThreadCreatedContent messageCountCache][t.channelId] = @(t.messageCount);
                }
            }
            dispatch_group_leave(batchGroup);
        }).catch(^(NSError *error) {
            dispatch_group_leave(batchGroup);
        });
    }
    dispatch_group_notify(batchGroup, dispatch_get_main_queue(), ^{
        // listThreads 拿到的子区也同步进 threadWrapModels —— 不然最近 tab 冷启动时
        // SDK getConversationList 没返回子区，threadWrapModels 是空的，列表里看不到
        // 任何子区行；用户必须发条子区消息触发 onConversationUpdate 才出来。
        [self syncThreadWrapModelsFromCachedTopics];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountBatchUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:WKThreadMessageCountUpdatedNotification object:nil];
    });
}

/// 把 listThreads 已发现的所有子区同步到 threadWrapModels（最近 tab 平铺渲染源）。
/// 优先用 SDK 缓存的真实 WKConversation；SDK 没有时（冷启 SDK 还没把 thread 加载完）
/// 用 WKThreadModel 信息**合成一个最小 WKConversation**作为占位 — 保证 cell 至少
/// 能渲染（标题 + 未读数；preview/time 暂空，等真实 conv 到来时由
/// applyThreadConversationUpdates: setConversation: 替换）。
- (void)syncThreadWrapModelsFromCachedTopics {
    // 把当前 wrap 拷一份当复用池，然后只从最新 listThreads 已发现的 thread 重建 byChannel。
    // 不再用旧 threadWrapModels 做 seed —— 关闭 / 归档 / 服务端筛掉的子区必须立即从 Recent
    // 消失，否则旧行会一直停留到 VM 全量 reset 才清。
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *oldByChannel = [NSMutableDictionary dictionary];
    for (WKConversationWrapModel *m in self.threadWrapModels) {
        if (m.channel.channelId) oldByChannel[m.channel.channelId] = m;
    }
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *byChannel = [NSMutableDictionary dictionary];
    NSSet<NSString *> *syncedGroups = self.syncedGroupChannelIds;
    BOOL changed = NO;
    NSInteger parentCount = 0;
    NSInteger threadsTotal = 0;
    NSInteger sdkHits = 0;
    NSInteger synthesized = 0;
    NSInteger reused = 0;
    for (WKConversationWrapModel *parent in self.conversationWrapModels) {
        if (parent.channel.channelType != WK_GROUP) continue;
        // 父群不在当前 Space 白名单 → 整组子区都跳过（避免漏到最近 tab）
        if (syncedGroups && ![syncedGroups containsObject:parent.channel.channelId]) continue;
        parentCount++;
        for (WKThreadModel *t in parent.threadPreviews) {
            if (t.channelId.length == 0) continue;
            threadsTotal++;
            WKChannel *threadChannel = [WKChannel channelID:t.channelId channelType:WK_COMMUNITY_TOPIC];
            WKConversation *conv = [[WKSDK shared].conversationManager getConversation:threadChannel];
            WKConversationWrapModel *existing = oldByChannel[t.channelId];
            if (existing) {
                // 仍在 discovered 集合 → 复用旧 wrap，保住 onConversationUpdate 写入的 preview / lastMessage。
                // 旧 wrap 是 placeholder（lastMessage 空）且 SDK 现在有真实 conv → 顺手刷一次。
                if (conv && !existing.lastMessage) {
                    [existing setConversation:conv];
                    changed = YES;
                }
                byChannel[t.channelId] = existing;
                reused++;
                continue;
            }
            if (conv) {
                sdkHits++;
                byChannel[t.channelId] = [[WKConversationWrapModel alloc] initWithConversation:conv];
                changed = YES;
            } else {
                // SDK 没有 → 合成一个最小 WKConversation 作为占位，避免子区在最近
                // tab 完全消失。lastMessage 留空，cell 显示标题 + 未读数即可，等
                // 真实消息到来时由 applyThreadConversationUpdates 替换。
                WKConversation *placeholder = [[WKConversation alloc] init];
                placeholder.channel = threadChannel;
                placeholder.unreadCount = t.unreadCount;
                synthesized++;
                byChannel[t.channelId] = [[WKConversationWrapModel alloc] initWithConversation:placeholder];
                changed = YES;
            }
        }
    }
    // 检测 prune：oldByChannel 里有但 byChannel 没了的项 = 该子区已不在最新 discovered 集合，需要清掉。
    if (!changed && byChannel.count != oldByChannel.count) changed = YES;
    if (!changed) {
        for (NSString *k in oldByChannel) {
            if (!byChannel[k]) { changed = YES; break; }
        }
    }
    NSLog(@"[ThreadSync] syncThreadWrapModels: parents=%ld threadsInPreviews=%ld sdkHits=%ld synthesized=%ld reused=%ld changed=%d total=%ld old=%ld",
          (long)parentCount, (long)threadsTotal, (long)sdkHits, (long)synthesized, (long)reused, changed, (long)byChannel.count, (long)oldByChannel.count);
    if (changed) {
        self.threadWrapModels = [byChannel.allValues copy];
        // 总是 rebuildFilteredList — Follow tab 启动时也要让 filteredConversations
        // 准备好，避免切到 Recent 才发现里面没子区
        [self rebuildFilteredList];
        NSLog(@"[ThreadSync] threadWrapModels=%ld filteredConversations=%ld filterType=%ld",
              (long)self.threadWrapModels.count, (long)self.filteredConversations.count, (long)self.filterType);
    }
}

/// 用本地会话时间戳排序子区（解决服务端 updated_at 延迟导致首条消息排序不更新）
-(NSArray<WKThreadModel*>*) sortThreadsByLocalTimestamp:(NSArray<WKThreadModel*>*)threads {
    NSMutableDictionary<NSString*, NSNumber*> *tsMap = [NSMutableDictionary dictionaryWithCapacity:threads.count];
    for (WKThreadModel *t in threads) {
        if (t.channelId.length == 0) continue;
        WKConversation *conv = [[WKSDK shared].conversationManager getConversation:
                                [WKChannel channelID:t.channelId channelType:WK_COMMUNITY_TOPIC]];
        tsMap[t.channelId] = @(conv ? conv.lastMsgTimestamp : 0);
    }
    return [threads sortedArrayUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
        double tsA = [tsMap[a.channelId] doubleValue];
        double tsB = [tsMap[b.channelId] doubleValue];
        if (tsA != tsB) return tsA > tsB ? NSOrderedAscending : NSOrderedDescending;
        return [b.updatedAt compare:a.updatedAt];
    }];
}

/// 判断会话是否应在当前空间显示
-(BOOL) shouldShowConversation:(WKConversation*)conversation {
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return YES; // 无空间上下文，不过滤
    }
    NSString *channelId = conversation.channel.channelId;
    // 系统通知、文件助手始终显示
    if([channelId isEqualToString:[WKApp shared].config.systemUID] ||
       [channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
        return YES;
    }
    // BotFather：检查当前空间是否已隐藏
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    if(botfatherUID && [channelId isEqualToString:botfatherUID]) {
        NSString *hiddenKey = [NSString stringWithFormat:@"WKBotFatherHidden_%@", currentSpaceId];
        if([[NSUserDefaults standardUserDefaults] boolForKey:hiddenKey]) {
            return NO;
        }
        return YES;
    }
    // 群聊：优先走 WKSpaceFilter（支持外部群 source_space_id 兜底，对齐 dmwork-web PR #1036 #1037）
    //   - Keep: channelInfo.space_id == currentSpaceId 或 member.source_space_id == currentSpaceId
    //   - Skip: channelInfo.space_id 明确不匹配且我不是外部成员
    //   - FailOpen: channelInfo 未缓存，降级走白名单（iOS 原有兼容路径）
    if(conversation.channel.channelType == WK_GROUP) {
        WKSpaceFilterDecision decision = [[WKSpaceFilter shared] decideChannel:conversation.channel.channelId
                                                                  channelType:conversation.channel.channelType];
        if(decision == WKSpaceFilterDecisionKeep) {
            return YES;
        }
        if(decision == WKSpaceFilterDecisionSkip) {
            return NO;
        }
        // fail-open：用 sync 白名单兜底
        //   - nil: 尚未sync（首次启动DB清空后），暂不过滤（shouldShowConversation 主要在
        //         loadConversationList 的 DB 冷启动路径调用；DB 是上次 sync 的持久化真值，
        //         此时放行不会带来跨 Space 串台。新消息路径不走本方法——它走
        //         WKConversationListVC.filterConversationsBySpace，那里已按 收紧。）
        //   - 空集合: sync完成但当前空间无群聊，过滤掉所有群聊
        //   - 非空: 只显示白名单中的群聊
        if(self.syncedGroupChannelIds) {
            return [self.syncedGroupChannelIds containsObject:conversation.channel.channelId];
        }
        return YES; // 白名单未初始化（首次sync前），暂不过滤
    }

    // Person 频道：默认放行（消息级隔离在聊天页面 shouldShowMessageInCurrentSpace 处理）。
    // 例外：channelId 带 `s{otherSpace}_` 前缀（Bot 与私聊均会被后端前缀化）→ Skip。
    // 对齐 web `shouldSkipChannelForSpace`（dmwork-web/.../SpaceService.tsx:23-25）。
    // 无前缀的私聊保持向前兼容。
    if(conversation.channel.channelType == WK_PERSON) {
        WKSpaceFilterDecision decision = [[WKSpaceFilter shared]
                                           decideChannel:conversation.channel.channelId
                                             channelType:conversation.channel.channelType];
        if(decision == WKSpaceFilterDecisionSkip) {
            return NO;
        }
        return YES;
    }
    return YES;
}

-(void) handleProhibitwords:(WKConversationWrapModel*)model {
    if(!model.lastMessage) {
        return;
    }
    if(model.lastMessage.contentType != WK_TEXT) {
        return;
    }
    if( model.lastMessage.remoteExtra.isEdit) {
        if(model.lastMessage.remoteExtra.isEdit) {
            WKTextContent *content = (WKTextContent*)model.lastMessage.remoteExtra.contentEdit;
            content.content =[WKProhibitwordsService.shared filter:content.content]; // 违禁词过滤
            return;
        }
        WKTextContent *content = (WKTextContent*)model.lastMessage.content;
        content.content = [WKProhibitwordsService.shared filter:content.content]; // 违禁词过滤
    }
}

-(WKConversationWrapModel*) addOrCreateParentConversation:(WKChannel*) parentChannel newConversationWrapModel:(WKConversationWrapModel*)wrapModel conversationWrapModels:(NSArray<WKConversationWrapModel*>*)conversationWrapModels {
    WKConversationWrapModel *parentConversation = [self getConversationWrap:parentChannel conversations:conversationWrapModels];
    if(parentConversation) {
        [self handleProhibitwords:wrapModel];
        [parentConversation addOrUpdateChildren:wrapModel];
    }else{
        WKConversation *newParentConversation = [[WKConversation alloc] init];
        newParentConversation.channel = wrapModel.parentChannel;
        WKConversationWrapModel *parentConversationWrap = [[WKConversationWrapModel alloc] initWithConversation:newParentConversation];
        [self handleProhibitwords:wrapModel];
        [parentConversationWrap addOrUpdateChildren:wrapModel];
        return parentConversationWrap;
    }
    return nil;
}

-(WKConversationWrapModel*) getConversationWrap:(WKChannel*)channel conversations:(NSArray<WKConversationWrapModel*>*)conversations{
    for (WKConversationWrapModel *conversation in conversations) {
        if([conversation.channel isEqual:channel]) {
            return conversation;
        }
    }
    return nil;
}

// 获取真实显示的最近会话对象
-(WKConversationWrapModel*) getRealShowConversationWrap:(WKConversationWrapModel*) wrapModel {
    if(!wrapModel.parentChannel) {
        return wrapModel;
    }
    WKConversationWrapModel *conversation = [self modelAtChannel:wrapModel.parentChannel];
    if (conversation) {
        [self handleProhibitwords:wrapModel];
        [conversation addOrUpdateChildren:wrapModel];
        return conversation;
    }
    WKConversation *parentConversation = [[WKConversation alloc] init];
    parentConversation.channel = wrapModel.parentChannel;
    WKConversationWrapModel *parentConversationWrap = [[WKConversationWrapModel alloc] initWithConversation:parentConversation];
    [self handleProhibitwords:wrapModel];
    [parentConversationWrap addOrUpdateChildren:wrapModel];
    return parentConversationWrap;
}

-(void) sortConversationList {
    [self.conversationWrapModels sortUsingComparator:^NSComparisonResult(WKConversationWrapModel   *obj1, WKConversationWrapModel   *obj2) {

        if(obj1.stick && !obj2.stick) {
            return NSOrderedAscending;
        }
        if(obj2.stick && !obj1.stick) {
            return NSOrderedDescending;
        }
        if(obj1.lastMsgTimestamp < obj2.lastMsgTimestamp) {
            return NSOrderedDescending;
        }else if(obj1.lastMsgTimestamp == obj2.lastMsgTimestamp) {
            return NSOrderedSame;
        }
        return NSOrderedAscending;
    }];
    [self rebuildFilteredList];
}

#pragma mark - 过滤

+ (BOOL)isInactiveGroup:(WKConversationWrapModel *)model {
    if (!model || model.channel.channelType != WK_GROUP) return NO;
    NSInteger ts = model.lastMsgTimestamp; // SDK 10 位秒级时间戳
    if (ts <= 0) return YES; // 从未活跃过的群也按 stale 处理
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    return (now - (NSTimeInterval)ts) >= 3 * 86400;
}

- (void)applyThreadConversationUpdates:(NSArray<WKConversation*>*)threadConversations {
    if (threadConversations.count == 0) return;
    // 把现有 threadWrapModels 按 channelId 建索引
    NSMutableDictionary<NSString*, WKConversationWrapModel*> *byChannel = [NSMutableDictionary dictionary];
    for (WKConversationWrapModel *m in self.threadWrapModels) {
        if (m.channel.channelId) byChannel[m.channel.channelId] = m;
    }
    NSSet<NSString *> *syncedGroups = self.syncedGroupChannelIds;
    BOOL mutated = NO;
    for (WKConversation *c in threadConversations) {
        if (!c.channel.channelId) continue;
        // 空间隔离：父群必须在当前 Space 白名单（fail-closed）—— syncedGroups 未初始化（reset 后
        // sync 完成前的 race 窗口）一律拒绝，与 VC.filterConversationsBySpace 的 topic 分支同步,
        // 避免跨 Space 子区在启动期被错误吸进 threadWrapModels（PR review #1C）。
        NSRange sep = [c.channel.channelId rangeOfString:@"____"];
        if (sep.location == NSNotFound) continue;
        NSString *parentGroupNo = [c.channel.channelId substringToIndex:sep.location];
        if (!syncedGroups || ![syncedGroups containsObject:parentGroupNo]) continue;
        WKConversationWrapModel *existing = byChannel[c.channel.channelId];
        if (existing) {
            // 已知子区：刷新 lastMessage / lastMsgTimestamp 让 cell 拿到新值（对齐
            // onlyAddOrUpdateConversation: 里 setConversation: 的处理）。
            [existing setConversation:c];
            mutated = YES;
        }
        // 未知子区：不再凭空 add 进 threadWrapModels。
        // 用户进 group 详情时，SDK 会回放/同步一批"幽灵"子区 conversation（早就不活跃但
        // SDK cache 还在），之前 applyThreadConversationUpdates 来者不拒全部 alloc 新 wrap，
        // threadWrapModels 瞬间从 20 涨到 185，badge 算上这 165 个的 unread 跳到 872；随后
        // syncThreadWrapModelsFromCachedTopics 按 parent.threadPreviews（listThreads 真实结果）
        // prune 回 20，但 badge 中间态已经 leak 给用户。
        //
        // 子区进入 threadWrapModels 的唯一通道交给 syncThreadWrapModelsFromCachedTopics
        // 单点驱动（走 parent.threadPreviews / listThreads 真实结果）+ loadConversationList
        // 同款口径。这条路径只负责给已知子区更新 preview / timestamp。
    }
    if (mutated) {
        self.threadWrapModels = [byChannel.allValues copy];
    }
    [self rebuildFilteredList];
}

-(BOOL) modelMatchesFilter:(WKConversationWrapModel *)model {
    uint8_t type = model.channel.channelType;
    if (self.filterType == WKConversationFilterFollow) {
        // P2 stage 1：关注 tab 行为不变，仍走分组 group 视图（VC 用 groupDisplayList，
        // 这里只决定 filteredConversations 内容，对 follow tab 不直接生效）。
        if (type != WK_GROUP && type != WK_PERSON) return YES;
        return type == WK_GROUP;
    }
    // 最近 tab：DM + 群（3 天活跃）+ 子区，全部平铺
    if (type == WK_PERSON) return YES;
    if (type == WK_GROUP) {
        return ![WKConversationListVM isInactiveGroup:model];
    }
    if (type == WK_COMMUNITY_TOPIC) return YES;
    // 系统通知、文件助手等特殊频道一直展示
    return YES;
}

-(void) rebuildFilteredList {
    // 先去重（同一个 channel 只保留一条，防止外部分享时同时发文件+文本导致重复）
    NSMutableSet *seenKeys = [NSMutableSet set];
    NSMutableArray *deduped = [NSMutableArray array];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        NSString *key = [self channelKey:model.channel];
        if ([seenKeys containsObject:key]) continue;
        [seenKeys addObject:key];
        [deduped addObject:model];
    }
    if (deduped.count != self.conversationWrapModels.count) {
        NSLog(@"[ShareExt] rebuildFilteredList 去重: %lu -> %lu", (unsigned long)self.conversationWrapModels.count, (unsigned long)deduped.count);
        [self.conversationWrapModels removeAllObjects];
        [self.conversationWrapModels addObjectsFromArray:deduped];
        [self rebuildChannelIndex]; // 去重后同步索引
    }

    NSMutableArray *filtered = [NSMutableArray array];
    if (self.filterType == WKConversationFilterRecent) {
        // 最近 tab：DM 用原始 wrap；群用 shadow wrap（不挂子区，避免群行借子区的 lastMessage
        // 渲染 + 隐藏子区数量指示）；子区独立成行；置顶（stick）参与排序 — 用户在最近 tab
        // 长按置顶时希望能浮顶。
        for (WKConversationWrapModel *model in self.conversationWrapModels) {
            uint8_t type = model.channel.channelType;
            if (![self modelMatchesFilter:model]) continue;
            if (type == WK_GROUP) {
                // shadow wrap：同一个底层 WKConversation，但没有 lastChildConversation/threadCount，
                // 所以 cell 渲染时取群自己的 lastMessage / 不显示子区角标（修 #2 #4）。
                // 缺点是 channelInfoInner 缓存丢失，需要 cell 自己懒加载；可以接受。
                WKConversationWrapModel *shadow = [[WKConversationWrapModel alloc] initWithConversation:[model getConversation]];
                [filtered addObject:shadow];
            } else {
                [filtered addObject:model];
            }
        }
        // 子区独立成行
        for (WKConversationWrapModel *thread in self.threadWrapModels) {
            [filtered addObject:thread];
        }
        [filtered sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
            // 置顶优先，再按时间倒序
            if (a.stick && !b.stick) return NSOrderedAscending;
            if (!a.stick && b.stick) return NSOrderedDescending;
            if (a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
            if (a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    } else {
        for (WKConversationWrapModel *model in self.conversationWrapModels) {
            if ([self modelMatchesFilter:model]) {
                [filtered addObject:model];
            }
        }
    }
    self.filteredConversations = [filtered copy];
    NSLog(@"[ThreadSync] rebuildFilteredList done: filterType=%ld convWraps=%ld threadWraps=%ld filtered=%ld",
          (long)self.filterType, (long)self.conversationWrapModels.count,
          (long)self.threadWrapModels.count, (long)self.filteredConversations.count);
}

-(NSInteger) getFollowUnreadCount {
    // 关注 tab 未读 = 关注集合（DM / 群 / 子区，!mute）的未读总和。
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    if (!store.loaded) return 0;
    NSInteger count = 0;
    for (WKConversationWrapModel *m in self.conversationWrapModels) {
        if ([self isChannelMuted:m]) continue;
        if (m.channel.channelType == WK_PERSON) {
            if ([store isFollowedWithType:WKFollowTargetTypeDM targetId:m.channel.channelId]) {
                count += m.unreadCount;
            }
        } else if (m.channel.channelType == WK_GROUP) {
            if ([store isFollowedWithType:WKFollowTargetTypeChannel targetId:m.channel.channelId]) {
                count += m.unreadCount;
            }
        }
    }
    for (WKConversationWrapModel *t in self.threadWrapModels) {
        if ([self isChannelMuted:t]) continue;
        if (![store isFollowedWithType:WKFollowTargetTypeThread targetId:t.channel.channelId]) continue;
        // 跳过 placeholder（与 getRecentUnreadCount 同款 — syncThreadWrapModelsFromCachedTopics
        // 为 listThreads 拉到但 SDK 还没同步真实 conv 的子区合成占位 wrap，placeholder.unreadCount
        // 来自接口字段，不一定是当前用户的未读，cell 端稳态也不渲染）
        if (t.lastMessage == nil) continue;
        count += t.unreadCount;
    }
    return count;
}

/// 静音判定单一入口：channelInfo.mute 是 SDK 权威源，DB 上的 WKConversation.mute
/// 是同步快照、冷启动可能滞后，所以优先信 channelInfo，缺失才回退。
-(BOOL) isChannelMuted:(WKConversationWrapModel *)model {
    if (!model || !model.channel) return NO;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:model.channel];
    if (info) return info.mute;
    return model.mute;
}

/// 同上，但接收 WKConversation —— 给 thread cell / cachedTopicsByGroup 这些拿不到 wrap 的路径用。
-(BOOL) isConversationMuted:(WKConversation *)conv {
    if (!conv || !conv.channel) return NO;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:conv.channel];
    if (info) return info.mute;
    return conv.mute;
}

-(NSInteger) getRecentUnreadCount {
    NSInteger count = 0;
    // DM + 3 天内活跃的群（与 modelMatchesFilter: 的最近 tab 谓词保持一致）。
    // 静音同样走 channelInfo.mute（见 getFollowUnreadCount 注释）。
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if ([self isChannelMuted:model]) continue;
        uint8_t type = model.channel.channelType;
        if (type == WK_PERSON) {
            count += model.unreadCount;
        } else if (type == WK_GROUP) {
            if (![WKConversationListVM isInactiveGroup:model]) {
                count += model.unreadCount;
            }
        }
    }
    for (WKConversationWrapModel *thread in self.threadWrapModels) {
        if ([self isChannelMuted:thread]) continue;
        // 跳过 placeholder thread —— syncThreadWrapModelsFromCachedTopics 在 listThreads 拉回大量
        // 子区时会合成占位 wrap（无 lastMessage，unreadCount 来自接口的 t.unreadCount）。这个
        // unread 不一定是当前用户的未读（可能是后端总未读），cell 端 stable 状态也不渲染这些
        // 占位行，badge 不能把它们算进去。等真实 WKConversation 通过 onConversationUpdate →
        // setConversation: 到达后 lastMessage 不再 nil，自动开始计入。
        if (thread.lastMessage == nil) continue;
        count += thread.unreadCount;
    }
    return count;
}

-(NSArray<WKConversationWrapModel*> *) conversationList {
    return self.filteredConversations ?: @[];
}

-(NSArray<WKConversationWrapModel*> *) allConversations {
    return self.conversationWrapModels ?: @[];
}

-(NSInteger) conversationCount {
    return self.filteredConversations.count;
}

-(NSInteger) indexAtChannel:(WKChannel*)channel {
    NSArray *list = self.filteredConversations;
    if (list) {
        for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
            WKConversationWrapModel *conversation = list[i];
            if ([conversation.channel isEqual:channel]) {
                return i;
            }
        }
    }
    return -1;
}

-(WKConversationWrapModel*) modelAtChannel:(WKChannel*) channel {
    if (!channel) return nil;
    [_conversationsLock lock];
    WKConversationWrapModel *result = self.channelIndex[[self channelKey:channel]];
    [_conversationsLock unlock];
    return result;
}

/// 同 modelAtChannel: 但若主索引找不到，再扫一遍 threadWrapModels —— 子区不在
/// conversationWrapModels / channelIndex 里，常规查询路径取不到。用于 unread /
/// channelInfo 这类需要"无论在哪个 wrap 容器都找到"的更新场景。
-(WKConversationWrapModel*) anyModelAtChannel:(WKChannel*) channel {
    WKConversationWrapModel *m = [self modelAtChannel:channel];
    if (m) return m;
    if (channel.channelType == WK_COMMUNITY_TOPIC) {
        for (WKConversationWrapModel *t in self.threadWrapModels) {
            if ([t.channel isEqual:channel]) return t;
        }
    }
    return nil;
}

-(WKConversationWrapModel*) modelAtIndex:(NSInteger)index {
    NSArray *list = self.filteredConversations;
    if (index < 0 || index >= (NSInteger)list.count) return nil;
    return list[index];
}

-(void) replaceAtChannel:(WKConversationWrapModel*)model atChannel:(WKChannel*)channel  {
    NSString *key = [self channelKey:channel];
    WKConversationWrapModel *oldModel = self.channelIndex[key];
    if (!oldModel) return;
    NSInteger fullIndex = [self.conversationWrapModels indexOfObjectIdenticalTo:oldModel];
    if (fullIndex == NSNotFound) return;
    if (oldModel.threadCount > 0 && model.threadCount == 0) {
        model.threadCount = oldModel.threadCount;
    }
    if (oldModel.threadPreviews.count > 0 && model.threadPreviews.count == 0) {
        model.threadPreviews = oldModel.threadPreviews;
    }
    [self handleProhibitwords:model];
    [self.conversationWrapModels replaceObjectAtIndex:fullIndex withObject:model];
    self.channelIndex[key] = model;
    [self rebuildFilteredList];
}
-(void) replaceObjectAtIndex:(NSInteger)index withObject:(WKConversationWrapModel*)model{
    [self handleProhibitwords:model];
    if (index >= 0 && index < (NSInteger)self.conversationWrapModels.count) {
        WKConversationWrapModel *oldModel = self.conversationWrapModels[index];
        [self.channelIndex removeObjectForKey:[self channelKey:oldModel.channel]];
        [self.conversationWrapModels replaceObjectAtIndex:index withObject:model];
        self.channelIndex[[self channelKey:model.channel]] = model;
        [self rebuildFilteredList];
    }
}

-(void) removeAtChannnel:(WKChannel*)channel {
    NSString *key = [self channelKey:channel];
    WKConversationWrapModel *model = self.channelIndex[key];
    if (model) {
        [self.channelIndex removeObjectForKey:key];
        [self.conversationWrapModels removeObjectIdenticalTo:model];
        [self rebuildFilteredList];
    }
}

-(void) removeAtIndex:(NSInteger)index {
    if (index >= 0 && index < (NSInteger)self.conversationWrapModels.count) {
        WKConversationWrapModel *model = self.conversationWrapModels[index];
        [self.channelIndex removeObjectForKey:[self channelKey:model.channel]];
        [self.conversationWrapModels removeObjectAtIndex:index];
        [self rebuildFilteredList];
    }
}


-(void) removeAll {
    [self.conversationWrapModels removeAllObjects];
    [self.channelIndex removeAllObjects];
    // 子区独立 wrap 也一并清 —— 之前漏清，"删除所有会话"后 recent tab 还能看到旧子区行,
    // badge 也算它们的 unread。与 reset 路径同款处理。
    self.threadWrapModels = @[];
    [self rebuildFilteredList];
}

-(void) insert:(WKConversationWrapModel*)model atIndex:(NSInteger)insert {
    if(insert>self.conversationWrapModels.count) {
        WKLogWarn(@"warn: conversationWrapModels数组大小->%ld insert的大小%ld",(long)self.conversationWrapModels.count,(long)insert);
        return;
    }
    [self handleProhibitwords:model];
    [self.conversationWrapModels insertObject:model atIndex:insert];
    self.channelIndex[[self channelKey:model.channel]] = model;
    [self rebuildFilteredList];
}

-(NSInteger) insert:(WKConversationWrapModel*)model {
    [self  handleProhibitwords:model];
    WKConversationWrapModel *conversationWrapModel = [self getRealShowConversationWrap:model];
    NSInteger insertPlace =  [self findInsertPlace:conversationWrapModel];
    [self.conversationWrapModels insertObject:conversationWrapModel atIndex:insertPlace];
    self.channelIndex[[self channelKey:conversationWrapModel.channel]] = conversationWrapModel;
    [self rebuildFilteredList];
    // 返回过滤后数组中的位置
    NSArray *list = self.filteredConversations;
    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        if (list[i] == conversationWrapModel) return i;
    }
    return 0;
}

-(NSInteger) findInsertPlace:(WKConversationWrapModel*)m {
    WKConversationWrapModel *newModel = m;
    if(newModel.parentChannel) {
       WKConversationWrapModel *parentConversationWrapModel = [self addOrCreateParentConversation:m.parentChannel newConversationWrapModel:m conversationWrapModels:self.conversationWrapModels];
        if(parentConversationWrapModel) {
            newModel = parentConversationWrapModel;
        }else {
             parentConversationWrapModel = [self getConversationWrap:m.parentChannel conversations:self.conversationWrapModels];
            if(parentConversationWrapModel) {
                newModel = parentConversationWrapModel;
            }
        }
    }
   
//    return 0;
//    __block int topMsgCount = 0;
//    for (NSInteger i=self.conversationWrapModels.count-1;i>=0;i--) {
//        WKConversationWrapModel *oldModel = self.conversationWrapModels[i];
//        if(newModel.stick) {
//            if(oldModel.stick) {
//                if(newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
//                    return i;
//                }
//            }else {
//                return i;
//            }
//        }else if(!oldModel.stick && newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
//            return i;
//        }
//    }
    if(!self.conversationWrapModels || self.conversationWrapModels.count == 0) {
        return 0;
    }
    if(self.conversationWrapModels.count == 1) {
        if( [self.conversationWrapModels[0].channel isEqual:newModel.channel]) {
            return 0;
        }
    }
   __block bool find = false;
    __block NSUInteger matchIndex = 0;
    __block bool beforeHasSelf = false;
    [self.conversationWrapModels enumerateObjectsUsingBlock:^(WKConversationWrapModel * _Nonnull oldModel, NSUInteger idx, BOOL * _Nonnull stop) {
        if(newModel.stick) {
            if(oldModel.stick) {
                if(newModel.lastMsgTimestamp>=oldModel.lastMsgTimestamp) {
                    find = YES;
                    matchIndex = idx;
                    *stop = YES;
                    return;
                }
            }else {
                find = YES;
                matchIndex = idx;
                *stop = YES;
            }
            return;
        }else if(!oldModel.stick && newModel.lastMsgTimestamp>oldModel.lastMsgTimestamp) {
            find = YES;
            matchIndex = idx;
            *stop = YES;
            return;
        }else if(!oldModel.stick && newModel.lastMsgTimestamp == oldModel.lastMsgTimestamp && [newModel.channel isEqual:oldModel.channel]) {
            find = YES;
            matchIndex = idx;
            *stop = YES;
            return;
        }else if([newModel.channel isEqual:oldModel.channel]) {
            beforeHasSelf = true;
        }
    }];
    if (find) {
        if(beforeHasSelf){
            return matchIndex-1;
        }
        return matchIndex;
    }else {
        return self.conversationWrapModels.count-1;
    }
}


-(WKConversationWrapModel*) conversationAtIndex:(NSInteger)index {
    NSArray *list = self.filteredConversations;
    if (index < 0 || index >= (NSInteger)list.count) {
        return nil;
    }
    return list[index];
}

-(void) removeConversationAtIndex:(NSInteger)index {
    NSArray *list = self.filteredConversations;
    if (index >= 0 && index < (NSInteger)list.count) {
        WKConversationWrapModel *model = list[index];
        [self.channelIndex removeObjectForKey:[self channelKey:model.channel]];
        [self.conversationWrapModels removeObjectIdenticalTo:model];
        [self rebuildFilteredList];
    }
}

-(BOOL) hasConversationTop {
    if(self.conversationWrapModels) {
        for (WKConversationWrapModel *model in self.conversationWrapModels) {
            if(model.stick) {
                return true;
            }
        }
    }
    return false;
}

-(NSInteger) getAllUnreadCount {
    [_conversationsLock lock];
    NSInteger unreadCount = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        // 与 follow / recent badge 一致走 channelInfo.mute 权威源；DB 快照可能滞后
        if(![self isChannelMuted:model]) {
            unreadCount +=model.unreadCount;
        }
    }
    [_conversationsLock unlock];
    return unreadCount;
}

#pragma mark - Category (分组)

-(void) loadCategoriesWithCompletion:(void(^)(void))completion {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!spaceId || spaceId.length == 0) {
        self.categoryList = @[];
        if(completion) completion();
        return;
    }
    [[WKCategoryService shared] listCategories:spaceId].then(^(NSArray<WKCategoryEntity *> *list) {
        self.categoryList = list ?: @[];
        if(completion) completion();
    }).catch(^(NSError *error) {
        NSLog(@"加载分组失败: %@", error);
        if(completion) completion();
    });
}

/// O(子区数) — 使用预建索引计算子区未读数（替代 O(N) 全量遍历版本）
-(NSInteger) threadUnreadForGroup:(NSString *)groupNo topicsByGroup:(NSDictionary<NSString*, NSArray<WKConversation*>*>*)topicsByGroup {
    NSInteger total = 0;
    for (WKConversation *conv in topicsByGroup[groupNo]) {
        total += conv.unreadCount;
    }
    return total;
}

/// 关注 tab section unread 用：只算"已关注"的子区未读，避免父群已关注就把所有缓存
/// 子区未读都算进去（spec 子区独立关注）。store 未加载时为 0，与渲染口径一致。
-(NSInteger) followedThreadUnreadForGroup:(NSString *)groupNo
                            topicsByGroup:(NSDictionary<NSString*, NSArray<WKConversation*>*>*)topicsByGroup {
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    if (!store.loaded) return 0;
    NSInteger total = 0;
    // 走 threadWrapModels（与 cell 渲染源 / getRecentUnreadCount 同口径，按 parent.threadPreviews
    // 即 listThreads 真实活跃集合），不再走 topicsByGroup（SDK 全量 cache，含归档 / 不再返回的
    // 幽灵 thread）。否则用户曾关注但已归档的 thread 仍会被 SDK cache 持有 → 这条路径
    // 把它们算入 section unread，与 cell 实际显示的子区集合不一致（cell 按 threadWrapModels
    // 渲染，看不到这些 thread）。topicsByGroup 参数保留兼容签名，仅供 cell 子区指示点等
    // "群下面是否有任何子区动静"语义复用。
    NSString *prefix = [NSString stringWithFormat:@"%@____", groupNo];
    for (WKConversationWrapModel *thread in self.threadWrapModels) {
        if (![thread.channel.channelId hasPrefix:prefix]) continue;
        if (thread.lastMessage == nil) continue; // 跳过 placeholder（与 getRecentUnreadCount 同款）
        if ([self isChannelMuted:thread]) continue;
        if (![store isFollowedWithType:WKFollowTargetTypeThread targetId:thread.channel.channelId]) continue;
        total += thread.unreadCount;
    }
    return total;
}

/// O(子区数) — 使用预建索引和 reminder 缓存检测@提醒（替代 O(N) 全量遍历 + 逐个 DB 查询版本）
-(BOOL) hasMentionForGroup:(NSString *)groupNo model:(WKConversationWrapModel *)model topicsByGroup:(NSDictionary<NSString*, NSArray<WKConversation*>*>*)topicsByGroup remindersByChannelId:(NSDictionary<NSString*, NSArray<WKReminder*>*>*)remindersByChannelId {
    if (model && model.simpleReminders.count > 0) {
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) return YES;
        }
    }
    for (WKConversation *conv in topicsByGroup[groupNo]) {
        for (WKReminder *r in remindersByChannelId[conv.channel.channelId]) {
            if (r.type == WKReminderTypeMentionMe) return YES;
        }
    }
    return NO;
}

/// 从缓存获取指定群聊下子区的未读数和 @提醒状态（供 cell 渲染用，纯内存查找，无 DB 查询）
-(void) getThreadIndicatorForGroup:(NSString *)groupNo threadUnread:(NSInteger *)outUnread threadHasMention:(BOOL *)outHasMention {
    [self getThreadIndicatorForGroup:groupNo excludingChannelIds:nil threadUnread:outUnread threadHasMention:outHasMention];
}

-(void) getThreadIndicatorForGroup:(NSString *)groupNo
               excludingChannelIds:(NSSet<NSString *> *)excluded
                      threadUnread:(NSInteger *)outUnread
                  threadHasMention:(BOOL *)outHasMention {
    NSInteger unread = 0;
    BOOL hasMention = NO;
    // 与 cell 的 WKConversationGroupThreadCell.visibleThreadPreviewsFor: 同源，按 followedKeys
    // 过滤 —— 否则 cell 上 preview 行只显示已关注子区、但 indicator 数字 / @ 提醒 / "+N
    // 子区" 把未关注子区也算进去，违反 spec §0 "Follow tab 严格按 followedKeys 过滤"。
    // store 未加载时 fail-open（与 visibleThreadPreviewsFor 同款），避免冷启动期一律 0。
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    NSArray<WKConversation*> *topics = self.cachedTopicsByGroup[groupNo];
    if (topics) {
        for (WKConversation *conv in topics) {
            if (excluded.count > 0 && [excluded containsObject:conv.channel.channelId]) continue;
            if (store.loaded && ![store isFollowedWithType:WKFollowTargetTypeThread targetId:conv.channel.channelId]) continue;
            // cell 上显示的子区合计 unread 必须过滤静音子区，与 follow / recent tab badge 同款口径,
            // 否则用户给某个子区设静音后，群聊 cell 上的红点数字仍包含该子区的未读
            if ([self isConversationMuted:conv]) continue;
            unread += conv.unreadCount;
            if (!hasMention) {
                NSArray<WKReminder*> *rems = self.cachedRemindersByChannelId[conv.channel.channelId];
                for (WKReminder *r in rems) {
                    if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
                }
            }
        }
    }
    if (outUnread) *outUnread = unread;
    if (outHasMention) *outHasMention = hasMention;
}

/// 检测指定群聊及其所有子区是否有未处理的@提醒（使用缓存的会话列表避免重复 DB 查询）
-(BOOL) hasMentionForGroup:(NSString *)groupNo model:(WKConversationWrapModel *)model allConvs:(NSArray<WKConversation*>*)allConvs {
    // 检查群聊自身的 reminder
    if (model && model.simpleReminders.count > 0) {
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) return YES;
        }
    }
    // 检查该群聊下所有子区的 reminder
    NSString *prefix = [NSString stringWithFormat:@"%@____", groupNo];
    for (WKConversation *conv in allConvs) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC && [conv.channel.channelId hasPrefix:prefix]) {
            NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
            for (WKReminder *r in reminders) {
                if (r.type == WKReminderTypeMentionMe) return YES;
            }
        }
    }
    return NO;
}

/// 计算指定群聊下所有子区的未读数总和（使用缓存的会话列表避免重复 DB 查询）
-(NSInteger) threadUnreadForGroup:(NSString *)groupNo allConvs:(NSArray<WKConversation*>*)allConvs {
    NSInteger total = 0;
    NSString *prefix = [NSString stringWithFormat:@"%@____", groupNo];
    for (WKConversation *conv in allConvs) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC && [conv.channel.channelId hasPrefix:prefix]) {
            total += conv.unreadCount;
        }
    }
    return total;
}

/// 从 cachedAllConversations 构建子区索引和 reminder 缓存
-(void) rebuildTopicIndexCache {
    NSArray<WKConversation *> *allConvs = self.cachedAllConversations;
    if (!allConvs) return;
    NSMutableDictionary<NSString*, NSMutableArray<WKConversation*>*> *topicsByGroup = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = [NSMutableDictionary dictionary];
    for (WKConversation *conv in allConvs) {
        if (conv.channel.channelType != WK_COMMUNITY_TOPIC) continue;
        NSString *channelId = conv.channel.channelId;
        NSRange sep = [channelId rangeOfString:@"____"];
        if (sep.location == NSNotFound) continue;
        NSString *groupId = [channelId substringToIndex:sep.location];
        NSMutableArray *topics = topicsByGroup[groupId];
        if (!topics) { topics = [NSMutableArray array]; topicsByGroup[groupId] = topics; }
        [topics addObject:conv];
        NSArray<WKReminder*> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
        if (reminders.count > 0) remindersByChannelId[channelId] = reminders;
    }
    self.cachedTopicsByGroup = topicsByGroup;
    self.cachedRemindersByChannelId = remindersByChannelId;
}

-(NSArray<WKConversationDisplayItem *> *) buildGroupDisplayList {
    CFAbsoluteTime _bgStart = CFAbsoluteTimeGetCurrent();
    // 1. 建立 channelId → WKConversationWrapModel 映射（群 + DM 都加入，关注 tab 需要 DM）
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *groupChannelMap = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *dmChannelMap = [NSMutableDictionary dictionary];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(model.channel.channelType == WK_GROUP) {
            groupChannelMap[model.channel.channelId] = model;
        } else if (model.channel.channelType == WK_PERSON) {
            dmChannelMap[model.channel.channelId] = model;
        }
    }

    NSMutableArray<WKConversationDisplayItem *> *displayList = [NSMutableArray array];

    // 使用 loadConversationList 时预建的子区索引缓存，无缓存时现场构建（首次调用等边界情况）
    NSDictionary<NSString*, NSArray<WKConversation*>*> *topicsByGroup = self.cachedTopicsByGroup;
    NSDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = self.cachedRemindersByChannelId;
    if (!topicsByGroup) {
        [self rebuildTopicIndexCache];
        topicsByGroup = self.cachedTopicsByGroup ?: @{};
        remindersByChannelId = self.cachedRemindersByChannelId ?: @{};
    }

    // 关注 tab 数据装配（P2-2）：合并 WKFollowedKeysStore 提供的 DM 入分组。
    // store.itemsByCategory[category_id] 是后端 sidebar/sync 已按 follow_sort 排好的
    // 该分组下所有关注项（含群/DM/子区）；这里只取 DM（target_type=1），群仍以
    // cat.groups 为权威（categoryList 是 categories 接口的直接结果）。
    WKFollowedKeysStore *followStore = [WKFollowedKeysStore shared];
    NSDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *followItemsByCat = followStore.itemsByCategory;

    // sidebar/sync 已确认 followed 但本地 IM cache miss 的项（冷启 / 缓存清过 / 新关注还没拉到 conv）
    // 补 placeholder wrap，否则 Follow tab 会丢行 — 用户视角是「明明关注了却看不到」。
    // 真实 conv 到达后由 onConversationUpdate 流程接管，placeholder 会自然被替换。
    for (NSArray<WKSidebarItemEntity *> *bucket in followItemsByCat.allValues) {
        for (WKSidebarItemEntity *it in bucket) {
            if (it.target_id.length == 0) continue;
            if (it.target_type == WKFollowTargetTypeDM && !dmChannelMap[it.target_id]) {
                WKConversation *p = [[WKConversation alloc] init];
                p.channel = [WKChannel channelID:it.target_id channelType:WK_PERSON];
                p.unreadCount = (int)it.unread;
                p.lastMsgTimestamp = it.timestamp;
                dmChannelMap[it.target_id] = [[WKConversationWrapModel alloc] initWithConversation:p];
            } else if (it.target_type == WKFollowTargetTypeChannel && !groupChannelMap[it.target_id]) {
                WKConversation *p = [[WKConversation alloc] init];
                p.channel = [WKChannel channelID:it.target_id channelType:WK_GROUP];
                p.unreadCount = (int)it.unread;
                p.lastMsgTimestamp = it.timestamp;
                groupChannelMap[it.target_id] = [[WKConversationWrapModel alloc] initWithConversation:p];
            }
        }
    }

    // 3. 非 default 分组（spec §0：关注 tab 隐藏默认分组）
    NSSet<NSString *> *followedGroupNos = followStore.followedGroupNos;
    // 用 store.loaded 而不是 count > 0 — 空 vs 未加载严格区分：sidebar/sync 成功
    // 返回空集合（用户没关注任何东西）就该展示空，不能 fail-open 回退到 cat.groups
    // 把所有遗留群一股脑亮出来。
    BOOL followLoaded = followStore.loaded;
    for (WKCategoryEntity *cat in self.categoryList) {
        if (cat.is_default) continue;
        WKConversationDisplayItem *header = [WKConversationDisplayItem sectionHeaderWithId:cat.category_id title:cat.name isDefault:NO];
        // 解析本分组的 DM 关注项
        NSArray<WKSidebarItemEntity *> *items = followItemsByCat[cat.category_id ?: @""] ?: @[];
        NSMutableArray<WKConversationWrapModel *> *followedDMs = [NSMutableArray array];
        for (WKSidebarItemEntity *it in items) {
            if (it.target_type != WKFollowTargetTypeDM) continue;
            WKConversationWrapModel *dmWrap = dmChannelMap[it.target_id];
            if (dmWrap) [followedDMs addObject:dmWrap];
        }

        // 严格走 followedGroupNos 过滤；store 未加载完成时 visibleGroups 为空数组,
        // 避免 fail-open 把 server categories 接口返回的 unfollowed 群也展示出来。
        // 等 store loaded 后 buildGroupDisplayList 会被通知触发重建。
        NSMutableArray<WKCategoryGroup *> *visibleGroups = [NSMutableArray array];
        if (followLoaded) {
            for (WKCategoryGroup *cg in cat.groups) {
                if ([followedGroupNos containsObject:cg.group_no]) {
                    [visibleGroups addObject:cg];
                }
            }
        }

        // 统计：群数 + DM 数 + 群内未读 + DM 未读 + 子区未读 + @提醒
        NSInteger count = 0;
        NSInteger totalUnread = 0;
        BOOL sectionHasMention = NO;
        for (WKCategoryGroup *cg in visibleGroups) {
            WKConversationWrapModel *m = groupChannelMap[cg.group_no];
            if (m) {
                count++;
                // 静音判定走 channelInfo.mute（与 getFollowUnreadCount / tab badge 保持一致）—
                // model.mute 是 DB 快照，冷启动可能滞后，会让 section header 和 tab badge 算不一样。
                if (![self isChannelMuted:m]) totalUnread += m.unreadCount;
                totalUnread += [self followedThreadUnreadForGroup:cg.group_no topicsByGroup:topicsByGroup];
                if (!sectionHasMention) {
                    sectionHasMention = [self hasMentionForGroup:cg.group_no model:m topicsByGroup:topicsByGroup remindersByChannelId:remindersByChannelId];
                }
            }
        }
        for (WKConversationWrapModel *dm in followedDMs) {
            count++;
            if (![self isChannelMuted:dm]) totalUnread += dm.unreadCount;
            if (!sectionHasMention && dm.simpleReminders.count > 0) {
                for (WKReminder *r in dm.simpleReminders) {
                    if (r.type == WKReminderTypeMentionMe) { sectionHasMention = YES; break; }
                }
            }
        }
        header.groupCount = count;
        header.unreadCount = totalUnread;
        header.hasMention = sectionHasMention;
        // 空分组也要展示 header — 否则用户从引导页新建分组后引导页不消失、看不到自己刚建的分组，
        // 也无法在分组管理外的位置感知分组存在。空分组下不会渲染任何会话行，只占一个 header。
        [displayList addObject:header];

        if(![self.collapsedSections containsObject:cat.category_id]) {
            // 分组内顺序：优先用 store.itemsByCategory（已按 follow_sort 排好）的顺序,
            // 保证 P3-1.7 的拖拽排序生效。store 没覆盖到的项（冷启动、新建未同步等）
            // 兜底按 timestamp 追加在末尾。
            NSMutableArray<WKConversationWrapModel *> *sectionItems = [NSMutableArray array];
            NSMutableSet<NSString *> *added = [NSMutableSet set];
            for (WKSidebarItemEntity *it in items) {
                WKConversationWrapModel *wrap = nil;
                if (it.target_type == WKFollowTargetTypeDM) {
                    wrap = dmChannelMap[it.target_id];
                } else if (it.target_type == WKFollowTargetTypeChannel) {
                    wrap = groupChannelMap[it.target_id];
                }
                if (wrap && ![added containsObject:wrap.channel.channelId]) {
                    [sectionItems addObject:wrap];
                    [added addObject:wrap.channel.channelId];
                }
            }
            // store 没覆盖的群 / DM 兜底（按 timestamp 倒序）
            NSMutableArray<WKConversationWrapModel *> *leftover = [NSMutableArray array];
            for (WKCategoryGroup *cg in visibleGroups) {
                if ([added containsObject:cg.group_no]) continue;
                WKConversationWrapModel *msg = groupChannelMap[cg.group_no];
                if (msg) { [leftover addObject:msg]; [added addObject:cg.group_no]; }
            }
            for (WKConversationWrapModel *dm in followedDMs) {
                if ([added containsObject:dm.channel.channelId]) continue;
                [leftover addObject:dm];
                [added addObject:dm.channel.channelId];
            }
            [leftover sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
                if (a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
                if (a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            [sectionItems addObjectsFromArray:leftover];
            for (WKConversationWrapModel *m in sectionItems) {
                [displayList addObject:[WKConversationDisplayItem itemWithConversation:m]];
            }
        }
    }

    // 4. 默认分组 / 未归组群聊：spec §0 关注 tab 完全隐藏。原来这里有把未归组群挂到
    // is_default 分组的逻辑（保持向后兼容用），关注 tab 改版后**不再展示**任何属于
    // 默认分组的会话（这是产品规则，对齐 web）。若用户有未关注的群想看，最近 tab 仍有。

    // 顺便计算 Follow / Recent 两个 tab 各自的 hasMention（复用已有的 remindersByChannelId,
    // 避免 updateGroupMentionBadge 重复查 DB）。
    // 归属口径严格对齐 getFollowUnreadCount / getRecentUnreadCount：
    //   - Follow: WKFollowedKeysStore（DM/Channel/Thread）；store 未加载时一律不算（保守，
    //     与 getFollowUnreadCount 同口径，避免冷启动期把全量 mention 都挂到关注 tab）。
    //   - Recent: DM 全部；Group 非 3 天 stale；Thread 走 threadWrapModels 排除 placeholder。
    // 一个会话可能同时落在两个集合（例：关注的 3 天活跃群），两端都会亮。
    // mention 本身不做静音过滤 —— 与 section header sectionHasMention 行为一致（静音群被
    // @ 还是要让用户感知）。
    BOOL followHasMention = NO;
    BOOL recentHasMention = NO;

    NSMutableSet<NSString*> *recentThreadIds = [NSMutableSet set];
    for (WKConversationWrapModel *t in self.threadWrapModels) {
        if (t.lastMessage == nil) continue; // placeholder
        if (t.channel.channelId.length > 0) [recentThreadIds addObject:t.channel.channelId];
    }

    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (followHasMention && recentHasMention) break;
        if (model.simpleReminders.count == 0) continue;
        BOOL hasMention = NO;
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
        }
        if (!hasMention) continue;
        uint8_t type = model.channel.channelType;
        if (type == WK_PERSON) {
            if (!recentHasMention) recentHasMention = YES;
            if (!followHasMention && followLoaded &&
                [followStore isFollowedWithType:WKFollowTargetTypeDM targetId:model.channel.channelId]) {
                followHasMention = YES;
            }
        } else if (type == WK_GROUP) {
            if (!recentHasMention && ![WKConversationListVM isInactiveGroup:model]) {
                recentHasMention = YES;
            }
            if (!followHasMention && followLoaded &&
                [followStore isFollowedWithType:WKFollowTargetTypeChannel targetId:model.channel.channelId]) {
                followHasMention = YES;
            }
        }
    }

    if (!followHasMention || !recentHasMention) {
        for (NSString *channelId in remindersByChannelId) {
            if (followHasMention && recentHasMention) break;
            // 顶层 channel（群/DM）已在上面通过 simpleReminders 走过；这里只补子区路径,
            // 子区 channelId 形如 "<groupNo>____<threadId>"。
            if ([channelId rangeOfString:@"____"].location == NSNotFound) continue;
            NSArray<WKReminder*> *rems = remindersByChannelId[channelId];
            BOOL hasMention = NO;
            for (WKReminder *r in rems) {
                if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
            }
            if (!hasMention) continue;
            if (!recentHasMention && [recentThreadIds containsObject:channelId]) {
                recentHasMention = YES;
            }
            if (!followHasMention && followLoaded &&
                [followStore isFollowedWithType:WKFollowTargetTypeThread targetId:channelId]) {
                followHasMention = YES;
            }
        }
    }

    self.lastBuildFollowHasMention = followHasMention;
    self.lastBuildRecentHasMention = recentHasMention;

    NSLog(@"[TabPerf] buildGroupDisplayList: %.1fms items=%lu followHasMention=%d recentHasMention=%d", (CFAbsoluteTimeGetCurrent()-_bgStart)*1000, (unsigned long)displayList.count, followHasMention, recentHasMention);
    return displayList;
}

static NSString *const kCollapsedSectionsKey = @"collapsed_sections";

-(void) saveCollapsedSections {
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *key = [NSString stringWithFormat:@"%@_%@", uid, kCollapsedSectionsKey];
    NSString *value = [[self.collapsedSections allObjects] componentsJoinedByString:@","];
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}

-(void) restoreCollapsedSections {
    if(!self.collapsedSections) {
        self.collapsedSections = [NSMutableSet set];
    }
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *key = [NSString stringWithFormat:@"%@_%@", uid, kCollapsedSectionsKey];
    NSString *saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if(saved && saved.length > 0) {
        NSArray *ids = [saved componentsSeparatedByString:@","];
        for (NSString *sectionId in ids) {
            if(sectionId.length > 0) {
                [self.collapsedSections addObject:sectionId];
            }
        }
    }
}

#pragma mark - Thread Expand

static NSString *const kExpandedThreadGroupsKey = @"expanded_thread_groups";

-(BOOL) isThreadExpanded:(NSString*)channelId {
    return [self.expandedThreadGroups containsObject:channelId];
}

-(void) toggleThreadExpanded:(NSString*)channelId {
    if ([self.expandedThreadGroups containsObject:channelId]) {
        [self.expandedThreadGroups removeObject:channelId];
    } else {
        [self.expandedThreadGroups addObject:channelId];
    }
    [self saveExpandedThreadGroups];
}

-(void) saveExpandedThreadGroups {
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *key = [NSString stringWithFormat:@"%@_%@", uid, kExpandedThreadGroupsKey];
    NSString *value = [[self.expandedThreadGroups allObjects] componentsJoinedByString:@","];
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}

-(void) restoreExpandedThreadGroups {
    if (!self.expandedThreadGroups) {
        self.expandedThreadGroups = [NSMutableSet set];
    }
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *key = [NSString stringWithFormat:@"%@_%@", uid, kExpandedThreadGroupsKey];
    NSString *saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (saved && saved.length > 0) {
        NSArray *ids = [saved componentsSeparatedByString:@","];
        for (NSString *cid in ids) {
            if (cid.length > 0) [self.expandedThreadGroups addObject:cid];
        }
    }
}

@end

#pragma mark - WKConversationDisplayItem

@implementation WKConversationDisplayItem

+ (instancetype)itemWithConversation:(WKConversationWrapModel *)model {
    WKConversationDisplayItem *item = [[WKConversationDisplayItem alloc] init];
    item.conversation = model;
    item.isSectionHeader = NO;
    return item;
}

+ (instancetype)sectionHeaderWithId:(NSString *)sectionId title:(NSString *)title isDefault:(BOOL)isDefault {
    WKConversationDisplayItem *item = [[WKConversationDisplayItem alloc] init];
    item.isSectionHeader = YES;
    item.sectionId = sectionId;
    item.sectionTitle = title;
    item.isDefaultSection = isDefault;
    return item;
}

@end
