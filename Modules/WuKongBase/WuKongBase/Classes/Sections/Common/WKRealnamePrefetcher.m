// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRealnamePrefetcher.m
//  WuKongBase
//

#import "WKRealnamePrefetcher.h"
#import "WKAPIClient.h"
#import "WKApp.h"
#import "WKLoginInfo.h"
#import <PromiseKit/PromiseKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

NSString *const WKRealnameVerifiedUpdatedNotification = @"WKRealnameVerifiedUpdated";

@implementation WKRealnamePrefetcher

// 会话级 uid 去重。线程不安全，仅在主线程调用（cell refresh 路径都在主线程）。
static NSMutableSet<NSString *> *_kFetchedUidSet = nil;

+ (NSMutableSet<NSString *> *)fetchedSet {
    if(!_kFetchedUidSet) {
        _kFetchedUidSet = [NSMutableSet new];
    }
    return _kFetchedUidSet;
}

+ (void)ensureFetched:(NSString *)uid {
    if(uid.length == 0) return;
    NSString *selfUid = [WKApp shared].loginInfo.uid;
    if(selfUid.length > 0 && [uid isEqualToString:selfUid]) return;

    NSMutableSet *seen = [self fetchedSet];
    if([seen containsObject:uid]) return;

    // 已经有显式 @YES：person 缓存被 SDK 推 / 上次 loadPersonChannelInfo 写过，
    // 不必重复打 /users/<uid>。@NO / nil 才需要拉。
    WKChannel *personChannel = [WKChannel personWithChannelID:uid];
    WKChannelInfo *cached = [[WKSDK shared].channelManager getChannelInfo:personChannel];
    id existing = cached.extra[@"realname_verified"];
    if([existing isKindOfClass:[NSNumber class]] && [(NSNumber *)existing boolValue]) {
        [seen addObject:uid];
        return;
    }

    [seen addObject:uid];

    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"users/%@", uid]
                         parameters:@{@"group_no":@""}
                              model:nil].then(^(id resp){
        if(![resp isKindOfClass:[NSDictionary class]]) return;
        NSDictionary *data = (NSDictionary *)resp;

        WKChannelInfo *cachedNow = [[WKSDK shared].channelManager getChannelInfo:personChannel];

        // 关键：必须传一个「新引用 + 新 extra dict」给 addOrUpdateChannelInfo，
        // 否则 SDK 内部 diff 比 oldInfo == newInfo（指针相等）会跳过
        // channelInfoUpdate delegate —— 各页面收不到刷新事件，徽章必须重新进
        // 页面才显示。WKChannelInfo 实现了 NSCopying，[cached copy] 给我们
        // 一份全字段一致的新实例。
        WKChannelInfo *fresh;
        if(cachedNow) {
            fresh = [cachedNow copy];
            // copy 出来的 extra 和原引用可能仍是同一 dict，再 mutableCopy 一遍最稳。
            fresh.extra = cachedNow.extra ? [cachedNow.extra mutableCopy] : [NSMutableDictionary new];
            // bump version：SDK 可能用 version 做 freshness 判定，不 bump 时旧 version
            // 同样可能让它认为「不是更新的数据」。
            fresh.version = cachedNow.version + 1;
        } else {
            fresh = [WKChannelInfo new];
            fresh.channel = personChannel;
            fresh.extra = [NSMutableDictionary new];
        }

        BOOL verified = [[data objectForKey:@"realname_verified"] boolValue];
        fresh.extra[@"realname_verified"] = @(verified);

        id atVal = [data objectForKey:@"realname_verified_at"];
        if(atVal && atVal != [NSNull null]) {
            NSTimeInterval ts = [atVal doubleValue];
            if(ts > 0) {
                fresh.extra[@"realname_verified_at"] = @(ts);
            }
        }

        [[WKSDK shared].channelManager addOrUpdateChannelInfo:fresh];

        // 兜底：发一个全局通知，无法监听 SDK delegate 的视图（比如群设置宫格、
        // 已经渲染好的 cell view）可以直接 reload 自己关心的 uid。
        [[NSNotificationCenter defaultCenter] postNotificationName:WKRealnameVerifiedUpdatedNotification
                                                            object:nil
                                                          userInfo:@{@"uid": uid, @"verified": @(verified)}];
    }).catch(^(NSError *err){
        // 失败容忍：从去重集合里移掉，下次还能再试。
        [seen removeObject:uid];
    });
}

@end
