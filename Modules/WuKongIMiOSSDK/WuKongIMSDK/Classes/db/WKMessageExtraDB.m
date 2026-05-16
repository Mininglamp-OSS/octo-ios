//
//  WKMessageExtraDB.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/12.
//

#import "WKMessageExtraDB.h"
#import "WKMessageDB.h"
#import "WKDB.h"
#define SQL_MESSAGE_EXTRA_INSERT_OR_UPDATE [NSString stringWithFormat:@"insert into message_extra( message_id,message_seq,channel_id,channel_type,readed,readed_at,readed_count,unread_count,revoke,revoker,is_pinned,content_edit,edited_at,extra,extra_version) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(message_id) DO UPDATE SET readed=excluded.readed,readed_at=excluded.readed_at,readed_count=excluded.readed_count,unread_count=excluded.unread_count,revoke=excluded.revoke,revoker=excluded.revoker,is_pinned=excluded.is_pinned,content_edit=excluded.content_edit,edited_at=excluded.edited_at,extra=excluded.extra,extra_version=excluded.extra_version"]

// 获取指定频道的最大扩展版本号
#define SQL_MESSAGE_EXTRA_MAX_VERSION [NSString stringWithFormat:@"select max(extra_version) max_version from %@ where channel_id=? and channel_type=?",@"message_extra"]

// 通过消息ID获取消息扩展
#define SQL_MESSAGE_EXTRA_GET_WITH_MESSAGEID [NSString stringWithFormat:@"select * from %@ where message_id=?",@"message_extra"]

// 消息正文修改或添加
#define SQL_ADD_UPDATE_CONTENT_EDIT [NSString stringWithFormat:@"insert into %@( message_id,message_seq,channel_id,channel_type,content_edit,edited_at,upload_status) values(?,?,?,?,?,?,?) ON CONFLICT(message_id) DO UPDATE SET content_edit=excluded.content_edit,edited_at=excluded.edited_at,upload_status=excluded.upload_status",@"message_extra"]

// 更新已读状态
#define SQL_ADD_UPDATE_READED [NSString stringWithFormat:@"insert into %@( message_id,message_seq,channel_id,channel_type,readed,readed_at) values(?,?,?,?,?,?) ON CONFLICT(message_id) DO UPDATE SET readed=excluded.readed,readed_at=excluded.readed_at",@"message_extra"]

#define SQL_CONTENT_EDIT_UPLOAD_WITH_STATUS [NSString stringWithFormat:@"select * from %@ where upload_status=? limit 100",@"message_extra"]

// 通过状态更新状态
#define SQL_UPDATE_CONTENT_EDIT_UPLOADSTATUS_WITH_UPLOADSTATUS [NSString stringWithFormat:@"update %@ set upload_status=? where upload_status=?",@"message_extra"]

// 通过消息ID更新状态
#define SQL_UPDATE_UPLOADSTATUS_WITH_MESSAGEID [NSString stringWithFormat:@"update %@ set upload_status=? where message_id=?",@"message_extra"]

@implementation WKMessageExtraDB

static WKMessageExtraDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMessageExtraDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) addOrUpdateMessageExtras:(NSArray<WKMessageExtra*>*)messageExtras {
    if(!messageExtras || messageExtras.count == 0) {
        return;
    }
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKMessageExtra *messageExtra in messageExtras) {
            NSString *extraStr = @"";
            if(messageExtra.extra) {
                extraStr = [self extraToStr:messageExtra.extra];
            }
            NSInteger readedAt = 0;
            if(messageExtra.readedAt) {
                readedAt = [messageExtra.readedAt timeIntervalSince1970];
            }
            [db executeUpdate:SQL_MESSAGE_EXTRA_INSERT_OR_UPDATE,@(messageExtra.messageID),@(messageExtra.messageSeq),messageExtra.channelID?:@"",@(messageExtra.channelType),@(messageExtra.readed),@(readedAt),@(messageExtra.readedCount),@(messageExtra.unreadCount),@(messageExtra.revoke),messageExtra.revoker?:@"",@(messageExtra.isPinned),messageExtra.contentEditData?:@"",@(messageExtra.editedAt),extraStr,@(messageExtra.extraVersion)];
            
        }
    }];
}

-(WKMessageExtra*) getMessageExtraWithMessageID:(uint64_t)messageID {
    __block WKMessageExtra *messageExtra;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =  [db executeQuery:SQL_MESSAGE_EXTRA_GET_WITH_MESSAGEID,@(messageID)];
        if(resultSet.next) {
            messageExtra = [self toMessageExtra:resultSet db:db];
        }
        [resultSet close];
    }];
    return messageExtra;
}

-(void) addOrUpdateMessageExtra:(WKMessageExtra*)messageExtra db:(FMDatabase*)db {
    NSString *extraStr = @"";
    if(messageExtra.extra) {
        extraStr = [self extraToStr:messageExtra.extra];
    }
    NSInteger readedAt = 0;
    if(messageExtra.readedAt) {
        readedAt = [messageExtra.readedAt timeIntervalSince1970];
    }
    [db executeUpdate:SQL_MESSAGE_EXTRA_INSERT_OR_UPDATE,@(messageExtra.messageID),@(messageExtra.messageSeq),messageExtra.channelID?:@"",@(messageExtra.channelType),@(messageExtra.readed),@(readedAt),@(messageExtra.readedCount),@(messageExtra.unreadCount),@(messageExtra.revoke),messageExtra.revoker?:@"",@(messageExtra.isPinned),messageExtra.contentEditData?:@"",@(messageExtra.editedAt),extraStr,@(messageExtra.extraVersion)];
}

-(void) addOrUpdateContentEdit:(WKMessageExtra*)messageExtra {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_ADD_UPDATE_CONTENT_EDIT,@(messageExtra.messageID),@(messageExtra.messageSeq),messageExtra.channelID?:@"",@(messageExtra.channelType),messageExtra.contentEditData?:@"",@(messageExtra.editedAt),@(messageExtra.uploadStatus)];
    }];
}

-(NSArray<WKMessageExtra*>*) getContentEditWaitUpload {
    __block NSMutableArray *messageExtras = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_CONTENT_EDIT_UPLOAD_WITH_STATUS,@(WKContentEditUploadStatusWait)];
        while(resultSet.next) {
            [messageExtras addObject:[self toMessageExtra:resultSet db:db]];
        }
        [resultSet close];
    }];
    return messageExtras;
}

-(void) updateContentEditUploadStatusToFailStatus{
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_UPDATE_CONTENT_EDIT_UPLOADSTATUS_WITH_UPLOADSTATUS,@(WKContentEditUploadStatusError),@(WKContentEditUploadStatusWait)];
    }];
}

-(void) updateUploadStatus:(WKContentEditUploadStatus)status withMessageID:(uint64_t)messageID {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_UPDATE_UPLOADSTATUS_WITH_MESSAGEID,@(status),@(messageID)];
    }];
}

-(long long) getMessageExtraMaxVersion:(WKChannel*)channel {
    __block long long maxVersion;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MESSAGE_EXTRA_MAX_VERSION,channel.channelId?:@"",@(channel.channelType)];
        if(resultSet.next) {
            maxVersion = [resultSet longLongIntForColumn:@"max_version"];
        }
        [resultSet close];
    }];
    return maxVersion;
}

-(NSString*) extraToStr:(NSDictionary*)extra {
    NSString *extraStr = @"";
    if(extra) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:kNilOptions error:nil];
        extraStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return extraStr;
}

-(WKMessageExtra*) toMessageExtra:(FMResultSet*)resultSet db:(FMDatabase*)db{
    WKMessageExtra *messageExtra = [WKMessageExtra new];
    messageExtra.messageID = [resultSet unsignedLongLongIntForColumn:@"message_id"];
    messageExtra.messageSeq = (uint32_t)[resultSet unsignedLongLongIntForColumn:@"message_seq"];
    messageExtra.channelID = [resultSet stringForColumn:@"channel_id"];
    messageExtra.channelType = [resultSet intForColumn:@"channel_type"];
    messageExtra.readed = [resultSet boolForColumn:@"readed"];
    messageExtra.isPinned = [resultSet boolForColumn:@"is_pinned"];
    NSInteger readedAt = [resultSet intForColumn:@"readed_at"];
    if(readedAt>0) {
        messageExtra.readedAt = [NSDate dateWithTimeIntervalSince1970:readedAt];
    }
    
    messageExtra.readedCount = [resultSet intForColumn:@"readed_count"];
    messageExtra.unreadCount = [resultSet intForColumn:@"unread_count"];
    messageExtra.revoke = [resultSet boolForColumn:@"revoke"];
    messageExtra.revoker = [resultSet stringForColumn:@"revoker"];
    messageExtra.extraVersion = [resultSet unsignedLongLongIntForColumn:@"extra_version"];
    messageExtra.editedAt = [resultSet intForColumn:@"edited_at"];
    messageExtra.uploadStatus = [resultSet intForColumn:@"upload_status"];
    NSData *contentEditData = [resultSet dataForColumn:@"content_edit"];
    if(contentEditData&& [contentEditData length]>0) {
        messageExtra.contentEditData = contentEditData;
        __autoreleasing NSError *error = nil;
        NSDictionary *contentEditDict = [NSJSONSerialization JSONObjectWithData:contentEditData options:kNilOptions error:&error];
        if(!error && contentEditDict) {
            NSInteger contentType = [contentEditDict[@"type"] integerValue];
            messageExtra.contentEdit = [[WKMessageDB shared] decodeContent:contentType data:contentEditData db:db];
        }
    }
    NSString *extraStr = [resultSet stringForColumn:@"extra"];
    if(extraStr && ![extraStr isEqualToString:@""]) {
        __autoreleasing NSError *error = nil;
        NSDictionary *extraDictionary = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if(!error) {
            messageExtra.extra = extraDictionary;
        }
    }
    return messageExtra;
}

@end
