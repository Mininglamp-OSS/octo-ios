// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  LiMaoDataSourceTests.m
//  LiMaoDataSourceTests
//
//  Created by tangtaoit on 12/27/2019.
//  Copyright (c) 2019 tangtaoit. All rights reserved.
//

@import XCTest;
#import <WuKongDataSource/WKDataSourceModel.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - External Group (EP1) — WKGroupModel fromMap

// 群级：is_external_group = 1 / allow_external = 0 / space_id 同时存在时，字段应全部透传
- (void)test_groupModel_fromMap_allExternalFieldsPresent {
    NSDictionary *dict = @{
        @"group_no": @"gA",
        @"name": @"External Group A",
        @"is_external_group": @1,
        @"allow_external": @0,
        @"space_id": @"space_home_123",
    };
    WKGroupModel *m = (WKGroupModel*)[WKGroupModel fromMap:dict type:0];
    XCTAssertNotNil(m.isExternalGroup);
    XCTAssertEqual(m.isExternalGroup.integerValue, 1);
    XCTAssertNotNil(m.allowExternal);
    XCTAssertEqual(m.allowExternal.integerValue, 0);
    XCTAssertEqualObjects(m.spaceId, @"space_home_123");
}

// 群级：字段完全缺失时，NSNumber* 保持 nil，NSString* 保持 nil（允许增量更新路径保留旧值）
- (void)test_groupModel_fromMap_fieldsAbsent_nil {
    NSDictionary *dict = @{@"group_no": @"gB", @"name": @"Normal Group"};
    WKGroupModel *m = (WKGroupModel*)[WKGroupModel fromMap:dict type:0];
    XCTAssertNil(m.isExternalGroup);
    XCTAssertNil(m.allowExternal);
    XCTAssertNil(m.spaceId);
}

// 群级：NSNull 防御 — 后端下发 JSON null 不应崩溃，也不应误识别为 YES
- (void)test_groupModel_fromMap_nullGuards {
    NSDictionary *dict = @{
        @"group_no": @"gC",
        @"is_external_group": [NSNull null],
        @"allow_external": [NSNull null],
        @"space_id": [NSNull null],
    };
    WKGroupModel *m = (WKGroupModel*)[WKGroupModel fromMap:dict type:0];
    XCTAssertNil(m.isExternalGroup);
    XCTAssertNil(m.allowExternal);
    XCTAssertNil(m.spaceId);
}

// 群级：字符串数字也应能被识别 (某些 gateway 会把 1 转 "1")
- (void)test_groupModel_fromMap_stringDigitsAreAccepted {
    NSDictionary *dict = @{
        @"group_no": @"gD",
        @"is_external_group": @"1",
        @"allow_external": @"0",
        @"space_id": @"sp",
    };
    WKGroupModel *m = (WKGroupModel*)[WKGroupModel fromMap:dict type:0];
    XCTAssertNotNil(m.isExternalGroup);
    XCTAssertEqual(m.isExternalGroup.integerValue, 1);
    XCTAssertNotNil(m.allowExternal);
    XCTAssertEqual(m.allowExternal.integerValue, 0);
}

#pragma mark - External Group (EP1) — WKGroupMemberModel fromMap

// 成员级：5 个外部字段全部透传到 model
- (void)test_memberModel_fromMap_allExternalFieldsPresent {
    NSDictionary *dict = @{
        @"uid": @"u1",
        @"name": @"Alice",
        @"is_external": @1,
        @"source_space_id": @"sp_src",
        @"source_space_name": @"销售部",
        @"home_space_id": @"sp_home",
        @"home_space_name": @"研发部",
    };
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    XCTAssertTrue(m.isExternal);
    XCTAssertEqualObjects(m.sourceSpaceId, @"sp_src");
    XCTAssertEqualObjects(m.sourceSpaceName, @"销售部");
    XCTAssertEqualObjects(m.homeSpaceId, @"sp_home");
    XCTAssertEqualObjects(m.homeSpaceName, @"研发部");
}

// 成员级：NSNull 防御 — 后端下发 JSON null 不应崩溃，且不应写到 model
- (void)test_memberModel_fromMap_nullGuards {
    NSDictionary *dict = @{
        @"uid": @"u2",
        @"is_external": [NSNull null],
        @"source_space_id": [NSNull null],
        @"source_space_name": [NSNull null],
        @"home_space_id": [NSNull null],
        @"home_space_name": [NSNull null],
    };
    XCTAssertNoThrow([WKGroupMemberModel fromMap:dict type:0]);
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    XCTAssertFalse(m.isExternal);
    XCTAssertNil(m.sourceSpaceId);
    XCTAssertNil(m.sourceSpaceName);
    XCTAssertNil(m.homeSpaceId);
    XCTAssertNil(m.homeSpaceName);
}

// 成员级：普通成员（非外部）不应带任何外部字段
- (void)test_memberModel_fromMap_normalMember {
    NSDictionary *dict = @{@"uid": @"u3", @"name": @"Bob"};
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    XCTAssertFalse(m.isExternal);
    XCTAssertNil(m.sourceSpaceId);
    XCTAssertNil(m.sourceSpaceName);
    XCTAssertNil(m.homeSpaceId);
    XCTAssertNil(m.homeSpaceName);
}

#pragma mark - External Group (EP1) — WKGroupMemberModel toChannelMember

// toChannelMember: 外部成员字段必须透传到 channelMember.extra
- (void)test_memberModel_toChannelMember_externalMemberExtras {
    NSDictionary *dict = @{
        @"uid": @"u4",
        @"name": @"Carol",
        @"group_no": @"g1",
        @"is_external": @1,
        @"source_space_id": @"sp_src_carol",
        @"source_space_name": @"财务部",
        @"home_space_id": @"sp_home_carol",
        @"home_space_name": @"行政部",
    };
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    WKChannelMember *cm = [m toChannelMember];
    XCTAssertNotNil(cm);
    XCTAssertEqualObjects(cm.extra[@"is_external"], @1);
    XCTAssertEqualObjects(cm.extra[@"source_space_id"], @"sp_src_carol");
    XCTAssertEqualObjects(cm.extra[@"source_space_name"], @"财务部");
    XCTAssertEqualObjects(cm.extra[@"home_space_id"], @"sp_home_carol");
    XCTAssertEqualObjects(cm.extra[@"home_space_name"], @"行政部");
}

// toChannelMember: 普通成员不应污染 extra
- (void)test_memberModel_toChannelMember_normalMemberNoExtras {
    NSDictionary *dict = @{@"uid": @"u5", @"name": @"Dan", @"group_no": @"g1"};
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    WKChannelMember *cm = [m toChannelMember];
    XCTAssertNil(cm.extra[@"is_external"]);
    XCTAssertNil(cm.extra[@"source_space_id"]);
    XCTAssertNil(cm.extra[@"source_space_name"]);
    XCTAssertNil(cm.extra[@"home_space_id"]);
    XCTAssertNil(cm.extra[@"home_space_name"]);
}

// toChannelMember: home_space_* 即使是普通成员也可能存在（viewer-relative），应透传
- (void)test_memberModel_toChannelMember_homeSpaceWithoutExternal {
    NSDictionary *dict = @{
        @"uid": @"u6",
        @"name": @"Eva",
        @"group_no": @"g1",
        @"home_space_id": @"sp_me",
        @"home_space_name": @"我的空间",
    };
    WKGroupMemberModel *m = (WKGroupMemberModel*)[WKGroupMemberModel fromMap:dict type:0];
    WKChannelMember *cm = [m toChannelMember];
    XCTAssertNil(cm.extra[@"is_external"]);
    XCTAssertEqualObjects(cm.extra[@"home_space_id"], @"sp_me");
    XCTAssertEqualObjects(cm.extra[@"home_space_name"], @"我的空间");
}

@end

