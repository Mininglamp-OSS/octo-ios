//
//  WKSpaceConvSyncCache.h
//  WuKongBase
//
//  In-memory cache for the `space_id` / `my_source_space_id` resolved fields
//  delivered by octo-server PR#154 on every conversation/sync response.
//
//  Why memory (not DB stub) — PR #136 round-2 review fix:
//  - A placeholder `WKChannelInfo` row blocks the lazy-load of real channel
//    info: callers test `getChannelInfo != nil` and stop dispatching
//    `fetchChannelInfo`, so group name / avatar would never load.
//  - A placeholder `WKChannelMember` row defaults to status=inactive, and
//    `WKChannelMemberDB.get:memberUID:` filters on `status=1`, so the
//    `source_space_id` we just wrote is unreadable. Worse, upserting on top
//    of a real inactive row could flip a legitimately-left member back to
//    active.
//
//  Resolution order in `WKSpaceFilter` becomes:
//    1. DB:    channelInfo.extra[@"space_id"] / member.extra[@"source_space_id"]
//    2. cache: this class (filled by conv sync prefill)
//  As soon as the real channelInfo / member sync lands, DB wins transparently.
//  Cleared on Space switch and logout.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceConvSyncCache : NSObject

+ (instancetype)shared;

#pragma mark - space_id (channelInfo.extra surrogate)

- (void)setSpaceId:(NSString *)spaceId
      forChannelId:(NSString *)channelId
       channelType:(uint8_t)channelType;

- (nullable NSString *)spaceIdForChannelId:(NSString *)channelId
                               channelType:(uint8_t)channelType;

// PR #136 round-5 review 修复（Jerry-Xin，对齐 Android Round-3）：
// 当后续 conv sync 对同一 channel 不再携带 space_id 时，必须能清掉旧缓存值，
// 否则 WKSpaceFilter 永远按过期数据决策。仅 set/clearAll 不够。
- (void)removeSpaceIdForChannelId:(NSString *)channelId
                      channelType:(uint8_t)channelType;

#pragma mark - my source_space_id (channelMember.extra surrogate)

- (void)setMySourceSpaceId:(NSString *)sourceSpaceId
              forChannelId:(NSString *)channelId
               channelType:(uint8_t)channelType;

- (nullable NSString *)mySourceSpaceIdForChannelId:(NSString *)channelId
                                       channelType:(uint8_t)channelType;

// PR #136 round-5 review 修复（同上）：source_space_id 也需要 per-key 清理。
- (void)removeMySourceSpaceIdForChannelId:(NSString *)channelId
                              channelType:(uint8_t)channelType;

#pragma mark - lifecycle

- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
