//
//  WKSpaceGateVM.m
//  WuKongLogin
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceGateVM.h"

@implementation WKSpace
@end

@implementation WKSpaceCreateResp
@end

@implementation WKInviteResp
@end

@implementation WKSpaceGateVM

- (AnyPromise *)getMySpaces {
    return [[WKAPIClient sharedClient] GET:@"space/my" parameters:nil];
}

- (AnyPromise *)createSpace:(NSString *)name description:(NSString *)description {
    return [[WKAPIClient sharedClient] POST:@"space/create" parameters:@{@"name":name?:@"",@"description":description?:@""}];
}

- (AnyPromise *)joinSpace:(NSString *)inviteCode {
    return [[WKAPIClient sharedClient] POST:@"space/join" parameters:@{@"invite_code":inviteCode?:@""}];
}

- (AnyPromise *)createInvite:(NSString *)spaceId {
    return [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"space/%@/invite",spaceId] parameters:@{}];
}

+ (NSDictionary *)pickJoinedSpace:(NSArray *)spaces {
    if (![spaces isKindOfClass:[NSArray class]] || spaces.count == 0) return nil;

    // 优先尝试匹配「当前 uid 上次所处的 Space」（仅在 role>0 仍是成员时命中），
    // 否则回落到原有「首个成员 Space」语义。
    // WKLastSpaceIdByUid_<uid> 由 WKApp.m 的 WKPOINT_LOGIN_LOGOUT handler 在
    // 清 currentSpaceId 前快照写入；handleLoginData: 在 getMySpaces 之前已写好
    // loginInfo.uid，所以这里读 uid 是有效的。
    NSString *uid = [WKApp shared].loginInfo.uid;
    NSString *snapKey = uid.length > 0
        ? [NSString stringWithFormat:@"WKLastSpaceIdByUid_%@", uid]
        : nil;
    NSString *preferredId = snapKey
        ? [[NSUserDefaults standardUserDefaults] stringForKey:snapKey]
        : nil;
    WKLogDebug(@"[pickJoinedSpace] uid=%@ snapKey=%@ preferredId=%@ spaces.count=%zd",
               uid, snapKey, preferredId, spaces.count);

    NSDictionary *fallback = nil;
    for (id item in spaces) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *s = (NSDictionary *)item;
        NSInteger role = [s[@"role"] integerValue];
        NSString *spaceId = s[@"space_id"];
        if (role <= 0 || ![spaceId isKindOfClass:[NSString class]] || spaceId.length == 0) continue;
        if (preferredId.length > 0 && [spaceId isEqualToString:preferredId]) {
            WKLogDebug(@"[pickJoinedSpace] hit preferred spaceId=%@ name=%@", spaceId, s[@"name"]);
            return s;
        }
        if (!fallback) fallback = s;
    }
    if (fallback) {
        WKLogDebug(@"[pickJoinedSpace] fallback spaceId=%@ name=%@ (preferred=%@)",
                   fallback[@"space_id"], fallback[@"name"], preferredId);
    } else {
        WKLogDebug(@"[pickJoinedSpace] no member space found");
    }
    return fallback;
}

@end
