//
//  WKUnreadStateDB.m
//  WuKongIMSDK
//

#import "WKUnreadStateDB.h"
#import "WKDB.h"

@implementation WKUnreadStateRecord
@end

@implementation WKUnreadStateDB

static WKUnreadStateDB *_instance;
+ (instancetype) shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(uint32_t) lastReadSeqForChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return 0;
    __block uint32_t result = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select last_read_seq from unread_state where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        if (rs.next) {
            result = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
        }
        [rs close];
    }];
    return result;
}

-(NSTimeInterval) lastLocalReadAtForChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return 0;
    __block NSTimeInterval result = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select last_local_read_at from unread_state where channel_id=? and channel_type=?",
                            channel.channelId, @(channel.channelType)];
        if (rs.next) {
            result = [rs longLongIntForColumn:@"last_local_read_at"];
        }
        [rs close];
    }];
    return result;
}

-(void) setLastReadSeq:(uint32_t)seq lastLocalReadAt:(NSTimeInterval)at forChannel:(WKChannel*)channel {
    if (!channel || channel.channelId.length == 0) return;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [self setLastReadSeq:seq lastLocalReadAt:at forChannel:channel db:db];
    }];
}

-(void) setLastReadSeq:(uint32_t)seq lastLocalReadAt:(NSTimeInterval)at forChannel:(WKChannel*)channel db:(FMDatabase*)db {
    if (!channel || channel.channelId.length == 0) return;
    FMResultSet *rs = [db executeQuery:@"select last_read_seq from unread_state where channel_id=? and channel_type=?",
                        channel.channelId, @(channel.channelType)];
    BOOL exists = NO;
    uint32_t existingSeq = 0;
    if (rs.next) {
        exists = YES;
        existingSeq = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
    }
    [rs close];
    // last_read_seq 单调递增, 防 race 把已读 200 的 channel 覆盖回 100;
    // last_local_read_at 直接覆盖(它是用来判 60s 保护窗口的, 最新一次 mark-read 时间就是当前需求).
    uint32_t newSeq = MAX(seq, existingSeq);
    if (exists) {
        [db executeUpdate:@"update unread_state set last_read_seq=?, last_local_read_at=? where channel_id=? and channel_type=?",
         @(newSeq), @((long long)at), channel.channelId, @(channel.channelType)];
    } else {
        [db executeUpdate:@"insert into unread_state(channel_id, channel_type, last_read_seq, last_local_read_at) values(?,?,?,?)",
         channel.channelId, @(channel.channelType), @(newSeq), @((long long)at)];
    }
}

-(NSDictionary<NSString*, WKUnreadStateRecord*>*) allStateMap {
    NSMutableDictionary<NSString*, WKUnreadStateRecord*> *result = [NSMutableDictionary dictionary];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *rs = [db executeQuery:@"select * from unread_state"];
        while (rs.next) {
            NSString *cid = [rs stringForColumn:@"channel_id"];
            NSInteger ctype = [rs intForColumn:@"channel_type"];
            if (cid.length == 0) continue;
            WKUnreadStateRecord *rec = [[WKUnreadStateRecord alloc] init];
            rec.channel = [[WKChannel alloc] initWith:cid channelType:ctype];
            rec.lastReadSeq = (uint32_t)[rs unsignedLongLongIntForColumn:@"last_read_seq"];
            rec.lastLocalReadAt = [rs longLongIntForColumn:@"last_local_read_at"];
            NSString *key = [NSString stringWithFormat:@"%ld:%@", (long)ctype, cid];
            result[key] = rec;
        }
        [rs close];
    }];
    return result;
}

@end
