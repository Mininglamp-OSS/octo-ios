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
    __strong typeof(weakSelf) strongSelf = weakSelf;
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
                // 下面代码还不能注释 需要修改完联系人选择等功能后才能注释掉
//                NSInteger count = [[WKDBContacts shared] queryCountWithUID:cont.uid];
//                if(count>0) {
//                    [[WKDBContacts shared] updateWithModel:cont];
//                }else {
//                    [[WKDBContacts shared] insert:cont];
//                }
            }
            long long version = [contacts.lastObject[@"version"] longLongValue];
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lld",version] forKey:cacheKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
             [[WKSDK shared].channelManager addOrUpdateChannelInfos:channelInfos];
            
            if(contacts.count>=limit) {
                [strongSelf sync:callback];
                return;
            }
        }
        // 通知联系人更新
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
