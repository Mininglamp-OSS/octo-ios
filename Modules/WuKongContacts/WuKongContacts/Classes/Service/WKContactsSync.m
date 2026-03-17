//
//  WKContactsSync.m
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import "WKContactsSync.h"
@implementation WKContactsSync

- (BOOL)needSync {
    return true;
}

- (void)sync:(void (^)(NSError *))callback {
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (currentSpaceId && currentSpaceId.length > 0) {
        // Space 模式：从 Space 成员获取联系人（参考 Web 端 datasource.ts contactsSync）
        [self syncSpaceContacts:currentSpaceId callback:callback];
    } else {
        // 个人模式：好友同步
        [self syncFriendContacts:callback];
    }
}

// Space 模式：通过 space/{spaceId}/members 获取联系人
- (void)syncSpaceContacts:(NSString *)spaceId callback:(void (^)(NSError *))callback {
    NSString *path = [NSString stringWithFormat:@"space/%@/members", spaceId];
    [[WKAPIClient sharedClient] GET:path parameters:@{@"page":@"1", @"limit":@"10000"}].then(^(NSArray<NSDictionary*>* members){
        // 防止竞态条件：请求返回后检查 Space 是否已切换
        NSString *nowSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        if (![spaceId isEqualToString:nowSpaceId]) {
            if (callback) callback(nil);
            return;
        }

        // 先将所有个人频道的 follow 重置为未关注，清除旧空间的联系人
        [[WKChannelInfoDB shared] resetAllPersonChannelFollow];

        NSMutableArray *channelInfos = [NSMutableArray array];
        if (members && members.count > 0) {
            for (NSDictionary *m in members) {
                NSString *uid = m[@"uid"];
                // 排除自己
                if (!uid || [uid isEqualToString:[WKApp shared].loginInfo.uid]) continue;

                WKChannel *channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
                // 先查询数据库中已有的频道信息，避免全量覆盖丢失字段
                WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
                if (!channelInfo) {
                    channelInfo = [WKChannelInfo new];
                    channelInfo.channel = channel;
                }
                channelInfo.name = m[@"name"] ?: @"";
                channelInfo.logo = m[@"avatar"] ?: @"";
                if (!channelInfo.logo || [channelInfo.logo isEqualToString:@""]) {
                    channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar", uid];
                }
                channelInfo.follow = WKChannelInfoFollowFriend;
                channelInfo.status = 1;
                channelInfo.robot = m[@"robot"] ? [m[@"robot"] boolValue] : NO;
                if (m[@"category"] && ![m[@"category"] isEqual:[NSNull null]]) {
                    channelInfo.category = m[@"category"];
                }
                [channelInfos addObject:channelInfo];
            }
        }
        [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];
        [[NSNotificationCenter defaultCenter] postNotificationName:WK_NOTIFY_CONTACTS_UPDATE object:nil];
        if (callback) callback(nil);
    }).catch(^(NSError *error){
        if (callback) callback(error);
        WKLogError(@"同步Space联系人数据出错:%@", error);
    });
}

// 个人模式：通过 friend/sync 获取联系人
- (void)syncFriendContacts:(void (^)(NSError *))callback {
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@",[WKApp shared].loginInfo.uid,@"friend_version"];
    NSString *friendMaxVersion = [[NSUserDefaults standardUserDefaults] stringForKey:cacheKey];
    NSInteger limit = 200;
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"friend/sync"] parameters:@{@"version":friendMaxVersion?:@"",@"api_version":@"1",@"limit":@(limit)}].then(^(NSArray<NSDictionary*>* contacts){
        if(contacts && contacts.count>0) {
            NSMutableArray *channelInfos = [NSMutableArray array];
            for (NSDictionary *dict in contacts) {
                BOOL isDeleted = false;
                if(dict[@"is_deleted"]) {
                    isDeleted = [dict[@"is_deleted"] boolValue];
                }
                if(isDeleted) {
                    WKChannel *channel = [[WKChannel alloc] initWith:dict[@"uid"] channelType:WK_PERSON];
                    [[WKSDK shared].channelManager deleteChannelInfo:channel];
                }else{
                    [channelInfos addObject:[WKChannelUtil toChannelInfo:dict]];
                }
            }
            long long version = [contacts.lastObject[@"version"] longLongValue];
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld",version] forKey:cacheKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];

            // 如果返回的数量等于限制数量，说明可能还有更多数据，延迟后继续同步
            if(contacts.count >= limit) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if(weakSelf) {
                        [weakSelf syncFriendContacts:callback];
                    } else {
                        if(callback) {
                            callback(nil);
                        }
                    }
                });
                return;
            }
        }
        // 没有更多数据了，通知联系人更新并结束同步
        [[NSNotificationCenter defaultCenter] postNotificationName:WK_NOTIFY_CONTACTS_UPDATE object:nil];
        if(callback) {
            callback(nil);
        }

    }).catch(^(NSError *error){
        if(callback) {
            callback(error);
        }
        WKLogError(@"同步联系人数据出错:%@",error);
    });
}


- (NSString *)title {
//    return nil;
    return LLang(@"同步联系人");
}


@end
