//
//  WKFriendRequestDB.m
//  WuKongBase
//
//  Created by tt on 2020/1/4.
//

#import "WKFriendRequestDB.h"
#import "WKKitDB.h"
#import "WKContactsManager.h"
// 添加好友请求
#define WK_ADD_FRIENDREQUEST_SQL @"insert into lim_friend_req(uid,name,avatar,remark,token,status,readed) values(?,?,?,?,?,?,?)"
// 获取单个好友请求
#define WK_GET_FRIENDREQUEST_SQL @"select * from lim_friend_req where uid=?"

#define WK_GETALL_FRIENDREQUEST_SQL @"select * from lim_friend_req order by created_at desc"
// 删除好友请求
#define WK_DELETE_FRIENDREQUEST_SQL @"delete from lim_friend_req where uid=?"
// 获取未读数
#define WK_UNREAD_FRIENDREQUEST_SQL @"select count(*) cn from lim_friend_req where readed=0"

// 更新所有未读请求为已读
#define WK_MARK_FRIENDREQUEST_TO_READED_SQL @"update lim_friend_req set readed=1 where readed=0"

// 更新某个请求状态
#define WK_UPDATE_FRIENDREQUEST_STATUS_SQL @"update lim_friend_req set status=?,readed=1 where uid=?"


@implementation WKFriendRequestDB

static WKFriendRequestDB *_instance = nil;
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(BOOL) addFriendRequest:(WKFriendRequestDBModel*)model {
    __weak typeof(self) weakSelf = self;
    __block BOOL isNewRequest = true; // 是否是新的请求
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        WKFriendRequestDBModel *existFriendRequest = [self getFriendRequest:model.uid db:db];
        if(existFriendRequest) {
            [weakSelf deleteFriendRequest:model.uid db:db];
            if(existFriendRequest.status == WKFriendRequestStatusWaitSure) {
                isNewRequest = false;
            }else {
                isNewRequest = true;
            }
        }
        [db executeUpdate:WK_ADD_FRIENDREQUEST_SQL,model.uid,model.name,model.avatar,model.remark,model.token,@(model.status),@(model.readed),model.createdAt,model.updatedAt];
    }];
    return isNewRequest;
}

-(NSArray<WKFriendRequestDBModel*>*) getAllFriendRequest {
    __block NSMutableArray *models =[[NSMutableArray alloc] init];
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:WK_GETALL_FRIENDREQUEST_SQL];
        while (resultSet.next) {
            [models addObject:[self to:resultSet]];
        }
        [resultSet close];
    }];
    return models;
}
-(int) getFriendRequestUnreadCount {
    __block int unreadCount = 0;
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:WK_UNREAD_FRIENDREQUEST_SQL];
        if(resultSet.next) {
            unreadCount = [resultSet intForColumn:@"cn"];
        }
        [resultSet close];
    }];
    return unreadCount;
}

-(WKFriendRequestDBModel*) getFriendRequest:(NSString*)uid db:(FMDatabase*) db {
    FMResultSet *resultSet = [db executeQuery:WK_GET_FRIENDREQUEST_SQL,uid];
    if(!resultSet.next) {
        [resultSet close];
        return nil;
    }
    WKFriendRequestDBModel *model = [self to:resultSet];
    [resultSet close];
    return model;
}

-(void) markAllFriendRequestToReaded {
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:WK_MARK_FRIENDREQUEST_TO_READED_SQL];
    }];
}

-(void) updateFriendRequestStatus:(NSString*)uid status:(WKFriendRequestStatus)status {
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:WK_UPDATE_FRIENDREQUEST_STATUS_SQL,@(status),uid];
    }];
}

-(void) deleteFriendRequest:(NSString*)uid db:(FMDatabase*)db{
    [db executeUpdate:WK_DELETE_FRIENDREQUEST_SQL,uid];
}

-(void) deleteFriendRequest:(NSString*)uid{
    [[WKKitDB shared].dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [self deleteFriendRequest:uid db:db];
    }];
}

-(WKFriendRequestDBModel*) to:(FMResultSet*)resultSet {
    WKFriendRequestDBModel *model = [WKFriendRequestDBModel new];
    model.uid = [resultSet stringForColumn:@"uid"];
    model.name = [resultSet stringForColumn:@"name"];
    model.avatar = [resultSet stringForColumn:@"avatar"];
    model.remark = [resultSet stringForColumn:@"remark"];
    model.status = [resultSet intForColumn:@"status"];
    model.readed = [resultSet boolForColumn:@"readed"];
    model.token = [resultSet stringForColumn:@"token"];
    model.createdAt = [resultSet dateForColumn:@"created_at"];
    model.updatedAt = [resultSet dateForColumn:@"updated_at"];
    return model;
}


@end

@implementation WKFriendRequestDBModel


@end
