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

    // 优先尝试匹配「当前 uid 上次所处的 Space」(命中即返回，不看 role)；
    // 不命中再走 fallback：原有「首个 role>0 的成员 Space」语义。
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

    // preferred 命中：放宽 role 过滤。currentSpaceId 能落盘说明用户之前就在
    // 该空间活动过，必是成员；且后端给的 role 语义在不同空间不一致（明略默认
    // 空间 role=0 也是成员，与 WKSpaceEntity.h 注释对齐，与 aegis 历史
    // role==0=非成员的注释相反）。fallback 仍走 role>0 保守语义，避免 aegis
    // 切账号场景回归（详见类注释 + WKSpaceGateVM.h:54）。
    //
    // R8 fix (yujiawei P1-1): 加 fallbackAny 兜底, 治"明略首装 role=0 default 唯一
    // 成员空间"用户被 stranded 的回归: 该用户没 uid snapshot, preferred nil; fallback
    // 要求 role>0 也 nil → pickJoinedSpace 返 nil → checkSpaces 不 enterApp 也不 .catch
    // → 用户卡 SpaceGate 页只能登出。fallbackAny 在 fallback nil 时退到 role>=0 任一
    // 成员空间, 把这条路径救回来。aegis 多空间用户依然走 fallback role>0 优先, 单空间
    // role>0 用户行为不变。
    NSDictionary *fallback = nil;
    NSDictionary *fallbackAny = nil;
    NSDictionary *preferredHit = nil;
    for (id item in spaces) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *s = (NSDictionary *)item;
        NSInteger role = [s[@"role"] integerValue];
        NSString *spaceId = s[@"space_id"];
        WKLogDebug(@"[pickJoinedSpace] item space_id=%@ name=%@ role=%zd allKeys=%@",
                   spaceId, s[@"name"], role, [s.allKeys componentsJoinedByString:@","]);
        if (![spaceId isKindOfClass:[NSString class]] || spaceId.length == 0) continue;
        if (preferredId.length > 0 && !preferredHit && [spaceId isEqualToString:preferredId]) {
            preferredHit = s;
            continue;
        }
        if (role > 0 && !fallback) fallback = s;
        if (!fallbackAny) fallbackAny = s;
    }
    if (preferredHit) {
        WKLogDebug(@"[pickJoinedSpace] hit preferred spaceId=%@ name=%@ role=%@",
                   preferredHit[@"space_id"], preferredHit[@"name"], preferredHit[@"role"]);
        return preferredHit;
    }
    if (fallback) {
        WKLogDebug(@"[pickJoinedSpace] fallback spaceId=%@ name=%@ (preferred=%@)",
                   fallback[@"space_id"], fallback[@"name"], preferredId);
        return fallback;
    }
    if (fallbackAny) {
        WKLogDebug(@"[pickJoinedSpace] fallbackAny (role=0 only-member) spaceId=%@ name=%@",
                   fallbackAny[@"space_id"], fallbackAny[@"name"]);
        return fallbackAny;
    }
    WKLogDebug(@"[pickJoinedSpace] no member space found");
    return nil;
}

@end
