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
@interface WKConversationListVM ()
@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *conversationWrapModels;
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKConversationWrapModel*> *channelIndex; // channel key → model, O(1) lookup
@property(nonatomic,strong) NSArray<WKConversationWrapModel*> *filteredConversations; // 过滤后的列表
@property(nonatomic,strong) NSRecursiveLock *conversationsLock;
@property(nonatomic,strong) NSSet<NSString*> *syncedGroupChannelIds; // 当前空间的合法群聊白名单

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
    self.syncedGroupChannelIds = nil; // 重置白名单
    self.categoryList = @[];
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

-(void) loadConversationList:(void(^)(void)) finished {
    NSMutableArray<WKConversationWrapModel*> *conversationWrapModels = [[NSMutableArray alloc] init];
    NSArray<WKConversation*> *conversations = [[[WKSDK shared] conversationManager] getConversationList];
    NSLog(@"[ConvDebug] loadConversationList: DB returned %lu conversations, syncedGroupChannelIds=%@", (unsigned long)conversations.count, self.syncedGroupChannelIds ? [NSString stringWithFormat:@"%lu items", (unsigned long)self.syncedGroupChannelIds.count] : @"nil");
    NSInteger filteredCount = 0;
    if(conversations) {
        for (WKConversation *conversation in conversations) {
            // 空间隔离：过滤不属于当前空间的会话
            if(![self shouldShowConversation:conversation]) {
                filteredCount++;
                continue;
            }
            // 子区完全不显示在会话列表
            if(conversation.channel.channelType == WK_COMMUNITY_TOPIC) {
                continue;
            }
            WKConversationWrapModel *wrapModel = [[WKConversationWrapModel alloc] initWithConversation:conversation];
            if(conversation.parentChannel) {

                WKConversationWrapModel *parentConversationWrapModel = [self addOrCreateParentConversation:conversation.parentChannel newConversationWrapModel:wrapModel conversationWrapModels:conversationWrapModels];

                if(parentConversationWrapModel) {
                    [self handleProhibitwords:parentConversationWrapModel];
                    [conversationWrapModels addObject:parentConversationWrapModel];
                }
            }else {
                [self handleProhibitwords:wrapModel];
                [conversationWrapModels addObject:wrapModel];
            }
        }
    }

    // 从旧 model 继承 threadPreviews/threadCount（避免重建后子区预览丢失）
    if (self.conversationWrapModels.count > 0) {
        NSMutableDictionary *oldThreadData = [NSMutableDictionary dictionary];
        for (WKConversationWrapModel *old in self.conversationWrapModels) {
            if (old.threadPreviews.count > 0) {
                oldThreadData[old.channel.channelId] = @{
                    @"previews": old.threadPreviews,
                    @"count": @(old.threadCount)
                };
            }
        }
        for (WKConversationWrapModel *model in conversationWrapModels) {
            NSDictionary *data = oldThreadData[model.channel.channelId];
            if (data) {
                model.threadPreviews = data[@"previews"];
                model.threadCount = [data[@"count"] integerValue];
            }
        }
    }

    NSLog(@"[ConvDebug] loadConversationList: filtered=%ld, final models=%lu", (long)filteredCount, (unsigned long)conversationWrapModels.count);
    self.conversationWrapModels = conversationWrapModels;
    [self rebuildChannelIndex];

    // 从 DB 恢复每个会话的 reminders（@提醒等）
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        WKConversation *conv = [model getConversation];
        if (!conv.reminders || conv.reminders.count == 0) {
            NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
            if (reminders.count > 0) {
                conv.reminders = reminders;
            }
        }
    }

    [self sortConversationList];

    // 立即回调渲染列表（不阻塞等待 thread API，避免网络异常时列表卡死）
    if(finished) {
        finished();
    }

    // 异步请求子区数据，完成后通知刷新
    [self fetchThreadCountsForGroups];
}

/// 通过 API 获取每个群组的子区真实数量（带完成回调）
/// 并发限流：最多同时 3 个请求，避免启动时瞬间打出 N 个并发
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
    dispatch_semaphore_t rateLimiter = dispatch_semaphore_create(3);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (WKConversationWrapModel *model in groupModels) {
            NSString *groupNo = model.channel.channelId;
            dispatch_semaphore_wait(rateLimiter, DISPATCH_TIME_FOREVER);
            dispatch_group_enter(group);
            [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
                NSArray *sorted = [threads sortedArrayUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
                    return [b.updatedAt compare:a.updatedAt];
                }];
                NSMutableArray *activePreviews = [NSMutableArray array];
                for (WKThreadModel *t in sorted) {
                    if (t.status == WKThreadStatusActive) [activePreviews addObject:t];
                }
                model.threadCount = activePreviews.count;
                model.threadPreviews = activePreviews.count > 2
                    ? [activePreviews subarrayWithRange:NSMakeRange(0, 2)]
                    : [activePreviews copy];
                dispatch_semaphore_signal(rateLimiter);
                dispatch_group_leave(group);
            }).catch(^(NSError *error) {
                dispatch_semaphore_signal(rateLimiter);
                dispatch_group_leave(group);
            });
        }
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (completion) completion();
        });
    });
}

/// 拉取所有群组的子区数量，完成后统一通知 VC 刷新（不再逐个发通知）
-(void) fetchThreadCountsForGroups {
    [self fetchThreadCountsForGroupsWithCompletion:^{
        // 所有子区数据到达后，发一次统一刷新通知（避免大量逐行通知导致 tableView 卡死）
        [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountBatchUpdated" object:nil];
    }];
}

/// 刷新指定群组的子区数量（批量请求，统一刷新，最多 3 个并发）
-(void) refreshThreadCountForGroups:(NSSet<NSString*>*)groupNos {
    NSMutableArray<WKConversationWrapModel *> *models = [NSMutableArray array];
    for (NSString *groupNo in groupNos) {
        WKConversationWrapModel *model = [self modelAtChannel:[WKChannel groupWithChannelID:groupNo]];
        if (model) [models addObject:model];
    }
    if (models.count == 0) return;

    dispatch_group_t batchGroup = dispatch_group_create();
    dispatch_semaphore_t rateLimiter = dispatch_semaphore_create(3);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (WKConversationWrapModel *model in models) {
            NSString *groupNo = model.channel.channelId;
            dispatch_semaphore_wait(rateLimiter, DISPATCH_TIME_FOREVER);
            dispatch_group_enter(batchGroup);
            [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
                NSArray *sorted = [threads sortedArrayUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
                    return [b.updatedAt compare:a.updatedAt];
                }];
                NSMutableArray *activePreviews = [NSMutableArray array];
                for (WKThreadModel *t in sorted) {
                    if (t.status == WKThreadStatusActive) [activePreviews addObject:t];
                }
                model.threadCount = activePreviews.count;
                model.threadPreviews = activePreviews.count > 2
                    ? [activePreviews subarrayWithRange:NSMakeRange(0, 2)]
                    : [activePreviews copy];
                for (WKThreadModel *t in activePreviews) {
                    if (t.channelId.length > 0) {
                        [WKThreadCreatedContent messageCountCache][t.channelId] = @(t.messageCount);
                    }
                }
                dispatch_semaphore_signal(rateLimiter);
                dispatch_group_leave(batchGroup);
            }).catch(^(NSError *error) {
                dispatch_semaphore_signal(rateLimiter);
                dispatch_group_leave(batchGroup);
            });
        }
        dispatch_group_notify(batchGroup, dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountBatchUpdated" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:WKThreadMessageCountUpdatedNotification object:nil];
        });
    });
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
    // 群聊：群聊消息不带space_id，无法通过消息内容判断归属空间
    // 使用sync后记录的白名单过滤：
    //   - nil: 尚未sync（首次启动DB清空后），暂不过滤
    //   - 空集合: sync完成但当前空间无群聊，过滤掉所有群聊
    //   - 非空: 只显示白名单中的群聊
    if(conversation.channel.channelType == WK_GROUP) {
        if(self.syncedGroupChannelIds) {
            return [self.syncedGroupChannelIds containsObject:conversation.channel.channelId];
        }
        return YES; // 白名单未初始化（首次sync前），暂不过滤
    }

    // Person 频道直接放行（不按 lastMessage.space_id 过滤，避免跨 Space 私聊会话消失）
    // 消息级隔离在聊天页面内独立处理（shouldShowMessageInCurrentSpace）
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
    if (self.filterType == WKConversationFilterGroup) {
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

-(NSInteger) getGroupUnreadCount {
    NSInteger count = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if (model.channel.channelType == WK_GROUP && !model.mute) {
            count += model.unreadCount;
        }
    }
    return count;
}

-(NSInteger) getPrivateUnreadCount {
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

-(NSArray<WKConversationDisplayItem *> *) buildGroupDisplayList {
    // 1. 建立 channelId → WKConversationWrapModel 映射（仅群聊）
    NSMutableDictionary<NSString *, WKConversationWrapModel *> *channelMap = [NSMutableDictionary dictionary];
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(model.channel.channelType == WK_GROUP) {
            channelMap[model.channel.channelId] = model;
        }
    }

    NSMutableArray<WKConversationDisplayItem *> *displayList = [NSMutableArray array];
    NSMutableSet<NSString *> *groupedChannelIds = [NSMutableSet set];

    // 缓存一次子区会话列表，避免在循环中重复从 DB 查询
    NSArray<WKConversation *> *cachedAllConvs = [[WKSDK shared].conversationManager getConversationList];

    // 预建索引：O(总会话数) 一次遍历，把 O(群聊数×总会话数) 的嵌套遍历降为 O(子区数) 查找
    // topicsByGroup:        groupId → [WKConversation*]（该群下所有子区会话）
    // remindersByChannelId: channelId → [WKReminder*]（子区的 reminder，一次性批量 DB 查询）
    NSMutableDictionary<NSString*, NSMutableArray<WKConversation*>*> *topicsByGroup = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString*, NSArray<WKReminder*>*> *remindersByChannelId = [NSMutableDictionary dictionary];
    for (WKConversation *conv in cachedAllConvs) {
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
