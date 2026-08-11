//
//  WKConversationSpaceDB.m
//  WuKongIMSDK
//

#import "WKConversationSpaceDB.h"
#import "WKDB.h"

@interface WKConversationSpaceDB ()
/// hasAnyMembership 的内存缓存。-1 = 未知(需查表), 0 = 空表, 1 = 有记录。
/// 只在本类的写路径 / WKDB 切库时失效, 避免每次 getConversationList 都多一次 count 查询。
@property (nonatomic, assign) int hasAnyCache;
@property (nonatomic, strong) NSRecursiveLock *lock;
@end

@implementation WKConversationSpaceDB

static WKConversationSpaceDB *_instance;
+ (instancetype) shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(instancetype) init {
    self = [super init];
    if(self) {
        _hasAnyCache = -1;
        _lock = [[NSRecursiveLock alloc] init];
        // 切账号会换 DB 文件, 缓存必须跟着失效。
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onDBChanged)
                                                     name:WKDBDidSwitchNotification
                                                   object:nil];
    }
    return self;
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) onDBChanged {
    [self invalidateHasAnyCache];
}

-(void) invalidateHasAnyCache {
    [self.lock lock];
    self.hasAnyCache = -1;
    [self.lock unlock];
}

#pragma mark - 写

-(void) replaceMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId {
    if(spaceId.length == 0) return;
    long long now = (long long)[[NSDate date] timeIntervalSince1970];
    __block BOOL failed = NO;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 这是唯一"先删后插"的破坏性写入, 所以必须检查每一步并在失败时回滚:
        // 删已经跑完、插到一半失败(SQLITE_FULL / IO error)而事务照常提交的话, 会留下一份
        // **被截断**的归属集合 —— 作用域读会把缺失的那些会话直接藏起来, 而增量 sync
        // 不会重发它们, 要等下一次冷启动的强制全量才回来。宁可整批不生效(保留旧归属,
        // 下次 sync 再来一遍), 也不能提交半截。
        if(![db executeUpdate:@"delete from conversation_space where space_id=?", spaceId]) {
            NSLog(@"[SpaceIndex] replaceMembership delete 失败, 回滚: %@", db.lastErrorMessage);
            *rollback = YES; failed = YES; return;
        }
        for (WKChannel *channel in channels) {
            if(channel.channelId.length == 0) continue;
            if(![db executeUpdate:@"insert or replace into conversation_space(space_id,channel_id,channel_type,synced_at) values(?,?,?,?)",
                 spaceId, channel.channelId, @(channel.channelType), @(now)]) {
                NSLog(@"[SpaceIndex] replaceMembership insert 失败, 回滚: %@", db.lastErrorMessage);
                *rollback = YES; failed = YES; return;
            }
        }
    }];
    [self invalidateHasAnyCache];
    NSLog(@"[SpaceIndex] replaceMembership space=%@ count=%lu%@", spaceId, (unsigned long)channels.count,
          failed ? @" (失败已回滚)" : @"");
}

-(void) addMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId {
    if(spaceId.length == 0 || channels.count == 0) return;
    long long now = (long long)[[NSDate date] timeIntervalSince1970];
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKChannel *channel in channels) {
            if(channel.channelId.length == 0) continue;
            [db executeUpdate:@"insert or replace into conversation_space(space_id,channel_id,channel_type,synced_at) values(?,?,?,?)",
             spaceId, channel.channelId, @(channel.channelType), @(now)];
        }
    }];
    [self invalidateHasAnyCache];
}

-(void) removeMembership:(NSArray<WKChannel*>*)channels forSpace:(NSString*)spaceId {
    if(spaceId.length == 0 || channels.count == 0) return;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKChannel *channel in channels) {
            if(channel.channelId.length == 0) continue;
            [db executeUpdate:@"delete from conversation_space where space_id=? and channel_id=? and channel_type=?",
             spaceId, channel.channelId, @(channel.channelType)];
        }
    }];
    [self invalidateHasAnyCache];
    NSLog(@"[SpaceIndex] removeMembership space=%@ count=%lu", spaceId, (unsigned long)channels.count);
}

-(NSInteger) backfillMembershipFromExistingConversationsForSpace:(NSString*)spaceId {
    if(spaceId.length == 0) return 0;
    __block NSInteger inserted = 0;
    long long now = (long long)[[NSDate date] timeIntervalSince1970];
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // insert or ignore：已有归属的不动（可能是别的空间的外部群，不能被本次回填抢走）
        BOOL ok = [db executeUpdate:@"insert or ignore into conversation_space(space_id,channel_id,channel_type,synced_at) select ?,channel_id,channel_type,? from conversation",
                   spaceId, @(now)];
        if(ok) {
            inserted = [db changes];
        }
    }];
    if(inserted > 0) {
        [self invalidateHasAnyCache];
    }
    NSLog(@"[SpaceIndex] backfill legacy membership space=%@ rows=%ld", spaceId, (long)inserted);
    return inserted;
}

#pragma mark - 读

-(BOOL) deleteAllMembership {
    __block BOOL ok = NO;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        ok = [db executeUpdate:@"delete from conversation_space"];
        if(!ok) {
            NSLog(@"[SpaceIndex] deleteAllMembership 失败: %@", db.lastErrorMessage);
        }
    }];
    if(ok) {
        [self invalidateHasAnyCache];
    }
    NSLog(@"[SpaceIndex] deleteAllMembership (归属索引重建) ok=%d", ok);
    return ok;
}

-(NSSet<NSString*>*) channelIdsForSpace:(NSString*)spaceId channelType:(uint8_t)channelType {
    NSMutableSet<NSString*> *result = [NSMutableSet set];
    if(spaceId.length == 0) return result;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select channel_id from conversation_space where space_id=? and channel_type=?",
                            spaceId, @(channelType)];
        while (rs.next) {
            NSString *cid = [rs stringForColumn:@"channel_id"];
            if(cid.length > 0) [result addObject:cid];
        }
        [rs close];
    }];
    return result;
}

-(NSSet<NSString*>*) channelKeysForSpace:(NSString*)spaceId {
    NSMutableSet<NSString*> *result = [NSMutableSet set];
    if(spaceId.length == 0) return result;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select channel_id,channel_type from conversation_space where space_id=?", spaceId];
        while (rs.next) {
            NSString *cid = [rs stringForColumn:@"channel_id"];
            if(cid.length == 0) continue;
            [result addObject:[NSString stringWithFormat:@"%d:%@", [rs intForColumn:@"channel_type"], cid]];
        }
        [rs close];
    }];
    return result;
}

-(BOOL) hasAnyMembership {
    [self.lock lock];
    int cached = self.hasAnyCache;
    [self.lock unlock];
    if(cached >= 0) return cached == 1;

    __block BOOL has = NO;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select 1 from conversation_space limit 1"];
        if(rs.next) has = YES;
        [rs close];
    }];
    [self.lock lock];
    self.hasAnyCache = has ? 1 : 0;
    [self.lock unlock];
    return has;
}

-(BOOL) hasMembershipForSpace:(NSString*)spaceId {
    if(spaceId.length == 0) return NO;
    __block BOOL has = NO;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select 1 from conversation_space where space_id=? limit 1", spaceId];
        if(rs.next) has = YES;
        [rs close];
    }];
    return has;
}

-(BOOL) isChannel:(WKChannel*)channel inSpace:(NSString*)spaceId {
    if(spaceId.length == 0 || channel.channelId.length == 0) return NO;
    __block BOOL result = NO;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select 1 from conversation_space where space_id=? and channel_id=? and channel_type=? limit 1",
                            spaceId, channel.channelId, @(channel.channelType)];
        if(rs.next) result = YES;
        [rs close];
    }];
    return result;
}

#pragma mark - GC

-(NSInteger) gcOrphanConversationsBefore:(NSInteger)beforeTimestamp {
    __block NSInteger deleted = 0;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 1. 孤儿归属记录: 对应的会话行已经不在了
        [db executeUpdate:@"delete from conversation_space where not exists(select 1 from conversation c where c.channel_id=conversation_space.channel_id and c.channel_type=conversation_space.channel_type)"];
        // 2. 不属于任何空间、且早于 beforeTimestamp 的会话行
        FMResultSet *rs = [db executeQuery:@"select count(*) cn from conversation where last_msg_timestamp < ? and not exists(select 1 from conversation_space cs where cs.channel_id=conversation.channel_id and cs.channel_type=conversation.channel_type)",
                            @(beforeTimestamp)];
        if(rs.next) deleted = [rs longForColumn:@"cn"];
        [rs close];
        if(deleted > 0) {
            [db executeUpdate:@"delete from conversation where last_msg_timestamp < ? and not exists(select 1 from conversation_space cs where cs.channel_id=conversation.channel_id and cs.channel_type=conversation.channel_type)",
             @(beforeTimestamp)];
        }
    }];
    if(deleted > 0) {
        NSLog(@"[SpaceIndex] gcOrphanConversations deleted=%ld", (long)deleted);
    }
    return deleted;
}

-(NSInteger) gcDanglingMembership {
    __block NSInteger removed = 0;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 只删"指不到任何活着的会话行"的归属：会话行已经不存在, 或已 is_deleted=1。
        // 这类归属对读路径毫无作用（getConversationList 本身就带 is_deleted=0），
        // 删掉不会让任何肉眼可见的会话消失 —— 这是本方法与旧
        // gcTrimMembershipPerSpaceKeep: 的关键区别, 后者会裁掉**还活着**的会话的归属,
        // 导致超过上限的空间在启动 20s 后列表凭空少一截(详见 WKConvListCache
        // runGarbageCollectionIfNeeded 的注释)。
        BOOL ok = [db executeUpdate:@"delete from conversation_space where not exists (select 1 from conversation c where c.channel_id=conversation_space.channel_id and c.channel_type=conversation_space.channel_type and c.is_deleted=0)"];
        if(!ok) {
            NSLog(@"[SpaceIndex] gcDanglingMembership 失败, 回滚: %@", db.lastErrorMessage);
            *rollback = YES;
            return;
        }
        removed = [db changes];
    }];
    if(removed > 0) {
        [self invalidateHasAnyCache];
        NSLog(@"[SpaceIndex] gcDanglingMembership removed=%ld", (long)removed);
    }
    return removed;
}

@end
