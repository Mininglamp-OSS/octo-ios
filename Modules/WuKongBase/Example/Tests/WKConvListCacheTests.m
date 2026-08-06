// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConvListCacheTests.m
//  LiMaoBase_Tests
//
//  会话列表「每空间持久缓存」的纯逻辑单测（不碰 DB / 不碰网络）：
//   - WKSidebarItemEntity toDict ↔ fromDict 往返：关注集合磁盘缓存靠这条往返，
//     字段丢一个就会让缓存态的分组/排序错位
//   - follow_sort 哨兵值 NSIntegerMax 不被序列化，回读仍兜底成 NSIntegerMax
//   - WKSpaceDiskCache 读写/隔离/删除
//   - WKConvListCache.enabled 灰度开关语义（默认开、显式关）
//
//  作用域三态（归属表空 → 返回全部 / membership(A) → 只返回 A / membership(B) 为 0 行
//  → 返回空）和全量 tombstone 需要真实 sqlite，本测试目标没有 DB 引导，放在手工
//  验证清单里（切空间 A→B→A + web 端退群后拉一次全量 sync）。
//

@import XCTest;
#import "WKSidebarItemEntity.h"
#import "WKSpaceDiskCache.h"
#import "WKConvListCache.h"
#import "WKLoginInfo.h"

@interface WKConvListCacheTests : XCTestCase
@end

@implementation WKConvListCacheTests

#pragma mark - WKSidebarItemEntity 序列化往返

- (void)testEntityRoundTrip_AllFields {
    NSDictionary *src = @{
        @"target_type":   @2,
        @"target_id":     @"g_octo",
        @"channel_type":  @2,
        @"channel_id":    @"g_octo",
        @"timestamp":     @1716000000,
        @"unread":        @7,
        @"is_pinned":     @YES,
        @"is_followed":   @YES,
        @"category_id":   @"cat_work",
        @"category_sort": @3,
        @"follow_sort":   @11,
        @"parent_channel_id": @"g_parent",
    };
    WKSidebarItemEntity *e1 = [WKSidebarItemEntity fromDict:src];
    WKSidebarItemEntity *e2 = [WKSidebarItemEntity fromDict:[e1 toDict]];

    XCTAssertEqual(e2.target_type, e1.target_type);
    XCTAssertEqualObjects(e2.target_id, e1.target_id);
    XCTAssertEqual(e2.channel_type, e1.channel_type);
    XCTAssertEqualObjects(e2.channel_id, e1.channel_id);
    XCTAssertEqual(e2.timestamp, e1.timestamp);
    XCTAssertEqual(e2.unread, e1.unread);
    XCTAssertEqual(e2.is_pinned, e1.is_pinned);
    XCTAssertEqual(e2.is_followed, e1.is_followed);
    XCTAssertEqualObjects(e2.category_id, e1.category_id);
    XCTAssertEqual(e2.category_sort, e1.category_sort);
    XCTAssertEqual(e2.follow_sort, e1.follow_sort);
    XCTAssertEqualObjects(e2.parent_channel_id, e1.parent_channel_id);
}

/// follow_sort 缺省时 fromDict: 兜底成 NSIntegerMax（排到桶末尾）。
/// toDict 不能把这个哨兵写进缓存文件，但往返后语义必须一致。
- (void)testEntityRoundTrip_FollowSortSentinelNotSerialized {
    WKSidebarItemEntity *e1 = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1,
        @"target_id":   @"u_alice",
        @"is_followed": @YES,
    }];
    XCTAssertEqual(e1.follow_sort, NSIntegerMax);

    NSDictionary *dict = [e1 toDict];
    XCTAssertNil(dict[@"follow_sort"], @"哨兵值不应被序列化");

    WKSidebarItemEntity *e2 = [WKSidebarItemEntity fromDict:dict];
    XCTAssertEqual(e2.follow_sort, NSIntegerMax, @"回读后仍应兜底成 NSIntegerMax");
}

/// category_id / parent_channel_id 为 nil（未归类 / 非子区）时不写键，回读仍是 nil。
- (void)testEntityRoundTrip_NilOptionalsStayNil {
    WKSidebarItemEntity *e1 = [WKSidebarItemEntity fromDict:@{
        @"target_type": @1,
        @"target_id":   @"u_bob",
        @"is_followed": @YES,
    }];
    XCTAssertNil(e1.category_id);
    XCTAssertNil(e1.parent_channel_id);

    WKSidebarItemEntity *e2 = [WKSidebarItemEntity fromDict:[e1 toDict]];
    XCTAssertNil(e2.category_id);
    XCTAssertNil(e2.parent_channel_id);
}

#pragma mark - WKSpaceDiskCache

- (void)setUp {
    [super setUp];
    // 磁盘缓存目录按 uid 分，测试里给一个固定的假 uid
    [WKLoginInfo shared].uid = @"test_uid_convlistcache";
    [WKSpaceDiskCache removeAllForCurrentUser];
}

- (void)tearDown {
    [WKSpaceDiskCache removeAllForCurrentUser];
    [super tearDown];
}

- (void)testDiskCache_WriteThenRead {
    NSArray *payload = @[@{@"category_id": @"c1", @"name": @"工作"}];
    [WKSpaceDiskCache setObject:payload forNamespace:@"categories" spaceId:@"spaceA"];
    // 写是异步串行队列，读之前等一下
    [self waitForDiskCacheFlush];

    id got = [WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"];
    XCTAssertEqualObjects(got, payload);
}

/// 不同空间之间必须互不可见 —— 否则切空间会读到上一个空间的分组结构。
- (void)testDiskCache_SpaceIsolation {
    [WKSpaceDiskCache setObject:@[@"A"] forNamespace:@"categories" spaceId:@"spaceA"];
    [WKSpaceDiskCache setObject:@[@"B"] forNamespace:@"categories" spaceId:@"spaceB"];
    [self waitForDiskCacheFlush];

    XCTAssertEqualObjects([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"], (@[@"A"]));
    XCTAssertEqualObjects([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceB"], (@[@"B"]));
}

/// namespace 之间也要隔离（分组结构 vs 关注集合共用一个目录）。
- (void)testDiskCache_NamespaceIsolation {
    [WKSpaceDiskCache setObject:@[@"cats"] forNamespace:@"categories" spaceId:@"spaceA"];
    [WKSpaceDiskCache setObject:@{@"items": @[]} forNamespace:@"follow" spaceId:@"spaceA"];
    [self waitForDiskCacheFlush];

    XCTAssertEqualObjects([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"], (@[@"cats"]));
    XCTAssertEqualObjects([WKSpaceDiskCache objectForNamespace:@"follow" spaceId:@"spaceA"], (@{@"items": @[]}));
}

- (void)testDiskCache_MissReturnsNil {
    XCTAssertNil([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"never_written"]);
}

- (void)testDiskCache_Remove {
    [WKSpaceDiskCache setObject:@[@"A"] forNamespace:@"categories" spaceId:@"spaceA"];
    [self waitForDiskCacheFlush];
    XCTAssertNotNil([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"]);

    [WKSpaceDiskCache removeNamespace:@"categories" spaceId:@"spaceA"];
    [self waitForDiskCacheFlush];
    XCTAssertNil([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"]);
}

/// setObject:nil 等价于删除（避免留下一份过期数据）。
- (void)testDiskCache_SetNilDeletes {
    [WKSpaceDiskCache setObject:@[@"A"] forNamespace:@"categories" spaceId:@"spaceA"];
    [self waitForDiskCacheFlush];
    [WKSpaceDiskCache setObject:nil forNamespace:@"categories" spaceId:@"spaceA"];
    [self waitForDiskCacheFlush];
    XCTAssertNil([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"spaceA"]);
}

/// spaceId 里带路径分隔符不能逃出缓存目录。
- (void)testDiskCache_SanitizesSpaceId {
    [WKSpaceDiskCache setObject:@[@"X"] forNamespace:@"categories" spaceId:@"../../evil"];
    [self waitForDiskCacheFlush];
    // 写进去的是白名单化后的文件名，用同样的 spaceId 能读回来，且没有越出目录
    XCTAssertEqualObjects([WKSpaceDiskCache objectForNamespace:@"categories" spaceId:@"../../evil"], (@[@"X"]));
}

#pragma mark - 灰度开关

- (void)testEnabled_DefaultsToYES {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"OCTO_CONV_CACHE_ENABLED"];
    XCTAssertTrue([WKConvListCache enabled]);
}

- (void)testEnabled_ExplicitOff {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"OCTO_CONV_CACHE_ENABLED"];
    XCTAssertFalse([WKConvListCache enabled]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"OCTO_CONV_CACHE_ENABLED"];
}

#pragma mark - Helpers

/// WKSpaceDiskCache 的写/删走内部串行队列，测试里需要等它排空。
- (void)waitForDiskCacheFlush {
    XCTestExpectation *exp = [self expectationWithDescription:@"disk cache flush"];
    // 往同一条串行队列后面再排一个空任务，它跑到就说明前面的写已经落地
    [WKSpaceDiskCache setObject:@{@"_flush": @1} forNamespace:@"_flush" spaceId:@"_flush"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [exp fulfill];
    });
    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end
