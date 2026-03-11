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
                        [weakSelf sync:callback];
                    } else {
                        // 如果对象已释放，调用callback避免dispatch_group永久等待
                        if(callback) {
                            callback(nil);
                        }
                    }
                });
                return; // 不调用callback，等待递归完成
            }
        }
        // 没有更多数据了，通知联系人更新并结束同步
        [[NSNotificationCenter defaultCenter] postNotificationName:WK_NOTIFY_CONTACTS_UPDATE object:nil];
        if(callback) {
            callback(nil);
        }

    }).catch(^(NSError *error){
        // 发生错误时也要调用callback，否则弹窗会一直显示
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
