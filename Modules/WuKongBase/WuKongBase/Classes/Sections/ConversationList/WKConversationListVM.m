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
@interface WKConversationListVM ()
@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *conversationWrapModels;
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
    }
    return self;
}

- (void)reset {
    [self.conversationWrapModels removeAllObjects];
    self.syncedGroupChannelIds = nil; // 重置白名单
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
    if(conversations) {
        for (WKConversation *conversation in conversations) {
            // 空间隔离：过滤不属于当前空间的会话
            if(![self shouldShowConversation:conversation]) {
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

    self.conversationWrapModels = conversationWrapModels;
    [self sortConversationList];

    // 先请求子区数据，全部完成后再回调 finished（避免 reloadData 后再异步更新导致闪烁）
    [self fetchThreadCountsForGroupsWithCompletion:^{
        if(finished) {
            finished();
        }
    }];
}

/// 通过 API 获取每个群组的子区真实数量（带完成回调）
-(void) fetchThreadCountsForGroupsWithCompletion:(void(^)(void))completion {
    // 收集需要请求的群组
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
    __weak typeof(self) weakSelf = self;

    for (WKConversationWrapModel *model in groupModels) {
        NSString *groupNo = model.channel.channelId;
        dispatch_group_enter(group);
        [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
            NSArray *sorted = [threads sortedArrayUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
                return [b.updatedAt compare:a.updatedAt];
            }];
            NSMutableArray *activePreviews = [NSMutableArray array];
            for (WKThreadModel *t in sorted) {
                if (t.status == WKThreadStatusActive) {
                    [activePreviews addObject:t];
                }
            }
            model.threadCount = activePreviews.count;
            if (activePreviews.count > 2) {
                model.threadPreviews = [activePreviews subarrayWithRange:NSMakeRange(0, 2)];
            } else {
                model.threadPreviews = [activePreviews copy];
            }
            dispatch_group_leave(group);
        }).catch(^(NSError *error) {
            dispatch_group_leave(group);
        });
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion();
    });
}

/// 兼容旧调用
-(void) fetchThreadCountsForGroups {
    [self fetchThreadCountsForGroupsWithCompletion:nil];
}

/// 刷新指定群组的子区数量
-(void) refreshThreadCountForGroups:(NSSet<NSString*>*)groupNos {
    for (NSString *groupNo in groupNos) {
        WKChannel *groupChannel = [WKChannel groupWithChannelID:groupNo];
        WKConversationWrapModel *model = [self getConversationWrap:groupChannel conversations:self.conversationWrapModels];
        if (!model) continue;
        __weak typeof(self) weakSelf = self;
        [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel*> *threads) {
            NSArray *sorted = [threads sortedArrayUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
                return [b.updatedAt compare:a.updatedAt];
            }];
            NSMutableArray *activePreviews = [NSMutableArray array];
            for (WKThreadModel *t in sorted) {
                if(t.status == WKThreadStatusActive) {
                    [activePreviews addObject:t];
                }
            }
            model.threadCount = activePreviews.count;
            if (activePreviews.count > 2) {
                model.threadPreviews = [activePreviews subarrayWithRange:NSMakeRange(0, 2)];
            } else {
                model.threadPreviews = [activePreviews copy];
            }
            // 同步更新 messageCountCache（供群聊页面子区卡片使用）
            for (WKThreadModel *t in activePreviews) {
                if (t.channelId.length > 0) {
                    [WKThreadCreatedContent messageCountCache][t.channelId] = @(t.messageCount);
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger index = [weakSelf indexAtChannel:groupChannel];
                if(index != -1) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"WKThreadCountUpdated" object:groupChannel];
                }
                // 通知群聊页面刷新子区卡片消息数量
                [[NSNotificationCenter defaultCenter] postNotificationName:WKThreadMessageCountUpdatedNotification object:nil];
            });
        }).catch(^(NSError *error) {
        });
    }
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
    for (WKConversationWrapModel *conversation in self.conversationWrapModels) {
        if([conversation.channel isEqual:wrapModel.parentChannel]) {
            [self handleProhibitwords:wrapModel];
            [conversation addOrUpdateChildren:wrapModel];
            return conversation;
        }
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
}

-(NSArray<WKConversationWrapModel*> *) conversationList {
    // [_conversationsLock lock];
    NSArray<WKConversationWrapModel*> *data =  self.conversationWrapModels;
    // [_conversationsLock unlock];
    return data;
}

-(NSInteger) conversationCount {
     // [_conversationsLock lock];
    NSInteger count = [self.conversationWrapModels count];
    // [_conversationsLock unlock];
    return count;
}
-(NSInteger) indexAtChannel:(WKChannel*)channel {
     // [_conversationsLock lock];
    if( self.conversationWrapModels) {
        for (int i=0; i< self.conversationWrapModels.count; i++) {
            WKConversationWrapModel *conversation = self.conversationWrapModels[i];
            if([conversation.channel isEqual:channel]) {
                 // [_conversationsLock unlock];
                return i;
            }
        }
    }
    // [_conversationsLock unlock];
    return -1;
    
}

-(WKConversationWrapModel*) modelAtChannel:(WKChannel*) channel {
    // [_conversationsLock lock];
    if( self.conversationWrapModels) {
        for (int i=0; i< self.conversationWrapModels.count; i++) {
            WKConversationWrapModel *conversation = self.conversationWrapModels[i];
            if([conversation.channel isEqual:channel]) {
                // [_conversationsLock unlock];
                return conversation;
            }
        }
    }
    // [_conversationsLock unlock];
    return nil;
}

-(WKConversationWrapModel*) modelAtIndex:(NSInteger)index {
    // [_conversationsLock lock];
    WKConversationWrapModel *conversation = self.conversationWrapModels[index];
    // [_conversationsLock unlock];
    return conversation;
}

-(void) replaceAtChannel:(WKConversationWrapModel*)model atChannel:(WKChannel*)channel  {
     NSInteger index =[self indexAtChannel:channel];
    if(index!=-1) {
         // [_conversationsLock lock];
        // 继承旧 model 的子区数量和预览
        WKConversationWrapModel *oldModel = self.conversationWrapModels[index];
        if(oldModel.threadCount > 0 && model.threadCount == 0) {
            model.threadCount = oldModel.threadCount;
        }
        if(oldModel.threadPreviews.count > 0 && model.threadPreviews.count == 0) {
            model.threadPreviews = oldModel.threadPreviews;
        }
        [self handleProhibitwords:model];
        [self.conversationWrapModels replaceObjectAtIndex:index withObject:model];
         // [_conversationsLock unlock];
    }
}
-(void) replaceObjectAtIndex:(NSInteger)index withObject:(WKConversationWrapModel*)model{
    // [self.conversationsLock lock];
    [self handleProhibitwords:model];
    [self.conversationWrapModels replaceObjectAtIndex:index withObject:model];
    // [self.conversationsLock unlock];
}

-(void) removeAtChannnel:(WKChannel*)channel {
   NSInteger index = [self indexAtChannel:channel];
    if(index!=-1) {
        // [self.conversationsLock lock];
        [self.conversationWrapModels removeObjectAtIndex:index];
        // [self.conversationsLock unlock];
    }
}

-(void) removeAtIndex:(NSInteger)index {
    // [self.conversationsLock lock];
    [self.conversationWrapModels removeObjectAtIndex:index];
    // [self.conversationsLock unlock];
}


-(void) removeAll {
    // [self.conversationsLock lock];
    [self.conversationWrapModels removeAllObjects];
    // [self.conversationsLock unlock];
}

-(void) insert:(WKConversationWrapModel*)model atIndex:(NSInteger)insert {
     // [self.conversationsLock lock];
    if(insert>self.conversationWrapModels.count) {
        WKLogWarn(@"warn: conversationWrapModels数组大小->%ld insert的大小%ld",(long)self.conversationWrapModels.count,(long)insert);
        return;
    }
    [self handleProhibitwords:model];
    [self.conversationWrapModels insertObject:model atIndex:insert];
   
    // [self.conversationsLock unlock];
}

-(NSInteger) insert:(WKConversationWrapModel*)model {
    [self  handleProhibitwords:model];
    WKConversationWrapModel *conversationWrapModel = [self getRealShowConversationWrap:model];
    NSInteger insertPlace =  [self findInsertPlace:conversationWrapModel];
    [self.conversationWrapModels insertObject:conversationWrapModel atIndex:insertPlace];
    
    return insertPlace;
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
    if(index>=self.conversationWrapModels.count) {
        return nil;
    }
    // [_conversationsLock lock];
    WKConversationWrapModel *model =  [self.conversationWrapModels objectAtIndex:index];
    // [_conversationsLock unlock];
    return model;
}

-(void) removeConversationAtIndex:(NSInteger)index {
    // [_conversationsLock lock];
    if(index<self.conversationWrapModels.count) {
        [self.conversationWrapModels removeObjectAtIndex:index];
    }
    // [_conversationsLock unlock];
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
     // [_conversationsLock lock];
    NSInteger unreadCount = 0;
    for (WKConversationWrapModel *model in self.conversationWrapModels) {
        if(!model.mute) {
            unreadCount +=model.unreadCount;
        }
    }
    // [_conversationsLock unlock];
    return unreadCount;
}
@end
