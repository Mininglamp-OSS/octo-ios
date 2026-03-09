//
//  WKReactionDB.m
//  WuKongIMSDK
//
//  Created by tt on 2021/9/13.
//

#import "WKReactionDB.h"
#import "WKDB.h"
#define tableName @"reactions"

#define SQL_REACTIONS_WITH_MESSAGEIDS(param) [NSString stringWithFormat:@"select * from %@ where is_deleted=0 and message_id in %@ order by version desc",tableName,param]
#define SQL_REACTIONS_WITH_MESSAGEID [NSString stringWithFormat:@"select * from %@ where message_id = ? and is_deleted=0 order by version desc",tableName]

#define SQL_INSERT_REACTIONS [NSString stringWithFormat:@"insert into %@(message_id,channel_id,channel_type,uid,emoji,version,created_at,is_deleted) values(?,?,?,?,?,?,?,?) ON CONFLICT(message_id,uid) DO UPDATE SET version=excluded.version,emoji=excluded.emoji,created_at=excluded.created_at,is_deleted=excluded.is_deleted",tableName]

#define SQL_MAX_VERSION [NSString stringWithFormat:@"select IFNULL(max(version),0) max_version from %@ where channel_id=? and channel_type=?",tableName]

@implementation WKReactionDB

static WKReactionDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKReactionDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}


-(NSArray<WKReaction*>*) getReactions:(NSArray<NSNumber*>*) messageIDs {
    if(!messageIDs || messageIDs.count ==0) {
        return nil;
    }
    NSMutableArray *newMessageIDs = [NSMutableArray array];
    for (NSNumber *messageID in messageIDs) {
        if(messageID.intValue != 0) {
            [newMessageIDs addObject:messageID];
        }
    }
    if(newMessageIDs.count == 0) {
        return nil;
    }
    NSMutableArray *reactions = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet;
        if(messageIDs.count == 1) {
            resultSet = [db executeQuery:SQL_REACTIONS_WITH_MESSAGEID,newMessageIDs[0]];
        }else{
            NSString *ids = [newMessageIDs componentsJoinedByString:@","];
            NSString *inParam = [NSString stringWithFormat:@"(%@)",ids];
            resultSet = [db executeQuery:SQL_REACTIONS_WITH_MESSAGEIDS(inParam)];
        }
        while ([resultSet next]) {
            [reactions addObject:[self toReaction:resultSet]];
        }
        
        [resultSet close];
       
    }];
    return reactions;
}

-(  NSDictionary<NSString*,NSArray<WKReaction*>*> *) getReactionDictionary:(NSArray<NSNumber*>*) messageIDs {
    NSArray<WKReaction*> *reactions =  [[WKReactionDB shared] getReactions:messageIDs];
    NSMutableDictionary<NSString*,NSMutableArray<WKReaction*>*> *reactionDict = [NSMutableDictionary dictionary];
    if(reactions && reactions.count>0) {
        for (WKReaction *reaction in reactions) {
            NSString *key = [NSString stringWithFormat:@"%llu", reaction.messageId];
            NSMutableArray *messageReactions  = reactionDict[key];
            if(!messageReactions) {
                messageReactions = [NSMutableArray array];
                reactionDict[key] = messageReactions;
            }
            [messageReactions addObject:reaction];
        }
    }
    return reactionDict;
}

-(BOOL) insertOrUpdateReactions:(NSArray<WKReaction*>*)reactions {
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKReaction *reaction in reactions) {
            [db executeUpdate:SQL_INSERT_REACTIONS,@(reaction.messageId),reaction.channel.channelId,@(reaction.channel.channelType),reaction.uid,reaction.emoji,@(reaction.version),reaction.createdAt,@(reaction.isDeleted)];
        }
        
    }];
    return true;
}

-(BOOL) insertOrUpdateReactions:(NSArray<WKReaction*>*)reactions db:(FMDatabase*)db {
    for (WKReaction *reaction in reactions) {
        [db executeUpdate:SQL_INSERT_REACTIONS,@(reaction.messageId),reaction.channel.channelId,@(reaction.channel.channelType),reaction.uid,reaction.emoji,@(reaction.version),reaction.createdAt,@(reaction.isDeleted)];
    }
    return true;
}

-(uint64_t) maxVersion:(WKChannel*) channel {
    __block uint64_t version = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MAX_VERSION,channel.channelId,@(channel.channelType)];
        if([resultSet next]) {
            version = [resultSet unsignedLongLongIntForColumn:@"max_version"];
        }
        [resultSet close];
    }];
    return version;
}

-(WKReaction*) toReaction:(FMResultSet*)resultSet {
    WKReaction *reaction = [WKReaction new];
    reaction.uid = [resultSet stringForColumn:@"uid"]?:@"";
    reaction.messageId = [resultSet unsignedLongLongIntForColumn:@"message_id"];
    reaction.emoji = [resultSet stringForColumn:@"emoji"];
    reaction.createdAt = [resultSet stringForColumn:@"created_at"];
    reaction.isDeleted = [resultSet intForColumn:@"is_deleted"];
    NSString *channelID = [resultSet stringForColumn:@"channel_id"] ?:@"";
    NSInteger channelType = [resultSet intForColumn:@"channel_type"];
    
    reaction.channel = [WKChannel channelID:channelID channelType:channelType];
    
    reaction.version = [resultSet unsignedLongLongIntForColumn:@"version"];
    return reaction;
}

@end
