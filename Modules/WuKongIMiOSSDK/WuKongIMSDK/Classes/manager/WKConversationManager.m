//
//  WKConversationManager.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKConversationManager.h"
#import "WKDB.h"
#import "WKConversationDB.h"
#import "WKSDK.h"
#import "WKConversationUtil.h"
#import "WKMessageDB.h"
#import "WKReactionDB.h"
#import "WKReminderDB.h"
#import "WKConversationExtraDB.h"
@interface WKConversationManager ()
/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@end

@implementation WKConversationManager


- (void)setSyncConversationProviderAndAck:(WKSyncConversationProvider)syncConversationProvider ack:(WKSyncConversationAck)syncConversationAck {
    _syncConversationProvider = syncConversationProvider;
    _syncConversationAck = syncConversationAck;
}

-(WKConversationAddOrUpdateResult*) addOrUpdateConversation:(WKConversation*)cs incUnreadCount:(NSInteger)unUnreadCount{
    __block BOOL isInsert = false;
    __block BOOL modify = false;
    __block WKConversation *blockConversation;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        WKConversation *conversation =  [[WKConversationDB shared] getConversationWithChannelInAll:cs.channel db:db];
        if(conversation) {
            NSInteger _ut_before = conversation.unreadCount;
            conversation.unreadCount +=unUnreadCount ;
            NSLog(@"[UnreadTrace] addOrUpdate channelId=%@ type=%d before=%ld inc=%ld after=%ld lastSeq=%u",
                  cs.channel.channelId, cs.channel.channelType,
                  (long)_ut_before, (long)unUnreadCount, (long)conversation.unreadCount,
                  cs.lastMessageInner.messageSeq);
            if([self needUpdate:cs old:conversation]) { // (cs.lastMessageInner.messageSeq应该是发送的消息) 当前最近会话的最后一条消息的messageSeq小于更新的messageSeq才更新
                conversation.lastClientMsgNo = cs.lastClientMsgNo;
                conversation.lastMsgTimestamp = cs.lastMsgTimestamp;
                conversation.lastMessageSeq = cs.lastMessageInner.messageSeq;
                conversation.lastMessageInner = cs.lastMessageInner;
    //                conversation.isDeleted = cs.isDeleted;
//                [conversation.reminderManager mergeReminders:cs.reminderManager.reminders];
                modify = true;
            }
            
            if(unUnreadCount>0) {
                modify = true;
            }
            if(modify) {
                [[WKConversationDB shared] updateConversation:conversation db:db];
            }
            blockConversation = conversation;
            isInsert = false;
        }else {
            cs.unreadCount = unUnreadCount;
            [[WKConversationDB shared] insertConversation:cs db:db];
             blockConversation = cs;
            isInsert = true;
            modify = true;
        }
    }];
    return [WKConversationAddOrUpdateResult initWithInsert:isInsert modify:modify conversation:blockConversation];
}

-(BOOL) needUpdate:(WKConversation*)newConversation old:(WKConversation*)oldConversation {
    if(!newConversation.lastMessageInner) {
        return false;
    }
    uint32_t newOrderSeq = newConversation.lastMessageInner.orderSeq;
    uint32_t oldOrderSeq = [[WKSDK shared].chatManager getOrderSeq:oldConversation.lastMessageSeq];
    if(newOrderSeq>oldOrderSeq) {
        return true;
    }
    return false;
}

- (void)addConversation:(WKConversation *)conversation {
    [[WKConversationDB shared] addConversation:conversation];
}

-(void) recoveryConversation:(WKChannel*)channel {
   WKConversation *conversation = [[WKConversationDB shared] recoveryConversation:channel];
    if(conversation) {
        [self callOnConversationDeleteDelegate:conversation.channel];
    }
}

- (WKConversation *)getConversation:(WKChannel *)channel {
    WKConversation *conversation = [[WKConversationDB shared] getConversation:channel];
    conversation.reminders = [[WKReminderDB shared] getWaitDoneReminder:conversation.channel];
    return conversation;
}

-(NSArray<WKConversation*>*) getConversations:(NSArray<WKChannel*>*)channels {
   NSArray<WKConversation*> *conversations = [[WKConversationDB shared] getConversations:channels];
    if(!conversations || conversations.count == 0) {
        return conversations;
    }
    
    NSDictionary<WKChannel*,NSArray<WKReminder*>*> *reminderDicts = [WKReminderDB.shared getWaitDoneReminders:channels];
    for (WKConversation *conversation in conversations) {
        if(reminderDicts) {
            conversation.reminders = reminderDicts[conversation.channel];
        }
    }
    return conversations;
}

- (WKConversationAddOrUpdateResult *)addOrUpdateConversation:(WKConversation *)cs {
    return [self addOrUpdateConversation:cs incUnreadCount:0];
}
//
//-(WKConversation*) appendReminder:(WKReminder*) reminder channel:(WKChannel*)channel {
//    WKConversation *conversation = [[WKConversationDB shared] appendReminder:reminder channel:channel];
//    if(conversation) {
//        // 调用委托
//        [self callOnConversationUpdateDelegate:conversation];
//    }
//    return conversation;
//}
//
//-(WKReminder*) getReminder:(WKReminderType)type channel:(WKChannel*)channel {
//    WKConversation *conversation = [[WKConversationDB shared] getConversation:channel];
//    if(conversation && conversation.reminderManager.reminders && conversation.reminderManager.reminders.count>0) {
//        for (WKReminder *reminder in conversation.reminderManager.reminders) {
//            if(reminder.type == type) {
//                return reminder;
//            }
//        }
//    }
//    return nil;
//}

-(void) clearConversationUnreadCount:(WKChannel*)channel {
    // [UnreadTrace] SDK 层硬清零入口,带短调用栈定位 caller.
    NSArray *_ut_stack = [NSThread callStackSymbols];
    NSString *_ut_top = _ut_stack.count > 4 ? [[_ut_stack subarrayWithRange:NSMakeRange(1, MIN(3u, _ut_stack.count - 1))] componentsJoinedByString:@" | "] : [_ut_stack componentsJoinedByString:@" | "];
    NSLog(@"[UnreadTrace] clearConversationUnreadCount channelId=%@ type=%d caller=%@", channel.channelId, channel.channelType, _ut_top);
    // 清除指定频道消息未读数
    [[WKConversationDB shared] clearConversationUnreadCount:channel];
    // 通知UI层
    [self callOnConversationUnreadCountUpdateDelegate:channel unreadCount:0];
}

-(void) setConversationUnreadCount:(WKChannel*)channel unread:(NSInteger)unread {
    // [UnreadTrace] SDK 层硬设值入口,带短调用栈定位 caller.
    NSArray *_ut_stack = [NSThread callStackSymbols];
    NSString *_ut_top = _ut_stack.count > 4 ? [[_ut_stack subarrayWithRange:NSMakeRange(1, MIN(3u, _ut_stack.count - 1))] componentsJoinedByString:@" | "] : [_ut_stack componentsJoinedByString:@" | "];
    NSLog(@"[UnreadTrace] setConversationUnreadCount channelId=%@ type=%d unread=%ld caller=%@", channel.channelId, channel.channelType, (long)unread, _ut_top);
    // 设置指定频道消息未读数
       [[WKConversationDB shared] setConversationUnreadCount:channel unread:unread];
    // 通知UI层
       [self callOnConversationUnreadCountUpdateDelegate:channel unreadCount:unread];
}

-(void) deleteConversation:(WKChannel*)channel {
    // 删除z最近会话
    [[WKConversationDB shared] deleteConversation:channel];
    // 通知UI层
    [self callOnConversationDeleteDelegate:channel];
}
//
//-(void)  removeReminder:(WKReminderType) type channel:(WKChannel*)channel {
//    WKConversation *conversation = [[WKConversationDB shared] removeReminder:type channel:channel];
//    // 调用委托
//    if(conversation) {
//        [self callOnConversationUpdateDelegate:conversation];
//    }
//}
//
//-(void) clearAllReminder:(WKChannel*)channel {
//     WKConversation *conversation = [[WKConversationDB shared] clearAllReminder:channel];
//    // 调用委托
//    if(conversation) {
//        [self callOnConversationUpdateDelegate:conversation];
//    }
//}

//-(void) updateConversation:(WKChannel*)channel title:(NSString*)title avatar:(NSString*) avatar {
//    if(channel.channelType == WK_PERSON) {
//        // 获取收取人的用户信息
//        __block WKUserInfo *toUserInfo;
//        [WKSDK shared].userInfoProvider(channel.channelId, ^(WKUserInfo * _Nonnull userInfo) {
//            if(userInfo) {
//                
//            }
//        });
//    }
//}

-(NSArray<WKConversation*>*) getConversationList {
    if ([NSThread isMainThread]) {
        NSArray *stack = [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(8, [NSThread callStackSymbols].count - 1))];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        NSArray<WKConversation*> *result = [self _getConversationListInternal];
        CFAbsoluteTime elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000;
        if (elapsed > 30) {
            NSLog(@"[ANR-Trace] getConversationList on MAIN thread took %.0fms, count=%lu, stack:\n%@", elapsed, (unsigned long)result.count, [stack componentsJoinedByString:@"\n"]);
        }
        return result;
    }
    return [self _getConversationListInternal];
}

-(NSArray<WKConversation*>*) _getConversationListInternal {
   NSArray<WKConversation*> *conversations =  [[WKConversationDB shared] getConversationList];
    if(conversations && conversations.count>0) {
       NSDictionary<WKChannel*,NSArray<WKReminder*>*> *reminderDict = [[WKReminderDB shared] getAllWaitDoneReminders];
        if(reminderDict) {
            for (WKConversation *conversation in conversations) {
                conversation.reminders = reminderDict[conversation.channel];
            }
        }
    }
    return conversations;
}

-(void) handleSyncConversation:(WKSyncConversationWrapModel*)model {
    NSArray<WKSyncConversationModel*> *syncConversations = model.conversations;

    // DB 密集操作移到后台线程，避免阻塞主线程动画
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CFAbsoluteTime syncStart = CFAbsoluteTimeGetCurrent();

        // ########## 存储会话所有消息 ##########
        NSMutableArray *messages = [NSMutableArray array];
        if(syncConversations && syncConversations.count>0) {
            for (WKSyncConversationModel *syncConversationModel in syncConversations) {
                if(syncConversationModel.recents && syncConversationModel.recents.count>0) {
                    [messages addObjectsFromArray:syncConversationModel.recents];
                }
            }
        }
        if(messages.count>0) {
            [[WKMessageDB shared] replaceMessages:messages];
        }

        // ########## 存储所有会话 ##########
        NSMutableArray<WKConversation*> *conversations = [NSMutableArray array];
        for (WKSyncConversationModel *syncConversationModel in syncConversations) {
            [conversations addObject:syncConversationModel.conversation];
        }

        if(conversations.count>0) {
            NSMutableArray<WKChannel*> *channels = [NSMutableArray array];
            for (WKConversation *conversation in conversations) {
                [channels addObject:conversation.channel];
            }
            NSDictionary *reminderDict = [[WKReminderDB shared] getWaitDoneReminders:channels];
            if(reminderDict) {
                for (WKConversation *conversation in conversations) {
                    conversation.reminders = reminderDict[conversation.channel];
                }
            }
            [[WKConversationDB shared] mergeConversations:conversations];

            // 将同步的 stick/mute 状态写入 channel 表
            for (WKSyncConversationModel *syncModel in syncConversations) {
                // 子区(WK_COMMUNITY_TOPIC)的 mute/stick 服务端 conversation/sync 路径不查 thread_setting,
                // 对子区一律返回父群值(实际上 groupMap[topicChannelId] 找不到,返回 0),
                // 如果在这里写回本地 channelInfo.mute,会把用户已设置的子区静音状态覆盖掉。
                // 子区的 mute/stick 仅信任 thread 详情接口(WKDataSourceModule setChannelInfoUpdate 的 topic 分支)。
                if (syncModel.channel.channelType == WK_COMMUNITY_TOPIC) {
                    continue;
                }
                WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:syncModel.channel];
                if (channelInfo) {
                    BOOL needUpdate = NO;
                    if (channelInfo.stick != syncModel.stick) {
                        channelInfo.stick = syncModel.stick;
                        needUpdate = YES;
                    }
                    if (channelInfo.mute != syncModel.mute) {
                        channelInfo.mute = syncModel.mute;
                        needUpdate = YES;
                    }
                    if (needUpdate) {
                        [[WKSDK shared].channelManager updateChannelInfo:channelInfo];
                    }
                }
            }

            // UI 通知回主线程
            [self callOnConversationUpdateDelegates:conversations];
        }

        CFAbsoluteTime syncElapsed = (CFAbsoluteTimeGetCurrent() - syncStart) * 1000;
        if (syncElapsed > 30) {
            NSLog(@"[ANR-Trace] handleSyncConversation took %.0fms (background), syncCount=%lu, msgCount=%lu", syncElapsed, (unsigned long)syncConversations.count, (unsigned long)messages.count);
        }

        // DB 已写 + delegate 已通知,主线程派发 sync 完成信号,VC 用这个信号跑
        // side-effects(loadCategories 等),保证 getConversation 能拿到刚 merge
        // 进 DB 的子区行,不再被 3 天活跃过滤误删.
        [self callOnConversationSyncFinishedDelegates];
    });
}

-(void) syncExtra {
    if(!self.syncConversationExtraProvider) {
        NSLog(@"###########没有syncConversationExtraProvider###########");
        return;
    }
    int64_t version = [[WKConversationExtraDB shared] getMaxVersion];
    __weak typeof(self) weakSelf = self;
    self.syncConversationExtraProvider(version, ^(NSArray<WKConversationExtra *> * _Nullable extras, NSError * _Nullable error) {
        if(error) {
            NSLog(@"同步最近会话扩展失败！->%@",error);
            return;
        }
        [[WKConversationExtraDB shared] addOrUpdates:extras];
        [weakSelf updateConversationExtras:extras];
    });
}

-(void) updateOrAddExtra:(WKConversationExtra*)extra {
    if(!extra) {
        return;
    }
    
    [[WKConversationExtraDB shared] addOrUpdates:@[extra]];
    if(!self.updateConversationExtraProvider) {
        NSLog(@"###########没有updateConversationExtraProvider###########");
        return;
    }
    WKConversation *conversation = [[WKConversationDB shared] getConversation:extra.channel];
    if(!conversation) {
        return;
    }
    conversation.reminders = [[WKReminderDB shared] getWaitDoneReminder:conversation.channel];
    conversation.remoteExtra = extra;
    [self callOnConversationUpdateDelegate:conversation];
    
    self.updateConversationExtraProvider(extra, ^(int64_t version, NSError * _Nullable error) {
        if(error) {
            NSLog(@"更新最近会话扩展失败！->%@",error);
            return;
        }
        [[WKConversationExtraDB shared] updateVersion:extra.channel version:version];
    });
    
    
    
}

-(void) updateConversationExtras:(NSArray<WKConversationExtra*>*)converstionExtras {
    if(!converstionExtras || converstionExtras.count == 0) {
        return;
    }
    NSMutableArray *channels = [NSMutableArray array];
    NSMutableDictionary *conversationExtraDict = [NSMutableDictionary dictionary];
    for (WKConversationExtra *extra in converstionExtras) {
        [channels addObject:extra.channel];
        conversationExtraDict[extra.channel] = extra;
    }
    NSDictionary<WKChannel*,NSArray<WKReminder*>*> *reminderDict = [[WKReminderDB shared] getWaitDoneReminders:channels];
    NSArray<WKConversation*> *conversations = [[WKConversationDB shared] getConversations:channels];
    if(conversations && conversations.count>0) {
        for (WKConversation *conversation in conversations) {
            WKConversationExtra *extra = conversationExtraDict[conversation.channel];
            if(extra) {
                conversation.remoteExtra = extra;
            }
            if(reminderDict) {
                conversation.reminders = reminderDict[conversation.channel];
            }
        }
        [self callOnConversationUpdateDelegates:conversations];
    }
}


/**
 获取所有会话未读数量
 */
-(NSInteger) getAllConversationUnreadCount {
    return [[WKConversationDB shared] getAllConversationUnreadCount];
}

-(void) addDelegate:(id<WKConversationManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKConversationManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}


- (void)callOnConversationUpdateDelegate:(WKConversation *)conversation {
    [self callOnConversationUpdateDelegates:@[conversation]];
}

- (void)callOnConversationUpdateDelegates:(NSArray<WKConversation*>*)conversations {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    NSArray *callerStack = [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN(5, [NSThread callStackSymbols].count - 1))];
    for (id delegate in copyDelegates) {
        if (delegate && [delegate respondsToSelector:@selector(onConversationUpdate:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
                    [delegate onConversationUpdate:conversations];
                    CFAbsoluteTime elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000;
                    if (elapsed > 30) {
                        NSLog(@"[ANR-Trace] onConversationUpdate delegate=%@ took %.0fms, convCount=%lu, callerStack:\n%@", NSStringFromClass([delegate class]), elapsed, (unsigned long)conversations.count, [callerStack componentsJoinedByString:@"\n"]);
                    }
                });
            }else {
                [delegate onConversationUpdate:conversations];
            }
        }
    }
}

- (void)callOnConversationUnreadCountUpdateDelegate:(WKChannel*)channel unreadCount:(NSInteger)unreadCount{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if (delegate && [delegate respondsToSelector:@selector(onConversationUnreadCountUpdate:unreadCount:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onConversationUnreadCountUpdate:channel unreadCount:unreadCount];
                });
            }else {
                [delegate onConversationUnreadCountUpdate:channel unreadCount:unreadCount];
            }
            
        }
    }
}


- (void)callOnConversationDeleteDelegate:(WKChannel*)channel{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if (delegate && [delegate respondsToSelector:@selector(onConversationDelete:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onConversationDelete:channel];
                });
            }else {
                [delegate onConversationDelete:channel];
            }
        }
    }
}

- (void)callOnConversationAllDeleteDelegate{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if (delegate && [delegate respondsToSelector:@selector(onConversationAllDelete)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onConversationAllDelete];
                });
            }else {
                [delegate onConversationAllDelete];
            }

        }
    }
}

- (void)callOnConversationSyncFinishedDelegates {
    [self.delegateLock lock];
    NSHashTable *copyDelegates = [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {
        if (delegate && [delegate respondsToSelector:@selector(onConversationSyncFinished)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onConversationSyncFinished];
                });
            } else {
                [delegate onConversationSyncFinished];
            }
        }
    }
}


@end
