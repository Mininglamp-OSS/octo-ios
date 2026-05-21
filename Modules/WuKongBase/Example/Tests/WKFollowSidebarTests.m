// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKFollowSidebarTests.m
//  LiMaoBase_Tests
//
//  P0 数据层单测：
//   - WKSidebarItemEntity 反序列化（3 种 target_type、缺省 follow_sort 兜底）
//   - WKFollowedKeysStore 桶内按 follow_sort 重排 + 空桶/默认桶处理
//   - WKFollowService.isVersionConflictError: NSError 字符串识别
//

@import XCTest;
#import "WKSidebarItemEntity.h"
#import "WKSidebarService.h"
#import "WKFollowedKeysStore.h"
#import "WKFollowService.h"

@interface WKFollowSidebarTests : XCTestCase
@end

@implementation WKFollowSidebarTests

#pragma mark - WKSidebarItemEntity 反序列化

- (void)testEntity_DM_AllFields {
    NSDictionary *dict = @{
        @"target_type": @1,
        @"target_id":   @"u_alice",
        @"channel_type": @1,
        @"channel_id":   @"u_alice",
        @"timestamp":    @1716000000,
        @"unread":       @3,
        @"is_pinned":    @NO,
        @"is_followed":  @YES,
        @"category_id":  @"cat_work",
        @"category_sort": @2,
        @"follow_sort":  @10,
    };
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:dict];
    XCTAssertEqual(e.target_type, WKFollowTargetTypeDM);
    XCTAssertEqualObjects(e.target_id, @"u_alice");
    XCTAssertEqual(e.timestamp, 1716000000LL);
    XCTAssertEqual(e.unread, 3);
    XCTAssertFalse(e.is_pinned);
    XCTAssertTrue(e.is_followed);
    XCTAssertEqualObjects(e.category_id, @"cat_work");
    XCTAssertEqual(e.follow_sort, 10);
    XCTAssertNil(e.parent_channel_id);
    XCTAssertEqualObjects([e followKey], @"1::u_alice");
}

- (void)testEntity_Channel_FollowKey {
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:@{
        @"target_type": @2, @"target_id": @"g_team", @"channel_id": @"g_team",
    }];
    XCTAssertEqual(e.target_type, WKFollowTargetTypeChannel);
    XCTAssertEqualObjects([e followKey], @"2::g_team");
}

- (void)testEntity_Thread_HasParent {
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:@{
        @"target_type":       @5,
        @"target_id":         @"thread_x",
        @"channel_id":        @"thread_x",
        @"parent_channel_id": @"g_team",
    }];
    XCTAssertEqual(e.target_type, WKFollowTargetTypeThread);
    XCTAssertEqualObjects(e.parent_channel_id, @"g_team");
    XCTAssertEqualObjects([e followKey], @"5::thread_x");
}

- (void)testEntity_MissingFollowSort_FallsBackToIntegerMax {
    // 后端返回未带 follow_sort 时必须用 NSIntegerMax 兜底，否则桶内排序会把未排过的项排到最前
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1, @"target_id": @"u_x", @"channel_id": @"u_x",
    }];
    XCTAssertEqual(e.follow_sort, NSIntegerMax);
}

- (void)testEntity_NullFollowSort_FallsBackToIntegerMax {
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1, @"target_id": @"u_x", @"channel_id": @"u_x",
        @"follow_sort": [NSNull null],
    }];
    XCTAssertEqual(e.follow_sort, NSIntegerMax);
}

- (void)testEntity_NullCategoryId_BecomesNil {
    WKSidebarItemEntity *e = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1, @"target_id": @"u_x", @"channel_id": @"u_x",
        @"category_id": [NSNull null],
    }];
    XCTAssertNil(e.category_id);
}

#pragma mark - WKSidebarSyncResponse

- (void)testSyncResponse_ParsesItemsAndVersions {
    NSDictionary *dict = @{
        @"version":        @123,
        @"follow_version": @7,
        @"items": @[
            @{ @"target_type": @1, @"target_id": @"u1", @"channel_id": @"u1" },
            @{ @"target_type": @2, @"target_id": @"g1", @"channel_id": @"g1" },
        ],
    };
    WKSidebarSyncResponse *r = [WKSidebarSyncResponse fromDict:dict];
    XCTAssertEqual(r.version, 123LL);
    XCTAssertEqual(r.follow_version, 7);
    XCTAssertEqual(r.items.count, 2u);
}

- (void)testSyncResponse_EmptyDict_ProducesEmptyItems {
    WKSidebarSyncResponse *r = [WKSidebarSyncResponse fromDict:@{}];
    XCTAssertNotNil(r.items);
    XCTAssertEqual(r.items.count, 0u);
    XCTAssertEqual(r.version, 0LL);
    XCTAssertEqual(r.follow_version, 0);
}

#pragma mark - WKFollowedKeysStore: 桶内排序 & 默认桶

- (WKSidebarItemEntity *)itemDM:(NSString *)uid category:(nullable NSString *)cat followSort:(NSInteger)fs timestamp:(int64_t)ts {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:@{
        @"target_type": @1,
        @"target_id":   uid,
        @"channel_id":  uid,
        @"follow_sort": @(fs),
        @"timestamp":   @(ts),
    }];
    if (cat) d[@"category_id"] = cat;
    return [WKSidebarItemEntity fromDict:d];
}

- (void)testStore_BucketSort_AscendingByFollowSort {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    NSArray *items = @[
        [self itemDM:@"u_c" category:@"cat_a" followSort:30 timestamp:1],
        [self itemDM:@"u_a" category:@"cat_a" followSort:10 timestamp:1],
        [self itemDM:@"u_b" category:@"cat_a" followSort:20 timestamp:1],
    ];
    [store applyItems:items followVersion:5];

    NSArray<WKSidebarItemEntity *> *bucket = store.itemsByCategory[@"cat_a"];
    XCTAssertEqual(bucket.count, 3u);
    XCTAssertEqualObjects(bucket[0].target_id, @"u_a");
    XCTAssertEqualObjects(bucket[1].target_id, @"u_b");
    XCTAssertEqualObjects(bucket[2].target_id, @"u_c");
    XCTAssertEqual(store.followVersion, 5);
}

- (void)testStore_MissingFollowSort_SortsToTail {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    // 一项带 follow_sort=5，另一项不带（entity 内兜底 NSIntegerMax）→ 后者必须排在后面
    WKSidebarItemEntity *withSort = [self itemDM:@"u_first" category:@"cat" followSort:5 timestamp:1];
    WKSidebarItemEntity *noSort = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1, @"target_id": @"u_last", @"channel_id": @"u_last",
        @"category_id": @"cat",
    }];
    [store applyItems:@[noSort, withSort] followVersion:0];

    NSArray<WKSidebarItemEntity *> *bucket = store.itemsByCategory[@"cat"];
    XCTAssertEqualObjects(bucket[0].target_id, @"u_first");
    XCTAssertEqualObjects(bucket[1].target_id, @"u_last");
}

- (void)testStore_EqualFollowSort_TiebreaksByTimestampDesc {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    NSArray *items = @[
        [self itemDM:@"u_old" category:@"cat" followSort:10 timestamp:100],
        [self itemDM:@"u_new" category:@"cat" followSort:10 timestamp:200],
    ];
    [store applyItems:items followVersion:0];
    NSArray<WKSidebarItemEntity *> *bucket = store.itemsByCategory[@"cat"];
    XCTAssertEqualObjects(bucket[0].target_id, @"u_new");
    XCTAssertEqualObjects(bucket[1].target_id, @"u_old");
}

- (void)testStore_NullCategory_GoesToEmptyStringBucket {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    WKSidebarItemEntity *item = [self itemDM:@"u_x" category:nil followSort:1 timestamp:1];
    [store applyItems:@[item] followVersion:1];
    XCTAssertEqual(store.itemsByCategory[@""].count, 1u);
}

- (void)testStore_FollowedKeysAndGroupNos {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    NSArray *items = @[
        [WKSidebarItemEntity fromDict:@{ @"target_type": @1, @"target_id": @"u1", @"channel_id": @"u1" }],
        [WKSidebarItemEntity fromDict:@{ @"target_type": @2, @"target_id": @"g1", @"channel_id": @"g1" }],
        [WKSidebarItemEntity fromDict:@{ @"target_type": @5, @"target_id": @"t1", @"channel_id": @"t1", @"parent_channel_id": @"g1" }],
    ];
    [store applyItems:items followVersion:0];

    XCTAssertTrue([store isFollowedWithType:WKFollowTargetTypeDM targetId:@"u1"]);
    XCTAssertTrue([store isFollowedWithType:WKFollowTargetTypeChannel targetId:@"g1"]);
    XCTAssertTrue([store isFollowedWithType:WKFollowTargetTypeThread targetId:@"t1"]);
    XCTAssertFalse([store isFollowedWithType:WKFollowTargetTypeDM targetId:@"u_other"]);

    XCTAssertEqual(store.followedGroupNos.count, 1u);
    XCTAssertTrue([store.followedGroupNos containsObject:@"g1"]);
}

- (void)testStore_BumpVersion {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    [store applyItems:@[] followVersion:42];
    XCTAssertEqual(store.followVersion, 42);
    [store bumpVersion];
    XCTAssertEqual(store.followVersion, 43);
}

- (void)testStore_ApplyEmpty_NotifiesObservers {
    WKFollowedKeysStore *store = [[WKFollowedKeysStore alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"didUpdate"];
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kWKFollowedKeysStoreDidUpdateNotification
                                                                    object:store
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        [exp fulfill];
    }];
    [store applyItems:@[] followVersion:1];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

#pragma mark - WKFollowService 错误识别

- (void)testIsVersionConflictError_NilError_IsNo {
    XCTAssertFalse([WKFollowService isVersionConflictError:nil]);
}

- (void)testIsVersionConflictError_MsgInDomain {
    // WKApp errorHandler 把 400 响应的 msg 放到 NSError.domain
    NSError *err = [NSError errorWithDomain:@"version conflict" code:400 userInfo:@{}];
    XCTAssertTrue([WKFollowService isVersionConflictError:err]);
}

- (void)testIsVersionConflictError_MsgCaseInsensitive {
    NSError *err = [NSError errorWithDomain:@"Version Conflict" code:400 userInfo:@{}];
    XCTAssertTrue([WKFollowService isVersionConflictError:err]);
}

- (void)testIsVersionConflictError_MsgInUserInfo {
    NSError *err = [NSError errorWithDomain:@"some other domain" code:400 userInfo:@{ @"msg": @"version conflict" }];
    XCTAssertTrue([WKFollowService isVersionConflictError:err]);
}

- (void)testIsVersionConflictError_UnrelatedError_IsNo {
    NSError *err = [NSError errorWithDomain:@"network unreachable" code:-1009 userInfo:@{}];
    XCTAssertFalse([WKFollowService isVersionConflictError:err]);
}

#pragma mark - WKFollowSortItem 序列化

- (void)testSortItem_ToDict {
    WKFollowSortItem *item = [[WKFollowSortItem alloc] init];
    item.target_type = WKFollowTargetTypeChannel;
    item.target_id = @"g_team";
    item.sort = 3;
    NSDictionary *dict = [item toDict];
    XCTAssertEqualObjects(dict[@"target_type"], @2);
    XCTAssertEqualObjects(dict[@"target_id"], @"g_team");
    XCTAssertEqualObjects(dict[@"sort"], @3);
}

@end
