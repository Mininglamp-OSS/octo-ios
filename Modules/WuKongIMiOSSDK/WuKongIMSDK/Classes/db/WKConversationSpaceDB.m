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
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        [db executeUpdate:@"delete from conversation_space where space_id=?", spaceId];
        for (WKChannel *channel in channels) {
            if(channel.channelId.length == 0) continue;
            [db executeUpdate:@"insert or replace into conversation_space(space_id,channel_id,channel_type,synced_at) values(?,?,?,?)",
             spaceId, channel.channelId, @(channel.channelType), @(now)];
        }
    }];
    [self invalidateHasAnyCache];
    NSLog(@"[SpaceIndex] replaceMembership space=%@ count=%lu", spaceId, (unsigned long)channels.count);
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

-(void) deleteAllMembership {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:@"delete from conversation_space"];
    }];
    [self invalidateHasAnyCache];
    NSLog(@"[SpaceIndex] deleteAllMembership (归属索引重建)");
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

-(NSInteger) gcTrimMembershipPerSpaceKeep:(NSInteger)keepCount {
    if(keepCount <= 0) return 0;
    __block NSInteger removed = 0;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        NSMutableArray<NSString*> *spaceIds = [NSMutableArray array];
        FMResultSet *spaceRs = [db executeQuery:@"select distinct space_id from conversation_space"];
        while (spaceRs.next) {
            NSString *sid = [spaceRs stringForColumn:@"space_id"];
            if(sid.length > 0) [spaceIds addObject:sid];
        }
        [spaceRs close];

        for (NSString *sid in spaceIds) {
            // 按会话的 last_msg_timestamp 倒序, 越过 keepCount 的归属删掉。
            // 没有对应会话行的(timestamp 视为 0)排最后, 优先被裁。
            FMResultSet *rs = [db executeQuery:@"select cs.channel_id,cs.channel_type from conversation_space cs left join conversation c on c.channel_id=cs.channel_id and c.channel_type=cs.channel_type where cs.space_id=? order by IFNULL(c.last_msg_timestamp,0) desc limit -1 offset ?",
                                sid, @(keepCount)];
            NSMutableArray<NSArray*> *victims = [NSMutableArray array];
            while (rs.next) {
                NSString *cid = [rs stringForColumn:@"channel_id"];
                if(cid.length == 0) continue;
                [victims addObject:@[cid, @([rs intForColumn:@"channel_type"])]];
            }
            [rs close];
            for (NSArray *v in victims) {
                [db executeUpdate:@"delete from conversation_space where space_id=? and channel_id=? and channel_type=?",
                 sid, v[0], v[1]];
                removed++;
            }
        }
    }];
    if(removed > 0) {
        [self invalidateHasAnyCache];
        NSLog(@"[SpaceIndex] gcTrimMembership removed=%ld keep=%ld", (long)removed, (long)keepCount);
    }
    return removed;
}

@end
