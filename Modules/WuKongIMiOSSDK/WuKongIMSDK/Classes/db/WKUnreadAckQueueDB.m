//
//  WKUnreadAckQueueDB.m
//  WuKongIMSDK
//

#import "WKUnreadAckQueueDB.h"
#import "WKDB.h"

@implementation WKUnreadAckEntry
@end

// 退避: 1s, 5s, 30s, 2m, 10m, 1h cap (索引 0..5).
static NSTimeInterval const kRetryBackoff[] = {1, 5, 30, 120, 600, 3600};
static NSInteger const kBackoffCount = 6;

static NSTimeInterval BackoffForAttempt(NSInteger attempts) {
    NSInteger idx = attempts < 0 ? 0 : (attempts >= kBackoffCount ? kBackoffCount - 1 : attempts);
    return kRetryBackoff[idx];
}

@implementation WKUnreadAckQueueDB

static WKUnreadAckQueueDB *_instance;
+ (instancetype) shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) enqueue:(WKChannel*)channel lastReadSeq:(uint32_t)seq {
    if (!channel || channel.channelId.length == 0) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select last_read_seq from unread_ack_queue where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        BOOL exists = NO;
        uint32_t existingSeq = 0;
        if (rs.next) {
            exists = YES;
            existingSeq = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
        }
        [rs close];
        uint32_t newSeq = MAX(seq, existingSeq);
        if (exists) {
            // 覆盖 lastReadSeq, 重置 attempts / 立即可重试. 用户又触发了 mark-read,
            // 之前累积的 backoff 不该让新事件等下去.
            [db executeUpdate:@"update unread_ack_queue set last_read_seq=?, attempts=0, next_retry_at=0, last_attempt_at=0 where channel_id=? and channel_type=?",
             @(newSeq), channel.channelId, @(channel.channelType)];
        } else {
            [db executeUpdate:@"insert into unread_ack_queue(channel_id, channel_type, last_read_seq, attempts, next_retry_at, last_attempt_at, created_at) values(?,?,?,?,?,?,?)",
             channel.channelId, @(channel.channelType), @(newSeq),
             @(0), @(0), @(0), @(now)];
        }
    }];
    NSLog(@"[UnreadAck] enqueue channelId=%@ type=%d seq=%u", channel.channelId, channel.channelType, seq);
}

-(NSArray<WKUnreadAckEntry*>*) dueEntries {
    NSMutableArray *result = [NSMutableArray array];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select * from unread_ack_queue where next_retry_at<=? order by created_at asc",
                            @(now)];
        while (rs.next) {
            [result addObject:[self toEntry:rs]];
        }
        [rs close];
    }];
    return result;
}

-(BOOL) hasPending:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return NO;
    __block BOOL has = NO;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select 1 from unread_ack_queue where channel_id=? and channel_type=? limit 1",
                            channel.channelId, @(channel.channelType)];
        if (rs.next) has = YES;
        [rs close];
    }];
    return has;
}

-(WKUnreadAckEntry*) entryForChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return nil;
    __block WKUnreadAckEntry *entry = nil;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select * from unread_ack_queue where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        if (rs.next) entry = [self toEntry:rs];
        [rs close];
    }];
    return entry;
}

-(void) markDone:(WKChannel*)channel ackedSeq:(uint32_t)ackedSeq {
    if (!channel || channel.channelId.length == 0) return;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select last_read_seq from unread_ack_queue where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        BOOL exists = NO;
        uint32_t storedSeq = 0;
        if (rs.next) {
            exists = YES;
            storedSeq = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
        }
        [rs close];
        if (!exists) {
            return;
        }
        if (storedSeq <= ackedSeq) {
            // ack 覆盖了 stored 的进度, 安全删掉.
            [db executeUpdate:@"delete from unread_ack_queue where channel_id=? and channel_type=?",
             channel.channelId, @(channel.channelType)];
            NSLog(@"[UnreadAck] markDone channelId=%@ type=%d ackedSeq=%u (stored=%u, deleted)",
                  channel.channelId, channel.channelType, ackedSeq, storedSeq);
        } else {
            // upload 在飞时用户又往后读了一段, stored 的 seq 比 acked 大.
            // 不能删: 删了 server 还停留在 ackedSeq, 后面的进度就丢了.
            // 把 attempts/next_retry_at 归零, 让下一轮 drain 立即把新 seq 顶上去.
            [db executeUpdate:@"update unread_ack_queue set attempts=0, next_retry_at=0, last_attempt_at=0 where channel_id=? and channel_type=?",
             channel.channelId, @(channel.channelType)];
            NSLog(@"[UnreadAck] markDone SUPERSEDED channelId=%@ type=%d ackedSeq=%u storedSeq=%u (keep row, retry immediately)",
                  channel.channelId, channel.channelType, ackedSeq, storedSeq);
        }
    }];
}

-(void) markFailed:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select attempts from unread_ack_queue where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        if (!rs.next) { [rs close]; return; }
        NSInteger attempts = [rs intForColumn:@"attempts"] + 1;
        [rs close];
        NSTimeInterval next = now + BackoffForAttempt(attempts);
        [db executeUpdate:@"update unread_ack_queue set attempts=?, next_retry_at=?, last_attempt_at=? where channel_id=? and channel_type=?",
         @(attempts), @(next), @(now), channel.channelId, @(channel.channelType)];
        NSLog(@"[UnreadAck] markFailed channelId=%@ type=%d attempts=%ld nextIn=%.0fs",
              channel.channelId, channel.channelType, (long)attempts, next - now);
    }];
}

-(NSArray<WKUnreadAckEntry*>*) allEntries {
    NSMutableArray *result = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select * from unread_ack_queue order by created_at asc"];
        while (rs.next) {
            [result addObject:[self toEntry:rs]];
        }
        [rs close];
    }];
    return result;
}

-(NSSet<NSString*>*) allPendingChannelKeys {
    NSMutableSet<NSString*> *result = [NSMutableSet set];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select channel_id, channel_type from unread_ack_queue"];
        while (rs.next) {
            NSString *cid = [rs stringForColumn:@"channel_id"];
            NSInteger ctype = [rs intForColumn:@"channel_type"];
            if (cid.length > 0) {
                [result addObject:[NSString stringWithFormat:@"%ld:%@", (long)ctype, cid]];
            }
        }
        [rs close];
    }];
    return result;
}

-(NSTimeInterval) earliestFutureRetryAt {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval result = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select min(next_retry_at) m from unread_ack_queue where next_retry_at>?",
                            @(now)];
        if (rs.next) {
            id v = [rs objectForColumn:@"m"];
            if (v && ![v isKindOfClass:[NSNull class]]) {
                result = [v doubleValue];
            }
        }
        [rs close];
    }];
    return result;
}

-(WKUnreadAckEntry*) toEntry:(FMResultSet*)rs {
    WKUnreadAckEntry *e = [[WKUnreadAckEntry alloc] init];
    NSString *cid = [rs stringForColumn:@"channel_id"];
    NSInteger ctype = [rs intForColumn:@"channel_type"];
    e.channel = [[WKChannel alloc] initWith:cid channelType:ctype];
    e.lastReadSeq = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
    e.attempts = [rs intForColumn:@"attempts"];
    e.nextRetryAt = [rs longLongIntForColumn:@"next_retry_at"];
    e.createdAt = [rs longLongIntForColumn:@"created_at"];
    return e;
}

@end
