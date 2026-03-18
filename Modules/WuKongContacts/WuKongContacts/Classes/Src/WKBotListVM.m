//
//  WKBotListVM.m
//  WuKongContacts
//

#import "WKBotListVM.h"

@implementation WKBotListVM

- (AnyPromise *)requestBots {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId && spaceId.length > 0) {
        // Space 模式：从 space 成员中过滤 robot
        NSString *path = [NSString stringWithFormat:@"space/%@/members", spaceId];
        return [[WKAPIClient sharedClient] GET:path parameters:@{@"page":@"1", @"limit":@"10000"}].then(^(NSArray<NSDictionary*>* members) {
            NSMutableArray *bots = [NSMutableArray array];
            for (NSDictionary *m in members) {
                if ([m[@"robot"] integerValue] == 1) {
                    WKBotResp *resp = [WKBotResp new];
                    resp.uid = m[@"uid"] ?: @"";
                    resp.name = m[@"name"] ?: @"";
                    resp.desc = @"";
                    [bots addObject:resp];
                }
            }
            return bots;
        });
    }
    // 非 Space 模式：使用原接口
    return [[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:nil model:WKBotResp.class];
}

@end

@implementation WKBotResp

+ (WKBotResp *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKBotResp *resp = [WKBotResp new];
    resp.uid = dictory[@"uid"];
    resp.name = dictory[@"name"];
    resp.desc = dictory[@"description"] ?: @"";
    return resp;
}

@end
