//
//  WKConversationDB.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKConversationDB.h"
#import "WKDB.h"
#import "WKConversationUtil.h"
#import "WKUnreadStore.h"
#import "WKUnreadAckQueueDB.h"
#import "WKConversationSpaceDB.h"
#define SQL_EXIST @"select count(*) cn from conversation where channel_id=? and channel_type=? and is_deleted=0"

#define SQL_GET_SELECT @"conversation.*,IFNULL(channel.stick,0) stick,IFNULL(channel.mute,0) mute,IFNULL(conversation_extra.browse_to,0) browse_to,IFNULL(conversation_extra.keep_message_seq,0) keep_message_seq,IFNULL(conversation_extra.keep_offset_y,0) keep_offset_y,IFNULL(conversation_extra.draft,'') draft,IFNULL(conversation_extra.version,0) extra_version"

#define SQL_GET [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type   where conversation.channel_id=? and conversation.channel_type=? and conversation.is_deleted=0",SQL_GET_SELECT]

#define SQL_GET_WITH_CHANNELS [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type   where conversation.is_deleted=0 and conversation.channel_id in ",SQL_GET_SELECT]

// 把channel里的stick和mute查询出来 为了防止排序conversation的时候去循环获取频道信息，最近会话过多会导致卡顿
#define SQL_GET_IN_ALL [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type  where conversation.channel_id=? and conversation.channel_type=?",SQL_GET_SELECT]

#define SQL_ALL [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type where conversation.is_deleted=0 order by conversation.last_msg_timestamp desc,conversation.id desc",SQL_GET_SELECT]

#define SQL_INSERT @"insert into conversation(channel_id,channel_type,parent_channel_id,parent_channel_type,avatar,last_client_msg_no,last_message_seq,last_msg_timestamp,unread_count,extra,version,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?)"

#define SQL_REPLACE @"insert into conversation(channel_id,channel_type,parent_channel_id,parent_channel_type,avatar,last_client_msg_no,last_message_seq,last_msg_timestamp,unread_count,extra,version,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(channel_id,channel_type) DO UPDATE SET parent_channel_id=excluded.parent_channel_id,parent_channel_type=excluded.parent_channel_type,last_client_msg_no=excluded.last_client_msg_no,last_message_seq=excluded.last_message_seq,last_msg_timestamp=excluded.last_msg_timestamp,unread_count=excluded.unread_count,version=excluded.version,is_deleted=excluded.is_deleted"

// 更新最新消息
#define SQL_UPDATE_LASTMSG @"update conversation set last_client_msg_no=?,last_message_seq=?,last_msg_timestamp=?,unread_count=?,is_deleted=0 where channel_id=? and channel_type=?"
// 更新用户标题
#define SQL_UPDATE_TITLEANDAVATAR @"update conversation set title=?,avatar=? where channel_id=? and channel_type=?"
// 清空频道未读消息数量
#define SQL_CLEAR_UNREADCOUNT @"update conversation set unread_count=0 where channel_id=? and channel_type=?"
// 设置频道未读消息数量
#define SQL_SET_UNREADCOUNT @"update conversation set unread_count=? where channel_id=? and channel_type=?"
// 更新提醒字段
#define SQL_UPDATE_REMINDERS @"update conversation set reminders=? where channel_id=? and channel_type=?"
// 通过最后一条消息的编号获取消息
#define SQL_GET_WITH_LASTCLIENTMSGNO [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type  where conversation.last_client_msg_no=? and conversation.is_deleted=0",SQL_GET_SELECT]
// 所有会话未读数量
#define SQL_GET_ALL_UNREADCOUNT @"select sum(unread_count) unreadCount from conversation where is_deleted=0"
// 删除最近会话
#define SQL_DELETE_CONVERSATION @"update conversation set is_deleted=1 where channel_id=? and channel_type=?"
// 删除所有最近会话
#define SQL_DELETE_ALL_CONVERSATION @"delete from conversation"
// 恢复最近会话
#define SQL_RECOVERY_CONVERSATION @"update conversation set is_deleted=0 where channel_id=? and channel_type=?"

//获取会话最大版本
#define SQL_MAX_VERSION @"select IFNULL(MAX(version),0) version from conversation where version <> ''"

// 获取同步key
#define SQL_SYNC_KEY @"select GROUP_CONCAT(channel_id||':'||channel_type||':'||last_msg_seq,'|') synckey from (select *,(select max(message_seq) from message where message.channel_id=conversation.channel_id and message.channel_type= conversation.channel_type and message.content_type<>0 and message.content_type<>? limit 1) last_msg_seq from conversation) cn where channel_id<>''"

// 更新预览至
#define SQL_UPDATE_BROWSETO @"update conversation set browse_to=? where channel_id=? and channel_type=?"

// 空间作用域子句（见 -spaceScopeClauseWithAlias:）。
// conversation_space 表由 migration 202608051200 建立，写入方见 WKConversationSpaceDB。
#define SQL_SPACE_SCOPE_FMT @" exists(select 1 from conversation_space cs where cs.channel_id=%@.channel_id and cs.channel_type=%@.channel_type and cs.space_id=?)"

@interface WKConversationDB ()
@property (nonatomic, strong) NSRecursiveLock *scopeLock;
@end

@implementation WKConversationDB

// getter/setter 都自定义了（加锁），需要显式 synthesize 出 ivar
@synthesize spaceScopeId = _spaceScopeId;

static WKConversationDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKConversationDB *)shared
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
        _scopeLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

#pragma mark - 空间作用域

/// 会话列表 / 同步版本号 / syncKey 三条读路径的空间作用域。
///
/// 背景：上层原先靠 `deleteAllConversation + 全量 sync` 保证 "DB 里只有当前空间的会话"，
/// 每次冷启动 / 切空间都把本地缓存丢掉（断网时列表全空）。改成 DB 保留多空间会话 +
/// 读路径按空间过滤后，缓存得以复用。
///
/// 作用域只有一个开关条件：spaceScopeId 非空就生效，只返回 conversation_space 里
/// 归属于它的会话。某空间归属为 0 行（从未同步过该空间）时返回空列表 —— 与原先
/// "清库后等 sync" 的行为一致。
///
/// ⚠️ 历史坑：这里曾经额外有一条 "conversation_space 整表为空 → 作用域 Off（返回 DB
/// 全部会话）" 的升级兼容态。它在「升级后首次全量 sync 还没落地就切空间」时会把上一个
/// 空间的会话整片漏进新空间（用户实测到的跨空间污染）。**不要**再把"表空"当成"不过滤"。
///
/// 注：这条禁令仍然成立，但它原本给的理由（"兼容性改由一次性回填解决"）已经失效 ——
/// 那个整表回填在 8431d8e 被删除了（它自己导致了另一起列表串空间事故，见
/// WKConvListCache 的 kWKConvSpaceIndexVersion v3 注释）。现在的机制是：归属由权威全量
/// sync 逐空间重建（version==0 → replaceMembership），"表空"只代表"这个空间还没被同步
/// 过"，正确行为就是返回空列表并等 sync —— 恰恰**不能**退化成"不过滤"。
-(void) setSpaceScopeId:(NSString *)spaceScopeId {
    [self.scopeLock lock];
    if(_spaceScopeId != spaceScopeId && ![_spaceScopeId isEqualToString:spaceScopeId]) {
        NSLog(@"[SpaceIndex] setSpaceScopeId %@ → %@", _spaceScopeId ?: @"<nil>", spaceScopeId ?: @"<nil>");
        _spaceScopeId = [spaceScopeId copy];
    }
    [self.scopeLock unlock];
}

-(NSString *)spaceScopeId {
    [self.scopeLock lock];
    NSString *result = _spaceScopeId;
    [self.scopeLock unlock];
    return result;
}

/// 作用域是否生效。生效时调用方必须把 spaceScopeId 作为 SQL 参数补在末尾。
/// 见 setSpaceScopeId: 的注释：**不要**再加"归属表为空就不过滤"的条件。
-(BOOL) spaceScopeActive {
    return self.spaceScopeId.length > 0;
}

/// alias 是 SQL 中 conversation 表的名字/别名。作用域关闭时返回空串。
-(NSString*) spaceScopeClauseWithAlias:(NSString*)alias {
    if(![self spaceScopeActive]) return @"";
    return [NSString stringWithFormat:SQL_SPACE_SCOPE_FMT, alias, alias];
}

-(void) addOrUpdateConversation:(WKConversation*)conversation{
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        bool exist = [self existConversation:conversation.channel db:db];
        if(exist) {
            [self updateConversation:conversation db:db];
        }else{
             [self insertConversation:conversation db:db];
        }
    }];
}

-(void) replaceConversations:(NSArray<WKConversation*>*)conversations {
    if(!conversations || conversations.count<=0) {
        return;
    }
   
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKConversation *conversation in conversations) {
            NSString *parentChannelID  = conversation.parentChannel?conversation.parentChannel.channelId:@"";
            uint8_t parentChannelType = conversation.parentChannel?conversation.parentChannel.channelType:0;
            NSString *extraStr = [self extraToStr:conversation.extra];
            // [UnreadTrace] sync 全量覆盖：把 server 快照的 unreadCount 写回 DB,
            // 如果它比当前内存/DB 中刚 +1 的值小,会把红点擦掉.
            WKConversation *_ut_old = [self getConversationWithChannelInAll:conversation.channel db:db];
            NSLog(@"[UnreadTrace] replaceConversations channelId=%@ type=%d dbBefore=%ld serverSnapshot=%ld lastSeqBefore=%u lastSeqAfter=%u version=%lld",
                  conversation.channel.channelId, conversation.channel.channelType,
                  (long)_ut_old.unreadCount, (long)conversation.unreadCount,
                  _ut_old.lastMessageSeq, conversation.lastMessageSeq,
                  conversation.version);
            [db executeUpdate:SQL_REPLACE,conversation.channel.channelId,@(conversation.channel.channelType),parentChannelID,@(parentChannelType),conversation.avatar?:@"",conversation.lastClientMsgNo?:@"",@(conversation.lastMessageSeq),@(conversation.lastMsgTimestamp),@(conversation.unreadCount),extraStr,@(conversation.version),@(conversation.isDeleted)];
        }
    }];
}

-(NSDictionary<NSString*, NSNumber*>*) mergeConversations:(NSArray<WKConversation*>*)conversations {
    if(!conversations || conversations.count<=0) {
        return @{};
    }
    // FIX(reentrancy): prefetch reconcile context 在进 inTransaction 之前一次拉完
    // (pending ack keys + unread_state map), 避免 reconcileServerSnapshot 内部
    // 再开 [dbQueue inDatabase:] 触发 FMDB 重入. 同 sync 批可能 250+ 行,
    // prefetch 一次 vs 250 次单 query, 性能也好得多.
    WKUnreadReconcileContext *reconcileCtx = [[WKUnreadStore shared] prefetchReconcileContext];
    // channelKey ("type:id") → reconcile 后真正写进 DB 的 unread.调用方需要回填到
    // 内存中的 WKConversation.unreadCount 再 dispatch UI delegate, 否则 server 原始
    // unread 会替换掉本地刚 +1 的真值(场景: 锁屏期间 socket 重连后 sync 接口返回的
    // unread 比真实少, mergeConversations 通过 reconcile 守住了 DB,但 callDelegate
    // 收到的 conversation.unreadCount 还是 server 原值, UI 红点被擦掉).
    NSMutableDictionary<NSString*, NSNumber*> *reconciledUnread = [NSMutableDictionary dictionaryWithCapacity:conversations.count];

    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKConversation *conversation in conversations) {
            // 1) 拒收"空白行": server 偶尔会给系统通道(botfather / fileHelper /
            //    notification / u_10000)返回 version=0 && last_msg_seq=0 的占位条目,
            //    裸 REPLACE 会把本地真实状态(unread=1, lastSeq=298)整行擦成 0.
            //    放过新会话(local 不存在)的"全 0 但 timestamp 非 0"行: 那是真新建.
            WKConversation *local = [self getConversationWithChannelInAll:conversation.channel db:db];
            BOOL serverIsBlank = (conversation.version <= 0
                                  && conversation.lastMessageSeq == 0
                                  && conversation.unreadCount == 0
                                  && conversation.lastMsgTimestamp <= 0);
            if (serverIsBlank && local) {
                NSLog(@"[UnreadTrace] mergeConversations REJECT-BLANK channelId=%@ type=%d localUnread=%ld localLastSeq=%u",
                      conversation.channel.channelId, conversation.channel.channelType,
                      (long)local.unreadCount, local.lastMessageSeq);
                // 拒收的行: 也把 local 真值塞回 map, 让 caller 能用同一份数据 dispatch.
                NSString *keyB = [NSString stringWithFormat:@"%d:%@", conversation.channel.channelType, conversation.channel.channelId ?: @""];
                reconciledUnread[keyB] = @(local.unreadCount);
                continue;
            }

            NSString *parentChannelID  = conversation.parentChannel?conversation.parentChannel.channelId:@"";
            uint8_t parentChannelType = conversation.parentChannel?conversation.parentChannel.channelType:0;
            NSString *extraStr = [self extraToStr:conversation.extra];

            NSString *keyInsert = [NSString stringWithFormat:@"%d:%@", conversation.channel.channelType, conversation.channel.channelId ?: @""];
            if (!local) {
                // 新会话直接插入
                NSLog(@"[UnreadTrace] mergeConversations INSERT channelId=%@ type=%d unread=%ld lastSeq=%u version=%lld",
                      conversation.channel.channelId, conversation.channel.channelType,
                      (long)conversation.unreadCount, conversation.lastMessageSeq, conversation.version);
                [db executeUpdate:SQL_REPLACE,conversation.channel.channelId,@(conversation.channel.channelType),parentChannelID,@(parentChannelType),conversation.avatar?:@"",conversation.lastClientMsgNo?:@"",@(conversation.lastMessageSeq),@(conversation.lastMsgTimestamp),@(conversation.unreadCount),extraStr,@(conversation.version),@(conversation.isDeleted)];
                reconciledUnread[keyInsert] = @(conversation.unreadCount);
                continue;
            }

            // 2) 对已有会话: server.version > local.version 才覆盖元数据.
            //    unread 走 WKUnreadStore.reconcileServerSnapshot —— 本地优先策略
            //    (用户已读过 / pending ack / 60s 保护窗口 三档),解决子区 server
            //    永远=1 + 锁屏后红点复活两个 bug.
            BOOL takeMeta = (conversation.version > local.version);
            uint32_t newLastSeq = takeMeta ? MAX(conversation.lastMessageSeq, local.lastMessageSeq) : local.lastMessageSeq;
            int64_t newTs = takeMeta ? MAX(conversation.lastMsgTimestamp, local.lastMsgTimestamp) : local.lastMsgTimestamp;
            NSString *newClientMsgNo = takeMeta && conversation.lastClientMsgNo.length > 0 ? conversation.lastClientMsgNo : (local.lastClientMsgNo ?: @"");
            NSString *newAvatar = takeMeta && conversation.avatar.length > 0 ? conversation.avatar : (local.avatar ?: @"");
            NSString *newExtraStr = takeMeta ? extraStr : [self extraToStr:local.extra];
            int64_t newVersion = MAX(conversation.version, local.version);
            NSInteger newUnread = [[WKUnreadStore shared] reconcileServerSnapshot:conversation.channel
                                                                     serverUnread:conversation.unreadCount
                                                                    serverLastSeq:conversation.lastMessageSeq
                                                                      localUnread:local.unreadCount
                                                                          context:reconcileCtx];
            BOOL newIsDeleted = takeMeta ? conversation.isDeleted : local.isDeleted;
            // parent 字段沿用 server 端(子区不会换爹)
            NSString *newParentChannelID = parentChannelID.length > 0 ? parentChannelID : (local.parentChannel ? local.parentChannel.channelId : @"");
            uint8_t newParentChannelType = parentChannelType > 0 ? parentChannelType : (local.parentChannel ? local.parentChannel.channelType : 0);

            NSLog(@"[UnreadTrace] mergeConversations MERGE channelId=%@ type=%d local(unread=%ld,seq=%u,ver=%lld) server(unread=%ld,seq=%u,ver=%lld) -> (unread=%ld,seq=%u,ver=%lld) takeMeta=%d",
                  conversation.channel.channelId, conversation.channel.channelType,
                  (long)local.unreadCount, local.lastMessageSeq, local.version,
                  (long)conversation.unreadCount, conversation.lastMessageSeq, conversation.version,
                  (long)newUnread, newLastSeq, newVersion, takeMeta);

            [db executeUpdate:SQL_REPLACE,
             conversation.channel.channelId,
             @(conversation.channel.channelType),
             newParentChannelID,
             @(newParentChannelType),
             newAvatar,
             newClientMsgNo,
             @(newLastSeq),
             @(newTs),
             @(newUnread),
             newExtraStr,
             @(newVersion),
             @(newIsDeleted)];
            reconciledUnread[keyInsert] = @(newUnread);
        }
    }];
    return reconciledUnread;
}

-(void) addConversation:(WKConversation*)conversation {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [self insertConversation:conversation db:db];
    }];
}

-(void) insertConversation:(WKConversation*)conversation db:(FMDatabase*)db{
    NSString *extraStr = [self extraToStr:conversation.extra];
    NSString *parentChannelID  = conversation.parentChannel?conversation.parentChannel.channelId:@"";
    uint8_t parentChannelType = conversation.parentChannel?conversation.parentChannel.channelType:0;
    [db executeUpdate:SQL_INSERT,conversation.channel.channelId,@(conversation.channel.channelType),parentChannelID,@(parentChannelType),conversation.avatar?:@"",conversation.lastClientMsgNo?:@"",@(conversation.lastMessageSeq),@(conversation.lastMsgTimestamp),@(conversation.unreadCount),@(conversation.version),extraStr,@(conversation.isDeleted)];
}

-(void) clearConversationUnreadCount:(WKChannel*)channel {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_CLEAR_UNREADCOUNT,channel.channelId,@(channel.channelType)];
    }];
}

-(void) setConversationUnreadCount:(WKChannel*)channel unread:(NSInteger)unread {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_SET_UNREADCOUNT,@(unread),channel.channelId,@(channel.channelType)];
    }];
}

-(void) deleteConversation:(WKChannel*)channel {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_DELETE_CONVERSATION,channel.channelId?:@"",@(channel.channelType)];
    }];
}

-(void) deleteAllConversation {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_DELETE_ALL_CONVERSATION];
    }];
}


//-(WKConversation*) appendReminder:(WKReminder*) reminder channel:(WKChannel*)channel {
//    __block WKConversation *conversation;
//    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//        conversation = [self getConversationWithChannel:channel db:db];
//        if(conversation) {
//            [conversation.reminderManager appendReminder:reminder];
//            [db executeUpdate:SQL_UPDATE_REMINDERS,[self remindersToStr:conversation.reminderManager.reminders],channel.channelId,@(channel.channelType)];
//        }
//    }];
//    return conversation;
//}
//
//-(WKConversation*) removeReminder:(WKReminderType)type channel:(WKChannel*)channel {
//    __block WKConversation *conversation;
//    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//        conversation = [self getConversationWithChannel:channel db:db];
//        if(conversation) {
//            [conversation.reminderManager removeReminder:type];
//            [db executeUpdate:SQL_UPDATE_REMINDERS,[self remindersToStr:conversation.reminderManager.reminders],channel.channelId,@(channel.channelType)];
//        }
//    }];
//    return conversation;
//}
//
//-(WKConversation*) clearAllReminder:(WKChannel*)channel {
//    __block WKConversation *conversation;
//    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//        conversation = [self getConversationWithChannel:channel db:db];
//        if(conversation) {
//            [db executeUpdate:SQL_UPDATE_REMINDERS,@"",channel.channelId,@(channel.channelType)];
//            conversation.reminderManager.reminders = [NSMutableArray array];
//        }
//    }];
//    return conversation;
//}
//
//- (WKConversation *)clearReminder:(WKChannel *)channel type:(NSInteger)type {
//    __block WKConversation *conversation;
//    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
//        conversation = [self getConversationWithChannel:channel db:db];
//        if(conversation) {
//            [self removeReminderForType:conversation.reminderManager.reminders type:type];
//            [db executeUpdate:SQL_UPDATE_REMINDERS,[self remindersToStr:conversation.reminderManager.reminders],channel.channelId,@(channel.channelType)];
//        }
//    }];
//    return conversation;
//}

-(NSInteger) getAllConversationUnreadCount {
    __block NSInteger unreadCount;
    NSString *scope = [self spaceScopeClauseWithAlias:@"conversation"];
    NSString *sql = scope.length > 0
        ? [NSString stringWithFormat:@"%@ and%@", SQL_GET_ALL_UNREADCOUNT, scope]
        : SQL_GET_ALL_UNREADCOUNT;
    NSString *scopeId = self.spaceScopeId;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = scope.length > 0 ? [db executeQuery:sql, scopeId] : [db executeQuery:sql];
        if(resultSet.next) {
           unreadCount = [resultSet intForColumn:@"unreadCount"];
        }
        [resultSet close];
    }];
    return unreadCount;
}

-(void) updateBrowseTo:(uint32_t)browseTo forChannel:(WKChannel*)channel {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_UPDATE_BROWSETO,@(browseTo),channel.channelId,@(channel.channelType)];
    }];
}

-(void) removeReminderForType:(NSMutableArray*)reminders type:(NSInteger)type {
    if(!reminders || reminders.count<=0) {
        return;
    }
    for (NSInteger i = reminders.count - 1; i >= 0; i--) { // 逆序删除 防止出错
         WKReminder *reminder = reminders[i];
        if (reminder.type == type) {
            [reminders removeObject:reminder];
        }
    }
}

-(void) updateConversation:(WKConversation*)conversation db:(FMDatabase*)db{
    [db executeUpdate:SQL_UPDATE_LASTMSG,conversation.lastClientMsgNo?:@"",@(conversation.lastMessageSeq),@(conversation.lastMsgTimestamp),@(conversation.unreadCount),conversation.channel.channelId,@(conversation.channel.channelType)];
}

-(void) updateConversation:(WKConversation*)conversation{
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [self updateConversation:conversation db:db];
    }];
}

-(void) updateConversation:(WKChannel*)channel title:(NSString*)title avatar:(NSString*) avatar db:(FMDatabase*)db {
    [db executeUpdate:SQL_UPDATE_TITLEANDAVATAR,title?:@"",avatar?:@"",channel.channelId?:@"",@(channel.channelType)];
}


-(NSArray<WKConversation*>*) getConversationList {
    __block NSMutableArray<WKConversation*> *items = [NSMutableArray new];
    NSString *scope = [self spaceScopeClauseWithAlias:@"conversation"];
    NSString *sql = scope.length > 0
        ? [NSString stringWithFormat:@"select %@ from conversation left join channel on conversation.channel_id=channel.channel_id and conversation.channel_type=channel.channel_type left join conversation_extra on conversation.channel_id=conversation_extra.channel_id and conversation.channel_type=conversation_extra.channel_type where conversation.is_deleted=0 and%@ order by conversation.last_msg_timestamp desc,conversation.id desc", SQL_GET_SELECT, scope]
        : SQL_ALL;
    NSString *scopeId = self.spaceScopeId;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = scope.length > 0 ? [db executeQuery:sql, scopeId] : [db executeQuery:sql];
        while (result.next) {
           [items addObject:[self toConversation:result.resultDictionary]];
        }
        [result close];
    }];
    return items;
}

-(WKConversation*) getConversation:(WKChannel*)channel{
     __block WKConversation *conversation;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =[db executeQuery:SQL_GET,channel.channelId,@(channel.channelType)];
        if (result.next) {
            conversation =  [self toConversation:result.resultDictionary];
        }
        [result close];
    }];
    return conversation;
}

-(NSArray<WKConversation*>*) getConversations:(NSArray<WKChannel*> *)channels {
    if(!channels||channels.count == 0) {
        return nil;
    }
    NSMutableArray *channelIDs = [NSMutableArray array];
    for (WKChannel *channel in channels) {
        [channelIDs addObject:channel.channelId];
    }
    NSString *inquery = @"";
    for (NSInteger i=0; i<channelIDs.count; i++) {
        NSString *channelID = channelIDs[i];
        if(i == channels.count-1) {
            inquery = [NSString stringWithFormat:@"%@'%@'",inquery,channelID];
        }else {
            inquery = [NSString stringWithFormat:@"%@'%@',",inquery,channelID];
        }
        
    }
    __block NSMutableArray<WKConversation*> *conversations = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =  [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_GET_WITH_CHANNELS,inquery]];
        while (resultSet.next) {
            WKConversation *conversation = [self toConversation:resultSet.resultDictionary];
            BOOL exist = false;
            for (WKChannel *channel in channels) {
                if([channel isEqual:conversation.channel]) {
                    exist = true;
                    break;
                }
            }
            if(exist) {
                [conversations addObject:conversation];
            }
        }
        [resultSet close];
    }];
    
    return conversations;
    
}


-(WKConversation*) recoveryConversation:(WKChannel*)channel {
     __block WKConversation *conversation;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_GET_IN_ALL,channel.channelId,@(channel.channelType)];
        if (result.next) {
            conversation =  [self toConversation:result.resultDictionary];
        }
        [result close];
        if(conversation) {
            conversation.isDeleted = 0;
            [db executeUpdate:SQL_RECOVERY_CONVERSATION,channel.channelId,@(channel.channelType)];
        }
    }];
    return conversation;
}

-(WKConversation*) getConversationWithLastClientMsgNo:(NSString*)lastClientMsgNo {
     __block WKConversation *conversation;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =  [db executeQuery:SQL_GET_WITH_LASTCLIENTMSGNO,lastClientMsgNo?:@""];
        if (result.next) {
            conversation =  [self toConversation:result.resultDictionary];
        }
        [result close];
    }];
    return conversation;
}

-(WKConversation*) getConversationWithChannel:(WKChannel*)channel db:(FMDatabase*)db{
    FMResultSet *result =[db executeQuery:SQL_GET,channel.channelId,@(channel.channelType)];
    WKConversation *conversation;
    if (result.next) {
        conversation =  [self toConversation:result.resultDictionary];
    }
    [result close];
    return conversation;
}

-(WKConversation*) getConversationWithChannelInAll:(WKChannel*)channel db:(FMDatabase*)db{
    FMResultSet *result =[db executeQuery:SQL_GET_IN_ALL,channel.channelId,@(channel.channelType)];
    WKConversation *conversation;
    if (result.next) {
        conversation =  [self toConversation:result.resultDictionary];
    }
    [result close];
    return conversation;
}

-(NSString*) extraToStr:(NSDictionary*)extra {
    NSString *extraStr = @"";
    if(extra) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:kNilOptions error:nil];
        extraStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return extraStr;
}


-(BOOL) existConversation:(WKChannel*)channel db:(FMDatabase*)db{
    FMResultSet *result = [db executeQuery:SQL_EXIST,channel.channelId,@(channel.channelType)];
    __block BOOL isExit=false;
    if(result.next){
        NSDictionary *resultDic = result.resultDictionary;
        isExit = [resultDic[@"cn"] integerValue]>0?YES:NO;
    }
    [result close];
    return isExit;
}

-(long long) getConversationMaxVersion {
    __block long long version =0;
    // 作用域生效时取的是"本空间"的最大版本号 —— 首次进入某空间时归属集为空 → 0
    // → 上层自动发起 version=0 的全量 sync，不需要额外的"切空间强制全量"逻辑。
    NSString *scope = [self spaceScopeClauseWithAlias:@"conversation"];
    NSString *sql = scope.length > 0
        ? [NSString stringWithFormat:@"%@ and%@", SQL_MAX_VERSION, scope]
        : SQL_MAX_VERSION;
    NSString *scopeId = self.spaceScopeId;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = scope.length > 0 ? [db executeQuery:sql, scopeId] : [db executeQuery:sql];
        if(result.next){
            NSDictionary *resultDic = result.resultDictionary;
            version = [resultDic[@"version"] longLongValue];
        }
        [result close];
    }];
    return version;
}

-(NSString*) getConversationSyncKey {
    __block NSString *syncKey = @"";
    // syncKey 会作为 last_msg_seqs 发给 conversation/sync?space_id=X。不作用域化就会把
    // 别的空间的 channel 报给本空间的 sync，服务端可能据此回灌跨空间会话。
    NSString *scope = [self spaceScopeClauseWithAlias:@"conversation"];
    NSString *sql = scope.length > 0
        ? [NSString stringWithFormat:@"select GROUP_CONCAT(channel_id||':'||channel_type||':'||last_msg_seq,'|') synckey from (select *,(select max(message_seq) from message where message.channel_id=conversation.channel_id and message.channel_type= conversation.channel_type and message.content_type<>0 and message.content_type<>? limit 1) last_msg_seq from conversation where%@) cn where channel_id<>''", scope]
        : SQL_SYNC_KEY;
    NSString *scopeId = self.spaceScopeId;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = scope.length > 0
            ? [db executeQuery:sql,@(WK_CMD),scopeId]
            : [db executeQuery:sql,@(WK_CMD)];
        if(result.next){
            NSDictionary *resultDic = result.resultDictionary;
            if(resultDic[@"synckey"] && ![resultDic[@"synckey"] isKindOfClass:[NSNull class]]) {
                syncKey = resultDic[@"synckey"];
            }

        }
        [result close];
    }];
    return syncKey;
}

-(WKConversation*) toConversation:(NSDictionary*)dict {
    WKConversation *conversation = [WKConversation new];
    conversation.channel = [[WKChannel alloc] initWith:dict[@"channel_id"] channelType:[dict[@"channel_type"] integerValue]];
    if(dict[@"parent_channel_id"] && ![dict[@"parent_channel_id"] isEqualToString:@""]) {
        conversation.parentChannel = [WKChannel channelID:dict[@"parent_channel_id"] channelType:[dict[@"parent_channel_type"] integerValue]];
    }
    conversation.avatar = dict[@"avatar"];
    conversation.lastClientMsgNo = dict[@"last_client_msg_no"];
    conversation.lastMessageSeq = [dict[@"last_message_seq"] unsignedIntValue];
    conversation.lastMsgTimestamp = [dict[@"last_msg_timestamp"] integerValue];
    conversation.unreadCount = [dict[@"unread_count"] integerValue];
    conversation.version = [dict[@"version"] longLongValue];
    conversation.mute = [dict[@"mute"] boolValue];
    conversation.stick = [dict[@"stick"] boolValue];
    NSString *extraStr = dict[@"extra"];
    __autoreleasing NSError *error = nil;
    NSDictionary *extraDictionary = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    if(!error) {
        conversation.extra = extraDictionary;
    }
    conversation.remoteExtra.channel = conversation.channel;
    if(dict[@"keep_message_seq"]) {
        conversation.remoteExtra.keepMessageSeq = [dict[@"keep_message_seq"] unsignedIntValue];
    }
    if(dict[@"keep_offset_y"]) {
        conversation.remoteExtra.keepOffsetY = [dict[@"keep_offset_y"] integerValue];
    }
    if(dict[@"draft"]) {
        conversation.remoteExtra.draft = dict[@"draft"];
    }
    if(dict[@"extra_version"]) {
        conversation.remoteExtra.version = [dict[@"extra_version"] longLongValue];
    }
    
    return conversation;
}

@end

@implementation WKConversationAddOrUpdateResult

+(instancetype) initWithInsert:(BOOL)insert modify:(BOOL)modify conversation:(WKConversation*)conversation {
    WKConversationAddOrUpdateResult *result = [WKConversationAddOrUpdateResult new];
    result.insert = insert;
    result.conversation = conversation;
    result.modify = modify;
    return result;
}

@end
