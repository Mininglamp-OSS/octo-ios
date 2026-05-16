//
//  WKChannelMemberDB.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/20.
//

#import "WKChannelMemberDB.h"
#import "WKDB.h"
#import "WKSDK.h"

// 添加成员信息
#define SQL_MEMBER_ADD [NSString stringWithFormat:@"insert into channel_member(channel_id,channel_type,member_uid,member_name,member_avatar,member_remark,role,status,version,extra,created_at,updated_at,robot,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?)"]

// 更新成员信息
#define SQL_MEMBER_UPDATE [NSString stringWithFormat:@"update channel_member set channel_id=?,channel_type=?,member_uid=?,member_name=?,member_avatar=?,member_remark=?,role=?,status=?,version=?,extra=?,created_at=?,updated_at=?,robot=?,is_deleted=? where channel_id=? and channel_type=? and member_uid=?"]

#define SQL_MEMBER_UPDATE_OR_ADD [NSString stringWithFormat:@"insert into channel_member(channel_id,channel_type,member_uid,member_name,member_avatar,member_remark,role,status,version,extra,created_at,updated_at,robot,is_deleted) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(channel_id,channel_type,member_uid) DO UPDATE SET member_name=excluded.member_name,member_avatar=excluded.member_avatar,member_remark=excluded.member_remark,role=excluded.role,status=excluded.status,version=excluded.version,extra=excluded.extra,created_at=excluded.created_at,updated_at=excluded.updated_at,robot=excluded.robot,is_deleted=excluded.is_deleted"]

// 是否存在
#define SQL_MEMBER_EXIST [NSString stringWithFormat:@"select count(*) cn from channel_member where channel_id=? and channel_type=? and member_uid=?"]
// 是否存在通过成员uid
#define SQL_MEMBER_EXIST_WITH_UID [NSString stringWithFormat:@"select count(*) cn from channel_member where channel_id=? and channel_type=? and member_uid=? and is_deleted=0 and status=1"]
// 获取最新同步key
#define SQL_MEMBER_SYNCKEY [NSString stringWithFormat:@"select max(version) version from channel_member where channel_id=? and channel_type=? limit 1"]

#define SQL_SELECT_CONTENT @"channel_member.channel_id,channel_member.channel_type,channel_member.member_uid ,channel_member.member_avatar,channel_member.member_remark,channel_member.role,channel_member.status,channel_member.version,channel_member.extra,channel_member.created_at,channel_member.updated_at,channel_member.robot,channel_member.is_deleted,IFNULL(channel.name,channel_member.member_name) member_name"

// 查询频道成员
#define SQL_MEMBER_LIST [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1  where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 order by channel_member.role=? desc,channel_member.role=? desc,channel_member.created_at asc",SQL_SELECT_CONTENT]

// 查询频道成员
#define SQL_MEMBER_LIST_WKIT [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 order by channel_member.role=? desc,channel_member.role=? desc,channel_member.created_at asc limit ?",SQL_SELECT_CONTENT]

// 查询频道成员(分页查询)
#define SQL_MEMBER_LIST_PAGE [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 order by channel_member.role=? desc,channel_member.role=? desc,channel_member.created_at asc limit ?,?",SQL_SELECT_CONTENT]


// 查询频道成员(分页查询)
#define SQL_MEMBER_LIST_PAGE_WITH_KEYWORD [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and (channel_member.status=1) and (member_name like ? or member_remark like ? or channel.remark like ?) order by channel_member.role=? desc,channel_member.role=? desc,channel_member.created_at asc limit ?,?",SQL_SELECT_CONTENT]

// 查询成员数量
#define SQL_MEMBER_COUNT [NSString stringWithFormat:@"select count(*) from channel_member where channel_id=? and channel_type=? and is_deleted=0 and status=1"]

// 查询频道成员黑明单
#define SQL_MEMBER_BLACK_LIST [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=2 order by channel_member.created_at asc",SQL_SELECT_CONTENT]

// 查询频道成员通过角色
#define SQL_MEMBER_LIST_WITH_ROLE [NSString stringWithFormat:@"select %@ from  channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 and channel_member.role=? order by channel_member.created_at asc",SQL_SELECT_CONTENT]

// 分页查询频道成员
#define SQL_MEMBER_PAGE [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 limit ?,?",SQL_SELECT_CONTENT]
// 查询频道成员
#define SQL_MEMBER_LIST_WITH_UIDS [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.is_deleted=0 and channel_member.status=1 and channel_member.member_uid in ",SQL_SELECT_CONTENT]

#define SQL_UPDATE_MEMBER_STATUS [NSString stringWithFormat:@"update channel_member set status=? where channel_id=? and channel_type=? and member_uid in "]

// 查询成员是否是管理者
#define SQL_MEMBER_ISMANAGER [NSString stringWithFormat:@"select count(*) cn from channel_member where channel_id=? and channel_type=? and member_uid=? and (role=? or role=?) and is_deleted=0 and status=1"]
// 查询成员是否是管理者
#define SQL_MEMBER_ISCREATOR [NSString stringWithFormat:@"select count(*) cn from channel_member where channel_id=? and channel_type=? and member_uid=? and role=? and is_deleted=0 and status=1"]
// 查询指定群成员
#define SQL_MEMBER_WITH_UID [NSString stringWithFormat:@"select  %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and channel_member.member_uid=? and channel_member.is_deleted=0 and channel_member.status=1",SQL_SELECT_CONTENT]
// 查询群管理者和创建者
#define SQL_MEMBER_MANAGER_CREATOR [NSString stringWithFormat:@"select %@ from channel_member left join channel on channel_member.member_uid=channel.channel_id and channel.channel_type=1 where channel_member.channel_id=? and channel_member.channel_type=? and (channel_member.role=? or channel_member.role=?) and channel_member.is_deleted=0 and channel_member.status=1 order by channel_member.role=? desc,channel_member.role=? desc,channel_member.created_at asc",SQL_SELECT_CONTENT]

#define SQL_MEMBER_DELETE @"delete from channel_member where channel_id=? and channel_type=?"


@implementation WKChannelMember

- (NSMutableDictionary *)extra {
    if(!_extra) {
        _extra = [NSMutableDictionary dictionary];
    }
    return _extra;
}

- (NSString *)displayName {
    if(_memberRemark && ![_memberRemark isEqualToString:@""] ) {
        return _memberRemark;
    }
    return _memberName;
}


-(BOOL) isEqual:(id)obj{
    if(self == obj) {
        return YES;
    }
    WKChannelMember *cm = (WKChannelMember*)obj;
    if(self.channelId && [self.channelId isEqual:cm.channelId] &&self.channelType == cm.channelType && [self.memberUid isEqualToString:cm.memberUid]) {
        return YES;
    }
    
    return NO;
}

- (NSUInteger)hash {
    return [self.channelId hash] ^ self.channelType^[self.memberUid hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"channelId: %@ channelType: %d uid:%@", self.channelId,self.channelType,self.memberUid];
}

@end

@interface WKChannelMemberDB ()

@property(nonatomic,strong) NSLock *memberLock;

@end

@implementation WKChannelMemberDB

static WKChannelMemberDB *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKChannelMemberDB *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) addOrUpdateMembers:(NSArray<WKChannelMember*>*)members {
    if(!members || members.count<=0) {
        return;
    }
    [[WKDB sharedDB].dbQueue  inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKChannelMember *member in members) {
            [db executeUpdate:SQL_MEMBER_UPDATE_OR_ADD,member.channelId?:@"",@(member.channelType),member.memberUid,member.memberName?:@"",member.memberAvatar?:@"",member.memberRemark?:@"",@(member.role),@(member.status),member.version?:@(0),[self extraToStr:member.extra],member.createdAt?:@"",member.updatedAt?:@"",@(member.robot),member.isDeleted?@(1):@(0)];
        }
    }];
}

-(void) deleteMembers:(WKChannel*)channel {
     [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
         [db executeUpdate:SQL_MEMBER_DELETE,channel.channelId,@(channel.channelType)];
     }];
}

-(NSString*) getMemberLastSyncKey:(WKChannel*)channel {
    __block NSString *syncKey;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet =  [db executeQuery:SQL_MEMBER_SYNCKEY,channel.channelId,@(channel.channelType)];
        if(resultSet.next) {
            syncKey = [resultSet stringForColumn:@"version"];
        }
        [resultSet close];
    }];
    return syncKey;
}

-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_LIST,channel.channelId,@(channel.channelType),@(WKMemberRoleCreator),@(WKMemberRoleManager)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}

-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel limit:(NSInteger)limit {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_LIST_WKIT,channel.channelId,@(channel.channelType),@(WKMemberRoleCreator),@(WKMemberRoleManager),@(limit)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}


-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel keyword:(NSString*)keyword page:(NSInteger)page limit:(NSInteger)limit {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet;
        if(keyword && ![keyword isEqualToString:@""]) {
            resultSet = [db executeQuery:SQL_MEMBER_LIST_PAGE_WITH_KEYWORD,channel.channelId,@(channel.channelType),[NSString stringWithFormat:@"%%%@%%",keyword],[NSString stringWithFormat:@"%%%@%%",keyword],[NSString stringWithFormat:@"%%%@%%",keyword],@(WKMemberRoleCreator),@(WKMemberRoleManager),@((page-1)*limit),@(limit)];
        }else {
            resultSet = [db executeQuery:SQL_MEMBER_LIST_PAGE,channel.channelId,@(channel.channelType),@(WKMemberRoleCreator),@(WKMemberRoleManager),@((page-1)*limit),@(limit)];
        }
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}


-(NSInteger) getMemberCount:(WKChannel*)channel {
    __block NSInteger count = 0;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_COUNT,channel.channelId,@(channel.channelType)];
        if(resultSet.next) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];
    return  count;
}


-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel role:(WKMemberRole)role {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_LIST_WITH_ROLE,channel.channelId,@(channel.channelType),@(role)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}

-(NSArray<WKChannelMember*>*) getBlacklistMembersWithChannel:(WKChannel*)channel {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_BLACK_LIST,channel.channelId,@(channel.channelType)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}

-(NSArray<WKChannelMember*>*) getManagerAndCreator:(WKChannel*)channel {
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
       FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_MANAGER_CREATOR,channel.channelId,@(channel.channelType),@(WKMemberRoleCreator),@(WKMemberRoleManager),@(WKMemberRoleCreator),@(WKMemberRoleManager)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
     return members;
}

-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel uids:(NSArray<NSString*>*)uids {
    if(!uids||uids.count<=0) {
        return nil;
    }
    __block NSMutableArray *members = [NSMutableArray array];
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray *uidsIns = [NSMutableArray array];;
        for (NSString *uid in uids) {
            [uidsIns addObject:[NSString stringWithFormat:@"\"%@\"",uid]];
        }
        FMResultSet *resultSet = [db executeQuery:[NSString stringWithFormat:@"%@ (%@)",SQL_MEMBER_LIST_WITH_UIDS,[uidsIns componentsJoinedByString:@","]],channel.channelId,@(channel.channelType)];
        while (resultSet.next) {
            [members addObject:[self toMemberModel:resultSet]];
        }
        [resultSet close];
    }];
    return members;
}

-(void) updateMemberStatus:(WKMemberStatus)status channel:(WKChannel*) channel  uids:(NSArray<NSString*>*)uids {
    if(!uids||uids.count<=0) {
        return;
    }
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableArray *uidsIns = [NSMutableArray array];;
        for (NSString *uid in uids) {
            [uidsIns addObject:[NSString stringWithFormat:@"\"%@\"",uid]];
        }
        [db executeUpdate:[NSString stringWithFormat:@"%@ (%@)",SQL_UPDATE_MEMBER_STATUS,[uidsIns componentsJoinedByString:@","]],@(status),channel.channelId,@(channel.channelType)];
    }];
}


-(BOOL) isManager:(WKChannel*)channel memberUID:(NSString*)uid {
    __block BOOL exist;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_ISMANAGER,channel.channelId?:@"",@(channel.channelType),uid?:@"",@(WKMemberRoleCreator),@(WKMemberRoleManager)];
        if(resultSet.next) {
            exist = [resultSet intForColumn:@"cn"];
        }
        [resultSet close];
        
    }];
    return exist;
}

- (BOOL)isCreator:(WKChannel*)channel  memberUID:(NSString *)uid {
    __block BOOL exist;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_ISCREATOR,channel.channelId?:@"",@(channel.channelType),uid?:@"",@(WKMemberRoleCreator)];
        if(resultSet.next) {
            exist = [resultSet intForColumn:@"cn"];
        }
        [resultSet close];
        
    }];
    return exist;
}

-(BOOL) exist:(WKChannel*)channel uid:(NSString*)uid {
    __block BOOL exist;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_EXIST_WITH_UID,channel.channelId?:@"",@(channel.channelType),uid?:@""];
        if(resultSet.next) {
            exist = [resultSet intForColumn:@"cn"]>0;
        }
        [resultSet close];
        
    }];
    return exist;
}

- (WKChannelMember*)get:(WKChannel*)channel  memberUID:(NSString *)uid {
    __block WKChannelMember *member;
    [[WKDB sharedDB].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:SQL_MEMBER_WITH_UID,channel.channelId?:@"",@(channel.channelType),uid?:@"",@(WKMemberRoleCreator)];
        if(resultSet.next) {
            member = [self toMemberModel:resultSet];
        }
        [resultSet close];
        
    }];
    return member;
}


-(WKChannelMember*) toMemberModel:(FMResultSet*) resultSet {
    WKChannelMember *member = [WKChannelMember new];
    member.channelId = [resultSet stringForColumn:@"channel_id"];
    member.channelType = [resultSet intForColumn:@"channel_type"];
    member.memberUid = [resultSet stringForColumn:@"member_uid"];
    member.memberName = [resultSet stringForColumn:@"member_name"];
    member.memberAvatar = [resultSet stringForColumn:@"member_avatar"];
    member.memberRemark = [resultSet stringForColumn:@"member_remark"];
    member.role = [resultSet intForColumn:@"role"];
    member.status = [resultSet intForColumn:@"status"];
    member.createdAt = [resultSet stringForColumn:@"created_at"];
    member.updatedAt = [resultSet stringForColumn:@"updated_at"];
    member.robot = [resultSet boolForColumn:@"robot"];
    member.isDeleted = [resultSet boolForColumn:@"is_deleted"];
    
    NSString *extraStr = [resultSet stringForColumn:@"extra"];
    if(extraStr && ![extraStr isEqualToString:@""]) {
        __autoreleasing NSError *error = nil;
        NSDictionary *extraDictionary = [NSJSONSerialization JSONObjectWithData:[extraStr dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if(!error) {
            member.extra = [NSMutableDictionary dictionaryWithDictionary:extraDictionary];
        }
    }
   
    return member;
}




- (NSLock *)memberLock {
    if(!_memberLock) {
        _memberLock = [[NSLock alloc] init];
    }
    return _memberLock;
}

-(NSString*) extraToStr:(NSDictionary*)extra {
    NSString *extraStr = @"";
    if(extra) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extra options:kNilOptions error:nil];
        extraStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return extraStr;
}
@end
