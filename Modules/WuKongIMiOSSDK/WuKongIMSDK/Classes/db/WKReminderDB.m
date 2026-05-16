//
//  WKReminderDB.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/19.
//

#import "WKReminderDB.h"
#import "WKDB.h"
#import "WKSDK.h"

#define SQL_ADD_UPDATE [NSString stringWithFormat:@"insert into %@( reminder_id,message_id,message_seq,channel_id,channel_type,`type`,`text`,`data`,publisher,is_locate,version,done) values(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(reminder_id) DO UPDATE SET `text`=excluded.text,`data`=excluded.data,is_locate=excluded.is_locate,version=excluded.version,done=excluded.done",@"reminders"]

#define SQL_GET_NO_DONE_WITH_CHANNELS [NSString stringWithFormat:@"select * from %@ where done=0 and upload_status<>2 and publisher<>? and channel_id in ",@"reminders"]

#define SQL_GET_NO_DONE_WITH_CHANNEL [NSString stringWithFormat:@"select * from %@ where done=0 and upload_status<>2 and channel_id=? and channel_type=? and publisher<>?",@"reminders"]
// 获取所有等待提醒的提醒项
#define SQL_GET_ALL_WAIT_DONE [NSString stringWithFormat:@"select * from %@ where done=0 and upload_status<>2 and publisher<>?",@"reminders"]

#define SQL_LIST_WAIT_DONE_WITH_TYPE_CHANNEL [NSString stringWithFormat:@"select * from %@ where done=0 and upload_status<>2 and channel_id=? and channel_type=? and `type`=? and publisher<>?",@"reminders"]

#define SQL_MAX_VERSION [NSString stringWithFormat:@"select max(version) max_version from %@",@"reminders"]

// 更新reminder为对应的done
#define SQL_UPDATE_DONE [NSString stringWithFormat:@"update %@ set done=1,upload_status=1,done_at=? where reminder_id in ",@"reminders"]

#define SQL_UPDATE_UPLOAD_FAIL [NSString stringWithFormat:@"update %@ set upload_status=2  where done=1 and done_at<? ",@"reminders"]

// 查询等待上传的reminder
#define SQL_GET_WAIT_UPLOAD [NSString stringWithFormat:@"select * from %@ where upload_status=1 limit 100",@"reminders"]

#define SQL_UPDATE_UPLOAD_STATIS [NSString stringWithFormat:@"update %@ set upload_status=? where reminder_id=? ",@"reminders"]

#define SQL_GET_WITH_IDS [NSString stringWithFormat:@"select * from %@ where reminder_id in ",@"reminders"]

@implementation WKReminderDB

static WKReminderDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKReminderDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) addOrUpdates:(NSArray<WKReminder*>*)reminders {
    if(!reminders || reminders.count==0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[WKDB sharedDB].dbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKReminder *reminder in reminders) {
            NSString *dataStr = [weakSelf dataToStr:reminder.data];
            [db executeUpdate:SQL_ADD_UPDATE,@(reminder.reminderID),@(reminder.messageId),@(reminder.messageSeq),reminder.channel.channelId,@(reminder.channel.channelType),@(reminder.type),reminder.text?:@"",dataStr,reminder.publisher?:@"",@(reminder.isLocate),@(reminder.version),@(reminder.done)];
        }
    }];
}

-(NSArray<WKReminder*>*) getWaitDoneReminders:(WKChannel*)channel type:(WKReminderType)type {
    
    __block NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_LIST_WAIT_DONE_WITH_TYPE_CHANNEL,channel.channelId,@(channel.channelType),@(type),WKSDK.shared.options.connectInfo.uid?:@""];
        while (resultSet.next) {
            [reminders addObject:[self toReminder:resultSet]];
        }
        [resultSet close];
    }];
    return reminders;
}

-(int64_t) getMaxVersion {
    __block int64_t maxVersion = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result = [db executeQuery:SQL_MAX_VERSION];
        if(result.next) {
            maxVersion = [result longLongIntForColumn:@"max_version"];
        }
        [result close];
    }];
    return maxVersion;
}

-(NSDictionary<WKChannel*,NSArray<WKReminder*>*>*) getAllWaitDoneReminders {
    
    NSMutableDictionary<WKChannel*,NSMutableArray<WKReminder*>*> *reminderDicts = [NSMutableDictionary dictionary];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =  [db executeQuery:SQL_GET_ALL_WAIT_DONE,WKSDK.shared.options.connectInfo.uid?:@""];
        while (resultSet.next) {
            WKReminder *reminder = [self toReminder:resultSet];
            NSMutableArray<WKReminder*> *reminders = reminderDicts[reminder.channel];
            if(!reminders) {
                reminders = [NSMutableArray array];
            }
            [reminders addObject:reminder];
            reminderDicts[reminder.channel] = reminders;
        }
        [resultSet close];
    }];
    return reminderDicts;
}

-(NSArray<WKReminder*>*) getWaitDoneReminder:(WKChannel*) channel {
    __block NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_GET_NO_DONE_WITH_CHANNEL,channel.channelId,@(channel.channelType),WKSDK.shared.options.connectInfo.uid?:@""];
        while (resultSet.next) {
            [reminders addObject:[self toReminder:resultSet]];
        }
        [resultSet close];
    }];
    return reminders;
}

-(void) updateDone:(NSArray<NSNumber*>*)ids {
    if(!ids||ids.count == 0) {
        return;
    }
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:[NSString stringWithFormat:@"%@ (%@)",SQL_UPDATE_DONE,[ids componentsJoinedByString:@","]],@([[NSDate date] timeIntervalSince1970])];
    }];
}

-(void) updateExpireDoneUploadStatusFail:(NSInteger)expireTime {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_UPDATE_UPLOAD_FAIL,@(expireTime)];
    }];
}

- (NSArray<WKReminder *> *)getWaitUploads {
    NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_GET_WAIT_UPLOAD];
        while (resultSet.next) {
            [reminders addObject:[self toReminder:resultSet]];
        }
        [resultSet close];
    }];
    return reminders;
}

-(void) updateUploadStatus:(WKReminderUploadStatus)status reminderID:(NSNumber*)reminderID {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_UPDATE_UPLOAD_STATIS,@(status),reminderID];
    }];
}

-(NSArray<WKReminder*>*) getReminders:(NSArray<NSNumber*>*)ids {
    __block NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue  inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =[db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_GET_WITH_IDS,[ids componentsJoinedByString:@","]]];
        while(resultSet.next) {
            [reminders addObject:[self toReminder:resultSet]];
        }
        [resultSet close];
    }];
    return reminders;
}

-(NSDictionary<WKChannel*,NSArray<WKReminder*>*>*)  getWaitDoneReminders:(NSArray<WKChannel*>*) channels {
    if(!channels||channels.count == 0) {
        return nil;
    }
    NSMutableArray *channelIDs = [NSMutableArray array];
    for (WKChannel *channel in channels) {
        [channelIDs addObject:channel.channelId];
    }
    __block NSMutableArray *reminders = [NSMutableArray array];
    NSString *inquery = @"";
    for (NSInteger i=0; i<channelIDs.count; i++) {
        NSString *channelID = channelIDs[i];
        if(i == channels.count-1) {
            inquery = [NSString stringWithFormat:@"%@'%@'",inquery,channelID];
        }else {
            inquery = [NSString stringWithFormat:@"%@'%@',",inquery,channelID];
        }
        
    }
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =  [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_GET_NO_DONE_WITH_CHANNELS,inquery],WKSDK.shared.options.connectInfo.uid?:@""];
        while (resultSet.next) {
            WKReminder *reminder = [self toReminder:resultSet];
            [reminders addObject:reminder];
        }
        [resultSet close];
    }];
    NSMutableDictionary *reminderDict = [NSMutableDictionary dictionary];
    for (WKReminder *reminder in reminders) {
        NSMutableArray *channelReminders = reminderDict[reminder.channel];
        if(!channelReminders) {
            channelReminders=  [NSMutableArray array];
        }
        [channelReminders addObject:reminder];
        reminderDict[reminder.channel] = channelReminders;
    }
    return reminderDict;
}


-(WKReminder*) toReminder:(FMResultSet*)resultSet {
    WKReminder *reminder = [[WKReminder alloc] init];
    reminder.reminderID = [resultSet longLongIntForColumn:@"reminder_id"];
    reminder.messageId = [resultSet unsignedLongLongIntForColumn:@"message_id"];
    reminder.messageSeq = (uint32_t)[resultSet unsignedLongLongIntForColumn:@"message_seq"];
    NSString *channelID = [resultSet stringForColumn:@"channel_id"];
    NSInteger channelType = [resultSet intForColumn:@"channel_type"];
    
    WKChannel *channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
    reminder.channel = channel;
    reminder.type = [resultSet intForColumn:@"type"];
    reminder.text = [resultSet stringForColumn:@"text"];
    
    reminder.done = [resultSet boolForColumn:@"done"];
    reminder.isLocate = [resultSet boolForColumn:@"is_locate"];
    reminder.version = [resultSet longLongIntForColumn:@"version"];
    reminder.publisher = [resultSet stringForColumn:@"publisher"];
    NSString *data = [resultSet stringForColumn:@"data"];
    if(data) {
        __autoreleasing NSError *error = nil;
        NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if(!error) {
            reminder.data = dataDictionary;
        }
    }
    return reminder;
}

-(NSString*) dataToStr:(NSDictionary*)data {
    NSString *dataStr = @"";
    if(data) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:kNilOptions error:nil];
        dataStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return dataStr;
}

@end
