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
#import <WuKongIMSDK/WKReminderDB.h>
#import "WKSpaceFilter.h"
#import "WKSpaceBotRegistry.h"
#import "WKApp.h"
@interface WKConversationListVM ()
@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *conversationWrapModels;
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKConversationWrapModel*> *channelIndex; // channel key → model, O(1) lookup
@property(nonatomic,strong) NSArray<WKConversationWrapModel*> *filteredConversations; // 过滤后的列表
@property(nonatomic,strong) NSRecursiveLock *conversationsLock;
@property(nonatomic,strong) NSSet<NSString*> *syncedGroupChannelIds; // 当前空间的合法群聊白名单
@property(nonatomic,strong) NSMutableSet<NSString*> *expandedThreadGroups; // 子区预览展开的群 channelId
@property(nonatomic,copy) NSArray<WKConversation*> *cachedAllConversations; // loadConversationList 缓存，供 buildGroupDisplayList 复用
@property(nonatomic,strong) NSDictionary<NSString*, NSArray<WKConversation*>*> *cachedTopicsByGroup; // groupId → 子区会话列表
@property(nonatomic,strong) NSDictionary<NSString*, NSArray<WKReminder*>*> *cachedRemindersByChannelId; // 子区 channelId → reminder 列表
@property(nonatomic,strong) NSDictionary *cachedThreadData; // channelId → {previews, count}，跨 reset 保留
@property(nonatomic,assign,readwrite) BOOL lastBuildHasMention;

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

-(BOOL) ensureSystemBotsVisible {
    // : 后端 sync 在当前 Space 不返回 botfather 时的本地兜底。
    // 对齐 Android Round-3 Fix C：只合成 VM 层占位条目，绝不写入 WKSDK cache / DB，
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

        // 构建子区索引缓存（DB 查询）
        NSMutableDictionary<NSString*, NSMutableArray<WKConversation*>*> *topicsByGroup = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = [NSMutableDictionary dictionary];
        for (WKConversation *conv in conversations) {
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
                if (ts > threeDaysAgo) {
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
                if (ts > threeDaysAgo) {
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
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountBatchUpdated" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:WKThreadMessageCountUpdatedNotification object:nil];
    });
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

-(BOOL) modelMatchesFilter:(WKConversationWrapModel *)model {
    uint8_t type = model.channel.channelType;
    if (type != WK_GROUP && type != WK_PERSON) {
        return YES; // 系统通知、文件助手等特殊会话两个 tab 都显示
    }
    if (self.filterType == WKConversationFilterFollow) {
        return type == WK_GROUP;
    } else {
        return type == WK_PERSON;
    }
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
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if ([self modelMatchesFilter:model]) {
            [filtered addObject:model];
        }
    }
    self.filteredConversations = [filtered copy];
}

-(NSInteger) getFollowUnreadCount {
    NSInteger count = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType == WK_GROUP && !model.mute) {
            count += model.unreadCount;
        }
    }
    return count;
}

-(NSInteger) getRecentUnreadCount {
    NSInteger count = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType == WK_PERSON && !model.mute) {
            count += model.unreadCount;
        }
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
        if(!model.mute) {
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
    NSArray<WKConversation*> *topics = self.cachedTopicsByGroup[groupNo];
    if (topics) {
        for (WKConversation *conv in topics) {
            if (excluded.count > 0 && [excluded containsObject:conv.channel.channelId]) continue;
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
    // 1. 建立 channelId → WKConversationWrapModel 映射（仅群聊）
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *channelMap = [NSMutableDictionary dictionary];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(model.channel.channelType == WK_GROUP) {
            channelMap[model.channel.channelId] = model;
        }
    }

    NSMutableArray<WKConversationDisplayItem *> *displayList = [NSMutableArray array];
    NSMutableSet<NSString *> *groupedChannelIds = [NSMutableSet set];

    // 使用 loadConversationList 时预建的子区索引缓存，无缓存时现场构建（首次调用等边界情况）
    NSDictionary<NSString*, NSArray<WKConversation*>*> *topicsByGroup = self.cachedTopicsByGroup;
    NSDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = self.cachedRemindersByChannelId;
    if (!topicsByGroup) {
        [self rebuildTopicIndexCache];
        topicsByGroup = self.cachedTopicsByGroup ?: @{};
        remindersByChannelId = self.cachedRemindersByChannelId ?: @{};
    }

    // 2. 收集已归组的 channelId，找到 is_default 分类
    WKCategoryEntity *defaultCategory = nil;
    for (WKCategoryEntity *cat in self.categoryList) {
        if (cat.is_default) defaultCategory = cat;
        for (WKCategoryGroup *cg in cat.groups) {
            [groupedChannelIds addObject:cg.group_no];
        }
    }

    // 3. 非 default 分组
    for (WKCategoryEntity *cat in self.categoryList) {
        if (cat.is_default) continue;
        WKConversationDisplayItem *header = [WKConversationDisplayItem sectionHeaderWithId:cat.category_id title:cat.name isDefault:NO];
        // 统计分组内群聊数量 + 群聊未读 + 子区未读 + @提醒
        NSInteger count = 0;
        NSInteger totalUnread = 0;
        BOOL sectionHasMention = NO;
        for (WKCategoryGroup *cg in cat.groups) {
            WKConversationWrapModel *m = channelMap[cg.group_no];
            if (m) {
                count++;
                totalUnread += m.unreadCount;
                // 累加该群聊下所有子区的未读
                totalUnread += [self threadUnreadForGroup:cg.group_no topicsByGroup:topicsByGroup];
                // 检测群聊及子区的@提醒
                if (!sectionHasMention) {
                    sectionHasMention = [self hasMentionForGroup:cg.group_no model:m topicsByGroup:topicsByGroup remindersByChannelId:remindersByChannelId];
                }
            }
        }
        header.groupCount = count;
        header.unreadCount = totalUnread;
        header.hasMention = sectionHasMention;
        [displayList addObject:header];

        if(![self.collapsedSections containsObject:cat.category_id]) {
            NSMutableArray<WKConversationWrapModel *> *sectionItems = [NSMutableArray array];
            for (WKCategoryGroup *cg in cat.groups) {
                WKConversationWrapModel *msg = channelMap[cg.group_no];
                if(msg) [sectionItems addObject:msg];
            }
            // 置顶优先，再按时间排序
            [sectionItems sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
                if(a.stick && !b.stick) return NSOrderedAscending;
                if(!a.stick && b.stick) return NSOrderedDescending;
                if(a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
                if(a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            for (WKConversationWrapModel *m in sectionItems) {
                [displayList addObject:[WKConversationDisplayItem itemWithConversation:m]];
            }
        }
    }

    // 4. 默认分组（未归组群聊）
    NSMutableArray<WKConversationWrapModel *> *ungrouped = [NSMutableArray array];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(model.channel.channelType == WK_GROUP && ![groupedChannelIds containsObject:model.channel.channelId]) {
            [ungrouped addObject:model];
        }
    }
    [ungrouped sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
        if(a.stick && !b.stick) return NSOrderedAscending;
        if(!a.stick && b.stick) return NSOrderedDescending;
        if(a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
        if(a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    // 4. 将未归组群聊合并到服务端的 is_default 分类中显示
    if (defaultCategory) {
        // 把未归组群聊也加入 default 分类的 groups 列表一起显示
        NSMutableArray<WKConversationWrapModel *> *defaultItems = [NSMutableArray array];
        if (defaultCategory.groups) {
            for (WKCategoryGroup *cg in defaultCategory.groups) {
                WKConversationWrapModel *m = channelMap[cg.group_no];
                if (m) [defaultItems addObject:m];
            }
        }
        for (WKConversationWrapModel *m in ungrouped) {
            [defaultItems addObject:m];
        }
        [defaultItems sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
            if(a.stick && !b.stick) return NSOrderedAscending;
            if(!a.stick && b.stick) return NSOrderedDescending;
            if(a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
            if(a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];

        NSString *sectionId = defaultCategory.category_id.length > 0 ? defaultCategory.category_id : @"uncategorized";
        WKConversationDisplayItem *header = [WKConversationDisplayItem sectionHeaderWithId:sectionId title:defaultCategory.name isDefault:YES];
        header.groupCount = defaultItems.count;
        NSInteger defaultUnread = 0;
        BOOL defaultHasMention = NO;
        for (WKConversationWrapModel *m in defaultItems) {
            defaultUnread += m.unreadCount;
            defaultUnread += [self threadUnreadForGroup:m.channel.channelId topicsByGroup:topicsByGroup];
            if (!defaultHasMention) {
                defaultHasMention = [self hasMentionForGroup:m.channel.channelId model:m topicsByGroup:topicsByGroup remindersByChannelId:remindersByChannelId];
            }
        }
        header.unreadCount = defaultUnread;
        header.hasMention = defaultHasMention;
        [displayList addObject:header];
        if (![self.collapsedSections containsObject:sectionId]) {
            for (WKConversationWrapModel *m in defaultItems) {
                [displayList addObject:[WKConversationDisplayItem itemWithConversation:m]];
            }
        }
    } else if (ungrouped.count > 0) {
        // 服务端没有返回 default 分类，本地兜底显示
        for (WKConversationWrapModel *m in ungrouped) {
            [displayList addObject:[WKConversationDisplayItem itemWithConversation:m]];
        }
    }

    // 顺便计算全局 hasMention（复用已有的 remindersByChannelId，避免 updateGroupMentionBadge 重复查 DB）
    BOOL globalHasMention = NO;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType != WK_GROUP) continue;
        if (model.simpleReminders.count > 0) {
            for (WKReminder *r in model.simpleReminders) {
                if (r.type == WKReminderTypeMentionMe) { globalHasMention = YES; break; }
            }
        }
        if (globalHasMention) break;
    }
    if (!globalHasMention) {
        for (NSArray<WKReminder*> *reminders in remindersByChannelId.allValues) {
            for (WKReminder *r in reminders) {
                if (r.type == WKReminderTypeMentionMe) { globalHasMention = YES; break; }
            }
            if (globalHasMention) break;
        }
    }
    self.lastBuildHasMention = globalHasMention;

    NSLog(@"[TabPerf] buildGroupDisplayList: %.1fms items=%lu hasMention=%d", (CFAbsoluteTimeGetCurrent()-_bgStart)*1000, (unsigned long)displayList.count, globalHasMention);
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
