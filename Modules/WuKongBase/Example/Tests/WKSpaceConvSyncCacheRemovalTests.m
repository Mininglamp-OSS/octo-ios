// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceConvSyncCacheRemovalTests.m
//  WuKongBase Tests
//
//  / —
//    PR #136 round-5 review 修复（Jerry-Xin，对齐 Android Round-3）：
//    WKSpaceConvSyncCache 此前只有 set / clearAll，没有 per-key remove。
//    后续 conv sync 不再带 space_id / my_source_space_id 时，旧缓存值会
//    永久保留，WKSpaceFilter 按过期数据决策（外部群被误判为内部、内部群
//    被误判为外部等）。
//
//  covers:
//    1. removeSpaceIdForChannelId:channelType: 清掉指定 key 后读回 nil
//    2. removeMySourceSpaceIdForChannelId:channelType: 同上
//    3. remove 只影响命中 key，不误清其它 channel
//    4. remove 不命中 key（从未 set）安全无副作用
//    5. (channelId, channelType) 复合键：相同 id 不同 type 互不影响
//    6. 空 / nil channelId 守卫
//

@import XCTest;
#import "WKSpaceConvSyncCache.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKSpaceConvSyncCacheRemovalTests : XCTestCase
@end

@implementation WKSpaceConvSyncCacheRemovalTests

- (void)setUp {
    [super setUp];
    [[WKSpaceConvSyncCache shared] clearAll];
}

- (void)tearDown {
    [[WKSpaceConvSyncCache shared] clearAll];
    [super tearDown];
}

#pragma mark - remove space_id

- (void)test_removeSpaceId_dropsCachedValue {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setSpaceId:@"spaceA" forChannelId:@"g1" channelType:WK_GROUP];
    XCTAssertEqualObjects([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP], @"spaceA");

    [cache removeSpaceIdForChannelId:@"g1" channelType:WK_GROUP];
    XCTAssertNil([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP],
                 @"remove 后 WKSpaceFilter 不应再读到旧值");
}

- (void)test_removeSpaceId_doesNotAffectOtherChannels {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setSpaceId:@"spaceA" forChannelId:@"g1" channelType:WK_GROUP];
    [cache setSpaceId:@"spaceB" forChannelId:@"g2" channelType:WK_GROUP];

    [cache removeSpaceIdForChannelId:@"g1" channelType:WK_GROUP];

    XCTAssertNil([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP]);
    XCTAssertEqualObjects([cache spaceIdForChannelId:@"g2" channelType:WK_GROUP], @"spaceB",
                          @"remove 只影响命中 key，不能误清其它 channel");
}

- (void)test_removeSpaceId_onMissingKey_isNoOp {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    // 从未 set，直接 remove 不应崩 / 不应影响其它状态
    XCTAssertNoThrow([cache removeSpaceIdForChannelId:@"never_set" channelType:WK_GROUP]);
    XCTAssertNil([cache spaceIdForChannelId:@"never_set" channelType:WK_GROUP]);
}

- (void)test_removeSpaceId_isPerChannelType {
    // (channelId, channelType) 是复合键 —— 同 id 不同 type 必须独立。
    // 例如裸 UID 既可能是 WK_PERSON 私聊，也可能在 GROUP 列表里出现。
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setSpaceId:@"spaceP" forChannelId:@"u1" channelType:WK_PERSON];
    [cache setSpaceId:@"spaceG" forChannelId:@"u1" channelType:WK_GROUP];

    [cache removeSpaceIdForChannelId:@"u1" channelType:WK_PERSON];

    XCTAssertNil([cache spaceIdForChannelId:@"u1" channelType:WK_PERSON]);
    XCTAssertEqualObjects([cache spaceIdForChannelId:@"u1" channelType:WK_GROUP], @"spaceG");
}

- (void)test_removeSpaceId_emptyChannelId_isSafeNoOp {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setSpaceId:@"spaceA" forChannelId:@"g1" channelType:WK_GROUP];

    XCTAssertNoThrow([cache removeSpaceIdForChannelId:@"" channelType:WK_GROUP]);
    XCTAssertEqualObjects([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP], @"spaceA",
                          @"空 channelId 不能作为通配清掉真实条目");
}

#pragma mark - remove mySourceSpaceId

- (void)test_removeMySourceSpaceId_dropsCachedValue {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setMySourceSpaceId:@"srcA" forChannelId:@"g1" channelType:WK_GROUP];
    XCTAssertEqualObjects([cache mySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP], @"srcA");

    [cache removeMySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP];
    XCTAssertNil([cache mySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP]);
}

- (void)test_removeMySourceSpaceId_doesNotAffectSpaceIdMap {
    // space_id / source_space_id 是两张独立 map，互不串。
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    [cache setSpaceId:@"spaceA" forChannelId:@"g1" channelType:WK_GROUP];
    [cache setMySourceSpaceId:@"srcA" forChannelId:@"g1" channelType:WK_GROUP];

    [cache removeMySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP];

    XCTAssertNil([cache mySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP]);
    XCTAssertEqualObjects([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP], @"spaceA",
                          @"清 source map 不应连带清 space map");
}

- (void)test_removeMySourceSpaceId_onMissingKey_isNoOp {
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];
    XCTAssertNoThrow([cache removeMySourceSpaceIdForChannelId:@"never_set" channelType:WK_GROUP]);
    XCTAssertNil([cache mySourceSpaceIdForChannelId:@"never_set" channelType:WK_GROUP]);
}

#pragma mark - stale value scenario end-to-end

- (void)test_staleValueRemoval_resetThenRead {
    // 端到端：第一轮 conv sync 带 space_id → cache 命中；第二轮不再带 →
    // prefill 调 remove；WKSpaceFilter 读不到旧值，回落 DB / nil。
    WKSpaceConvSyncCache *cache = [WKSpaceConvSyncCache shared];

    // Round 1：服务端下发 space_id
    [cache setSpaceId:@"spaceA" forChannelId:@"g1" channelType:WK_GROUP];
    [cache setMySourceSpaceId:@"srcA" forChannelId:@"g1" channelType:WK_GROUP];

    // Round 2：服务端不再下发（spaceId / mySourceSpaceId 都为空）
    //          —— prefillSpaceFieldsFromSyncModels: 现在会主动 remove
    [cache removeSpaceIdForChannelId:@"g1" channelType:WK_GROUP];
    [cache removeMySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP];

    XCTAssertNil([cache spaceIdForChannelId:@"g1" channelType:WK_GROUP]);
    XCTAssertNil([cache mySourceSpaceIdForChannelId:@"g1" channelType:WK_GROUP]);
}

@end
