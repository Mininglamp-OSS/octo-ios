//
//  WKChannelInfoDB.m
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import "WKChannelInfoDB.h"
#import "WKDB.h"
#import "WKChannelInfoSearchResult.h"
#import "WKConst.h"
#define SQL_CHANNEL_SAVE @"insert into channel(channel_id,channel_type,parent_channel_id,parent_channel_type,follow,name,notice,logo,remark,stick,mute,show_nick,save,forbidden,invite,extra,status,online,receipt,robot,last_offline,device_flag,category,be_deleted,be_blacklist,flame,flame_second) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"
// 更新频道信息
#define SQL_CHANNEL_UPDATE @"update channel set  parent_channel_id=?,parent_channel_type=?,name=?,follow=?,notice=?,logo=?,remark=?,stick=?,mute=?,show_nick=?,save=?,forbidden=?,invite=?, extra=?,status=?,online=?,receipt=?,robot=?,last_offline=?,device_flag=?,category=?,be_deleted=?,be_blacklist=?,flame=?,flame_second=? where channel_id=? and channel_type=?"

// 更新频道在线信息
#define SQL_CHANNEL_ONLINESTATUS_UPDATE @"update channel set online=?,last_offline=?,device_flag=? where channel_id=? and channel_type=?"
#define SQL_CHANNEL_ONLINESTATUS_UPDATE_NO_LAST_OFFLINE @"update channel set online=?,device_flag=?  where channel_id=? and channel_type=?"

// 搜索频道
#define SQL_CHANNEL_SEARCH @"select t.*, cm.member_name, cm.member_remark from( select channel.*, max(channel_member.id) mid from channel, channel_member where channel.channel_id = channel_member.channel_id and channel.channel_type = channel_member.channel_type and( channel.name like ? or channel.remark like ? or channel_member.member_name like ? or channel_member.member_remark like ?) group by channel.channel_id, channel.channel_type) t, channel_member cm where t.channel_id = cm.channel_id and t.channel_type = cm.channel_type and t.channel_type =? and t.mid = cm.id order by t.created_at desc limit ?"


// 扩展表的字段
#define SQL_EXTRA_COLS [NSString stringWithFormat:@"%@,%@,%@,%@,%@,%@,%@,%@,%@",@"IFNULL(message_extra.readed,0) readed",@"IFNULL(message_extra.readed_count,0) readed_count",@"IFNULL(message_extra.unread_count,0) unread_count",@"IFNULL(message_extra.revoke,'') revoke",@"IFNULL(message_extra.revoker,0) revoker",@"IFNULL(message_extra.content_edit,'') content_edit",@"IFNULL(message_extra.edited_at,0) edited_at",@"IFNULL(message_extra.upload_status,0) upload_status",@"IFNULL(message_extra.extra_version,0) extra_version"]

// 搜索频道消息
#define SQL_CHANNEL_MESSAGE_SEARCH [NSString stringWithFormat:@"SELECT * from (select channel_id,channel_type,count(*) message_count,max(created_at) created_at,searchable_word,max(order_seq) order_seq  from message where searchable_word like ? and content_type<>99 and from_uid <> '' and is_deleted=0 and revoke=0 group by channel_id,channel_type ) t order by created_at desc limit ?"]

// 移除频道数据
#define SQL_CHANNEL_DELETE @"delete from channel  where channel_id=? and channel_type=?"
// 通过状态查询频道
#define SQL_CHANNEL_WITH_STATUS @"select * from channel where status=? order by created_at desc"

// 通过状态和关注类型查询频道
#define SQL_CHANNEL_WITH_STATUS_AND_FOLLOW @"select * from channel where status=? and follow=? order by created_at desc"

// 查询所有在线的频道
#define SQL_CHANNEL_WITH_ONLINES @"select * from channel where online=1"

// 查询最近会话的所有频道
#define SQL_CHANNEL_WITH_CONVERSATION @"select channel.* from channel,conversation where channel.channel_id=conversation.channel_id and channel.channel_type=conversation.channel_type and conversation.is_deleted=0"

@implementation WKChannelInfoDB

static WKChannelInfoDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKChannelInfoDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(BOOL) saveChannelInfo:(WKChannelInfo*)channelInfo {
    NSLog(@"saveChannelInfo--->%@",channelInfo.channel.channelId);
    if(!channelInfo.channel) {
        NSLog(@"频道对象不能为空！保存失败！");
        return false;
    }
    [[[WKDB sharedDB] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *parentChannelID = channelInfo.parentChannel?channelInfo.parentChannel.channelId:@"";
        NSInteger parentChannelType = channelInfo.parentChannel?channelInfo.parentChannel.channelType:0;
        [db executeUpdate:SQL_CHANNEL_SAVE,channelInfo.channel.channelId?:@"",@(channelInfo.channel.channelType),parentChannelID,@(parentChannelType),@(channelInfo.follow),channelInfo.name?:@"",channelInfo.notice?:@"",channelInfo.logo?:@"",channelInfo.remark?:@"",@(channelInfo.stick),@(channelInfo.mute),@(channelInfo.showNick),@(channelInfo.save),@(channelInfo.forbidden),@(channelInfo.invite),[self extraToStr:channelInfo.extra],@(channelInfo.status),@(channelInfo.online),@(channelInfo.receipt),@(channelInfo.robot),@(channelInfo.lastOffline),@(channelInfo.deviceFlag),channelInfo.category?:@"",@(channelInfo.beDeleted),@(channelInfo.beBlacklist),@(channelInfo.flame),@(channelInfo.flameSecond)];
    }];
    return true;
}

-(BOOL) saveChannelInfo:(WKChannelInfo*)channelInfo db:(FMDatabase*) db{
    NSLog(@"saveChannelInfo-db--->%@",channelInfo.channel.channelId);
    if(!channelInfo.channel) {
        NSLog(@"频道对象不能为空！保存失败！");
        return false;
    }
    NSString *parentChannelID = channelInfo.parentChannel?channelInfo.parentChannel.channelId:@"";
    NSInteger parentChannelType = channelInfo.parentChannel?channelInfo.parentChannel.channelType:0;
    [db executeUpdate:SQL_CHANNEL_SAVE,channelInfo.channel.channelId?:@"",@(channelInfo.channel.channelType),parentChannelID,@(parentChannelType),@(channelInfo.follow),channelInfo.name?:@"",channelInfo.notice?:@"",channelInfo.logo?:@"",channelInfo.remark?:@"",@(channelInfo.stick),@(channelInfo.mute),@(channelInfo.showNick),@(channelInfo.save),@(channelInfo.forbidden),@(channelInfo.invite),[self extraToStr:channelInfo.extra],@(channelInfo.status),@(channelInfo.online),@(channelInfo.receipt),@(channelInfo.robot),@(channelInfo.lastOffline),@(channelInfo.deviceFlag),channelInfo.category?:@"",@(channelInfo.beDeleted),@(channelInfo.beBlacklist),@(channelInfo.flame),@(channelInfo.flameSecond)];
    return true;
}

-(void) updateChannelInfo:(WKChannelInfo*)channelInfo {
    NSLog(@"updateChannelInfo--->%@",channelInfo.channel.channelId);
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *parentChannelID = channelInfo.parentChannel?channelInfo.parentChannel.channelId:@"";
        NSInteger parentChannelType = channelInfo.parentChannel?channelInfo.parentChannel.channelType:0;
        [db executeUpdate:SQL_CHANNEL_UPDATE,parentChannelID,@(parentChannelType),channelInfo.name?:@"",@(channelInfo.follow),channelInfo.notice?:@"",channelInfo.logo?:@"",channelInfo.remark?:@"",@(channelInfo.stick),@(channelInfo.mute),@(channelInfo.showNick),@(channelInfo.save),@(channelInfo.forbidden),@(channelInfo.invite),[self extraToStr:channelInfo.extra],@(channelInfo.status),@(channelInfo.online),@(channelInfo.receipt),@(channelInfo.robot),@(channelInfo.lastOffline),@(channelInfo.deviceFlag),channelInfo.category?:@"",@(channelInfo.beDeleted),@(channelInfo.beBlacklist),@(channelInfo.flame),@(channelInfo.flameSecond),channelInfo.channel.channelId?:@"",@(channelInfo.channel.channelType)];
    }];
}

-(void) updateChannelOnlineStatus:(WKChannel*)channel status:(WKOnlineStatus)status lastOffline:(NSTimeInterval)lastOffline {
    [self updateChannelOnlineStatus:channel status:status lastOffline:lastOffline mainDeviceFlag:WKDeviceFlagEnumUnknown];
}

-(void) updateChannelOnlineStatus:(WKChannel*)channel status:(WKOnlineStatus)status lastOffline:(NSTimeInterval)lastOffline mainDeviceFlag:(WKDeviceFlagEnum)mainDeviceFlag{
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        if(status == WKOnlineStatusOnline) {
             [db executeUpdate:SQL_CHANNEL_ONLINESTATUS_UPDATE_NO_LAST_OFFLINE,@(status),@(mainDeviceFlag),channel.channelId?:@"",@(channel.channelType)];
        }else {
             [db executeUpdate:SQL_CHANNEL_ONLINESTATUS_UPDATE,@(status),@(lastOffline),@(mainDeviceFlag),channel.channelId?:@"",@(channel.channelType)];
        }
       
    }];
}


-(void) deleteChannelInfo:(WKChannel*)channel {
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:SQL_CHANNEL_DELETE,channel.channelId,@(channel.channelType)];
    }];
}

-(void) updateChannelInfo:(WKChannelInfo*)channelInfo db:(FMDatabase*)db {
    NSString *parentChannelID = channelInfo.parentChannel?channelInfo.parentChannel.channelId:@"";
    NSInteger parentChannelType = channelInfo.parentChannel?channelInfo.parentChannel.channelType:0;
    [db executeUpdate:SQL_CHANNEL_UPDATE,parentChannelID,@(parentChannelType),channelInfo.name?:@"",@(channelInfo.follow),channelInfo.notice?:@"",channelInfo.logo?:@"",channelInfo.remark?:@"",@(channelInfo.stick),@(channelInfo.mute),@(channelInfo.showNick),@(channelInfo.save),@(channelInfo.forbidden),@(channelInfo.invite),[self extraToStr:channelInfo.extra],@(channelInfo.status),@(channelInfo.online),@(channelInfo.receipt),@(channelInfo.robot),@(channelInfo.lastOffline),@(channelInfo.deviceFlag),channelInfo.category?:@"",@(channelInfo.beDeleted),@(channelInfo.beBlacklist),@(channelInfo.flame),@(channelInfo.flameSecond),channelInfo.channel.channelId?:@"",@(channelInfo.channel.channelType)];
}

-(WKChannelInfo*) queryChannelInfo:(WKChannel*)channel {
    NSLog(@"queryChannelInfo--->%@",channel.channelId);
    __block WKChannelInfo *channelInfo;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *result = [db executeQuery:@"select * from channel where channel_id=? and channel_type=?",channel.channelId?:@"",@(channel.channelType)];
        if(result.next) {
            channelInfo = [self toChannelInfo:result.resultDictionary];
        }
        [result close];
    }];
    return channelInfo;
}


-(WKChannelInfo*) queryChannelInfo:(WKChannel*)channel db:(FMDatabase*) db {
    NSLog(@"queryChannelInfo-db--->%@",channel.channelId);
    __block WKChannelInfo *channelInfo;
    FMResultSet *result = [db executeQuery:@"select * from channel where channel_id=? and channel_type=?",channel.channelId?:@"",@(channel.channelType)];
    if(result.next) {
        channelInfo = [self toChannelInfo:result.resultDictionary];
    }
    [result close];
    return channelInfo;
}


-(NSArray<WKChannelInfo*>*) queryChannelInfoWithFriend:(NSString*)keyword limit:(NSInteger)limit{
    __block NSMutableArray *channelInfos = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *likeKeyword = [NSString stringWithFormat:@"%%%@%%",[keyword lowercaseString]];
        FMResultSet * result = [db executeQuery:@"select * from channel where ( lower(name) like ? or lower(remark) like ?) and follow=? limit ?",likeKeyword,likeKeyword,@(WKChannelInfoFollowFriend),@(limit)];
        while(result.next) {
            [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
        }
        [result close];
    }];
    return channelInfos;
}

/// 查询所有在线的频道
-(NSArray<WKChannelInfo*>*) queryChannelOnlines {
    __block NSMutableArray *channelInfos = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet * result  = [db executeQuery:SQL_CHANNEL_WITH_ONLINES];
        while(result.next) {
            [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
        }
        [result close];
    }];
    return channelInfos;
}

-(NSArray<WKChannelInfo*>*) queryChannelInfosWithStatus:(WKChannelStatus)status {
    __block NSMutableArray *channelInfos = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet * result = [db executeQuery:SQL_CHANNEL_WITH_STATUS,@(status)];
        while(result.next) {
            [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
        }
        [result close];
    }];
    return channelInfos;
}

-(NSArray<WKChannelInfo*>*) queryChannelInfosWithStatusAndFollow:(WKChannelStatus)status follow:(WKChannelInfoFollow)follow {
    __block NSMutableArray *channelInfos = [NSMutableArray array];
       [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
           FMResultSet * result;
           if(follow == WKChannelInfoFollowAll) {
               result = [db executeQuery:SQL_CHANNEL_WITH_STATUS,@(status)];
           }else {
               result = [db executeQuery:SQL_CHANNEL_WITH_STATUS_AND_FOLLOW,@(status),@(follow)];
           }
          
           while(result.next) {
               [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
           }
           [result close];
       }];
       return channelInfos;
}

-(NSArray<WKChannelMessageSearchResult*>*) searchChannelMessageWithKeyword:(NSString*)keyword  limit:(NSInteger)limit {
     __block NSMutableArray *channelMessageSearchResults = [NSMutableArray array];
     NSString *likeKeyword = [NSString stringWithFormat:@"%%%@%%",keyword];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *result =  [db executeQuery:SQL_CHANNEL_MESSAGE_SEARCH,likeKeyword,@(limit)];
         while(result.next) {
//             WKChannelInfo *channelInfo = [self toChannelInfo:result.resultDictionary];
             WKChannelMessageSearchResult *searchResult = [WKChannelMessageSearchResult new];
             NSString *channelID = [result stringForColumn:@"channel_id"];
             NSInteger channelType = [result intForColumn:@"channel_type"];
             searchResult.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
//             searchResult.channelInfo = channelInfo;
             searchResult.orderSeq = (uint32_t)[result unsignedLongLongIntForColumn:@"order_seq"];
             searchResult.messageCount = [result.resultDictionary[@"message_count"] intValue];
             searchResult.searchableWord = result.resultDictionary[@"searchable_word"];
             [channelMessageSearchResults addObject:searchResult];
         }
        [result close];
    }];
    return channelMessageSearchResults;
}




-(NSArray<WKChannelInfoSearchResult*>*) searchChannelInfoWithKeyword:(NSString*)keyword channelType:(uint8_t)channelType limit:(NSInteger)limit {
     NSString *likeKeyword = [NSString stringWithFormat:@"%%%@%%",keyword];
     __block NSMutableArray *channelInfos = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet * result =  [db executeQuery:SQL_CHANNEL_SEARCH,likeKeyword,likeKeyword,likeKeyword,likeKeyword,@(channelType),@(limit)];
        while(result.next) {
           WKChannelInfo *channelInfo = [self toChannelInfo:result.resultDictionary];
            WKChannelInfoSearchResult *searchResult = [WKChannelInfoSearchResult new];
            searchResult.channelInfo = channelInfo;
            NSString *memberRemark = result.resultDictionary[@"member_remark"];
            NSString *memberName = result.resultDictionary[@"member_name"];
            if(memberRemark && [[memberRemark lowercaseString] rangeOfString:[keyword lowercaseString]].location != NSNotFound) {
                searchResult.containMemberName = memberRemark;
            }else if (memberName && [[memberName lowercaseString] rangeOfString:[keyword lowercaseString]].location != NSNotFound) {
                 searchResult.containMemberName = memberName;
            }
            [channelInfos addObject:searchResult];
        }
        [result close];
    }];
     return channelInfos;
}

-(NSArray<WKChannelInfo*>*) queryChannelInfoWithType:(NSString*)keyword channelType:(uint8_t)channelType limit:(NSInteger)limit {
    __block NSMutableArray *channelInfos = [NSMutableArray array];
       [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
           NSString *likeKeyword = [NSString stringWithFormat:@"%%%@%%",[keyword lowercaseString]];
           FMResultSet * result = [db executeQuery:@"select * from channel where ( lower(name) like ? or lower(remark) like ?) and channel_type=? limit ?",likeKeyword,likeKeyword,@(channelType),@(limit)];
           while(result.next) {
               [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
           }
           [result close];
       }];
       return channelInfos;
}

-(NSArray<WKChannelInfo*>*) queryAllConversationChannelInfos {
    __block NSMutableArray *channelInfos = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet * result = [db executeQuery:SQL_CHANNEL_WITH_CONVERSATION];
        while(result.next) {
            [channelInfos addObject: [self toChannelInfo:result.resultDictionary]];
        }
        [result close];
    }];
    return channelInfos;
}



-(BOOL) existChannelInfo:(WKChannel*)channel db:(FMDatabase*) db {
    __block BOOL exist =false;
    FMResultSet *result = [db executeQuery:@"select count(*) cn from channel where channel_id=? and channel_type=?",channel.channelId?:@"",@(channel.channelType)];
    if(result.next) {
        exist = [result intForColumn:@"cn"]>0;
    }
    [result close];
    return exist;
}

-(NSArray<WKChannelInfo*>*) addOrUpdateChannelInfos:(NSArray<WKChannelInfo*>*)channelInfos {
    NSLog(@"-------------addOrUpdateChannelInfos------------>");
    if(!channelInfos || channelInfos.count<=0) {
        return nil;
    }
     __block NSMutableArray *oldChannelInfos = [NSMutableArray array];
     [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
         for (WKChannelInfo *channelInfo in channelInfos) {
             WKChannelInfo *oldChannelInfo = [self queryChannelInfo:channelInfo.channel db:db];
             if(oldChannelInfo) {
                 [oldChannelInfos addObject:oldChannelInfo];
                 [self updateChannelInfo:channelInfo db:db];
             }else {
                 [self saveChannelInfo:channelInfo db:db];
             }
         }
        
     }];
    return oldChannelInfos;
}

-(NSString*) extraToStr:(NSDictionary*)extra {
    NSString *extraStr = @"";
    if(extra) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:kNilOptions error:nil];
        extraStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return extraStr;
}

-(WKChannelInfo*) toChannelInfo:(NSDictionary*)dict {
    WKChannelInfo *channelInfo = [WKChannelInfo new];
    channelInfo.channel = [[WKChannel alloc] initWith:dict[@"channel_id"] channelType:[dict[@"channel_type"] integerValue]];
    if(dict[@"parent_channel_id"] && ![dict[@"parent_channel_id"] isEqualToString:@""]) {
        channelInfo.parentChannel = [WKChannel channelID:dict[@"parent_channel_id"] channelType:[dict[@"parent_channel_type"] integerValue]];
    }
    
    channelInfo.follow = [dict[@"follow"] intValue];
    channelInfo.name = dict[@"name"];
    channelInfo.notice = dict[@"notice"];
    channelInfo.logo = dict[@"logo"];
    channelInfo.remark = dict[@"remark"];
    channelInfo.stick = [dict[@"stick"] boolValue];
    channelInfo.mute = [dict[@"mute"] boolValue];
    channelInfo.showNick = [dict[@"show_nick"] boolValue];
    channelInfo.save = [dict[@"save"] boolValue];
    channelInfo.forbidden = [dict[@"forbidden"] boolValue];
    channelInfo.invite = [dict[@"invite"] boolValue];
    channelInfo.status = [dict[@"status"] integerValue];
    
    channelInfo.receipt = [dict[@"receipt"] boolValue];
    channelInfo.robot = [dict[@"robot"] boolValue];
   
    channelInfo.category = dict[@"category"];
    
    channelInfo.online = [dict[@"online"] boolValue];
    channelInfo.lastOffline = [dict[@"last_offline"] integerValue];
    channelInfo.deviceFlag = [dict[@"device_flag"] integerValue];
    
    channelInfo.beDeleted = [dict[@"be_deleted"] boolValue];
    channelInfo.beBlacklist = [dict[@"be_blacklist"] boolValue];
    
    channelInfo.flame = [dict[@"flame"] boolValue];
    channelInfo.flameSecond = [dict[@"flame_second"] integerValue];
    
    NSString *extraStr = dict[@"extra"];
    __autoreleasing NSError *error = nil;
    NSDictionary *extraDictionary = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
    if(!error) {
        channelInfo.extra = [NSMutableDictionary dictionaryWithDictionary:extraDictionary];
    }
    return channelInfo;
}
@end
