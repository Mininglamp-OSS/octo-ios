//
//  LiMaoBaseTests.m
//  LiMaoBaseTests
//
//  Created by tangtaoit on 11/30/2019.
//  Copyright (c) 2019 tangtaoit. All rights reserved.
//

@import XCTest;
#import <WuKongBase/WKChannelUtil.h>
#import <WuKongBase/WKMessageUtil.h>
#import <WuKongBase/WKMessageModel.h>
#import <WuKongBase/WKMergeForwardContent.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark - WKChannelUtil.toChannelInfo2 — External Group Phase 1 群级字段透传 (YUJ-92 EP1)

- (void)test_channelUtil_toChannelInfo2_allExternalFieldsWritten {
    NSDictionary *dict = @{
        @"channel": @{@"channel_id": @"g1", @"channel_type": @2},
        @"name": @"External Group",
        @"is_external_group": @1,
        @"allow_external": @0,
        @"space_id": @"sp_abc",
    };
    WKChannelInfo *ci = [WKChannelUtil toChannelInfo2:dict];
    XCTAssertNotNil(ci);
    XCTAssertEqualObjects(ci.extra[@"is_external_group"], @1);
    XCTAssertEqualObjects(ci.extra[@"allow_external"], @0);
    XCTAssertEqualObjects(ci.extra[@"space_id"], @"sp_abc");
}

- (void)test_channelUtil_toChannelInfo2_nullGuards {
    NSDictionary *dict = @{
        @"channel": @{@"channel_id": @"g2", @"channel_type": @2},
        @"is_external_group": [NSNull null],
        @"allow_external": [NSNull null],
        @"space_id": [NSNull null],
    };
    XCTAssertNoThrow([WKChannelUtil toChannelInfo2:dict]);
    WKChannelInfo *ci = [WKChannelUtil toChannelInfo2:dict];
    XCTAssertNil(ci.extra[@"is_external_group"]);
    XCTAssertNil(ci.extra[@"allow_external"]);
    XCTAssertNil(ci.extra[@"space_id"]);
}

- (void)test_channelUtil_toChannelInfo2_absentFieldsAreUntouched {
    NSDictionary *dict = @{
        @"channel": @{@"channel_id": @"g3", @"channel_type": @2},
        @"name": @"Normal Group",
    };
    WKChannelInfo *ci = [WKChannelUtil toChannelInfo2:dict];
    XCTAssertNil(ci.extra[@"is_external_group"]);
    XCTAssertNil(ci.extra[@"allow_external"]);
    XCTAssertNil(ci.extra[@"space_id"]);
}

- (void)test_channelUtil_toChannelInfo2_emptySpaceIdIgnored {
    NSDictionary *dict = @{
        @"channel": @{@"channel_id": @"g4", @"channel_type": @2},
        @"space_id": @"",
    };
    WKChannelInfo *ci = [WKChannelUtil toChannelInfo2:dict];
    XCTAssertNil(ci.extra[@"space_id"]);
}

#pragma mark - WKMessageUtil.toMessage — External Group Phase 1 消息级字段透传 (YUJ-92 EP1)

- (void)test_messageUtil_toMessage_allFromFieldsWritten {
    NSDictionary *dict = @{
        @"message_id": @"1001",
        @"from_uid": @"u1",
        @"channel_id": @"g1",
        @"channel_type": @2,
        @"payload": @{@"type": @1, @"content": @"hi"},
        @"from_is_external": @1,
        @"from_source_space_name": @"销售",
        @"from_home_space_id": @"sp_home",
        @"from_home_space_name": @"研发",
    };
    WKMessage *msg = [WKMessageUtil toMessage:dict];
    XCTAssertNotNil(msg);
    XCTAssertEqualObjects(msg.extra[@"from_is_external"], @1);
    XCTAssertEqualObjects(msg.extra[@"from_source_space_name"], @"销售");
    XCTAssertEqualObjects(msg.extra[@"from_home_space_id"], @"sp_home");
    XCTAssertEqualObjects(msg.extra[@"from_home_space_name"], @"研发");
}

- (void)test_messageUtil_toMessage_nullGuards {
    NSDictionary *dict = @{
        @"message_id": @"1002",
        @"from_uid": @"u1",
        @"channel_id": @"g1",
        @"channel_type": @2,
        @"from_is_external": [NSNull null],
        @"from_source_space_name": [NSNull null],
        @"from_home_space_id": [NSNull null],
        @"from_home_space_name": [NSNull null],
    };
    XCTAssertNoThrow([WKMessageUtil toMessage:dict]);
    WKMessage *msg = [WKMessageUtil toMessage:dict];
    XCTAssertNil(msg.extra[@"from_is_external"]);
    XCTAssertNil(msg.extra[@"from_source_space_name"]);
    XCTAssertNil(msg.extra[@"from_home_space_id"]);
    XCTAssertNil(msg.extra[@"from_home_space_name"]);
}

- (void)test_messageUtil_toMessage_fieldsAbsent_noWrite {
    NSDictionary *dict = @{
        @"message_id": @"1003",
        @"from_uid": @"u1",
        @"channel_id": @"g1",
        @"channel_type": @2,
    };
    WKMessage *msg = [WKMessageUtil toMessage:dict];
    XCTAssertNil(msg.extra[@"from_is_external"]);
    XCTAssertNil(msg.extra[@"from_source_space_name"]);
}

- (void)test_messageUtil_toMessage_emptyStringsIgnored {
    NSDictionary *dict = @{
        @"message_id": @"1004",
        @"from_uid": @"u1",
        @"channel_id": @"g1",
        @"channel_type": @2,
        @"from_source_space_name": @"",
        @"from_home_space_id": @"",
        @"from_home_space_name": @"",
    };
    WKMessage *msg = [WKMessageUtil toMessage:dict];
    XCTAssertNil(msg.extra[@"from_source_space_name"]);
    XCTAssertNil(msg.extra[@"from_home_space_id"]);
    XCTAssertNil(msg.extra[@"from_home_space_name"]);
}

#pragma mark - WKMessageModel — External Group Phase 1 getter (YUJ-92 EP1)

- (void)test_messageModel_externalGetters_readFromMessageExtra {
    WKMessage *m = [WKMessage new];
    m.extra[@"from_is_external"] = @1;
    m.extra[@"from_source_space_name"] = @"销售";
    m.extra[@"from_home_space_id"] = @"sp_home";
    m.extra[@"from_home_space_name"] = @"研发";
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:m];
    XCTAssertTrue(model.fromIsExternal);
    XCTAssertEqualObjects(model.fromSourceSpaceName, @"销售");
    XCTAssertEqualObjects(model.fromHomeSpaceId, @"sp_home");
    XCTAssertEqualObjects(model.fromHomeSpaceName, @"研发");
}

- (void)test_messageModel_externalGetters_emptyByDefault {
    WKMessage *m = [WKMessage new];
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:m];
    XCTAssertFalse(model.fromIsExternal);
    XCTAssertNil(model.fromSourceSpaceName);
    XCTAssertNil(model.fromHomeSpaceId);
    XCTAssertNil(model.fromHomeSpaceName);
}

// 回落路径：message.extra 为空且 memberOfFrom 不存在（单元测试环境下 ChannelManager 没被初始化），
// 不应崩溃，应返回 false/nil。这验证了策略 B 兜底的防御性。
- (void)test_messageModel_externalGetters_doesNotCrashWhenMemberMissing {
    WKMessage *m = [WKMessage new];
    m.fromUid = @"unknown_uid";
    m.channel = [[WKChannel alloc] initWith:@"g1" channelType:WK_GROUP];
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:m];
    XCTAssertNoThrow([model fromIsExternal]);
    XCTAssertNoThrow([model fromSourceSpaceName]);
    XCTAssertNoThrow([model fromHomeSpaceId]);
    XCTAssertNoThrow([model fromHomeSpaceName]);
}

#pragma mark - WKMergeForwardContent — users 数组外部字段透传 (PR #981 对齐, YUJ-92 EP1)

- (void)test_mergeforward_usersArray_passesExternalFields {
    WKMergeForwardContent *c = [WKMergeForwardContent new];
    [c decodeWithJSON:@{
        @"channel_type": @2,
        @"users": @[
            @{@"uid": @"u1", @"name": @"Alice", @"is_external": @1, @"source_space_name": @"销售"},
            @{@"uid": @"u2", @"name": @"Bob"},
        ],
        @"msgs": @[],
    }];
    XCTAssertNotNil(c.users);
    XCTAssertEqual(c.users.count, 2);
    NSDictionary *u1 = c.users[0];
    XCTAssertEqualObjects(u1[@"is_external"], @1);
    XCTAssertEqualObjects(u1[@"source_space_name"], @"销售");
    NSDictionary *u2 = c.users[1];
    XCTAssertNil(u2[@"is_external"]);
}

- (void)test_mergeforward_innerMsgs_inheritFromIsExternal {
    WKMergeForwardContent *c = [WKMergeForwardContent new];
    [c decodeWithJSON:@{
        @"channel_type": @2,
        @"users": @[],
        @"msgs": @[@{
            @"message_id": @"2001",
            @"from_uid": @"u1",
            @"channel_id": @"g1",
            @"channel_type": @2,
            @"from_is_external": @1,
            @"from_source_space_name": @"销售",
            @"payload": @{@"type": @1, @"content": @"hi"},
        }],
    }];
    XCTAssertEqual(c.msgs.count, 1);
    WKMessage *inner = c.msgs.firstObject;
    XCTAssertEqualObjects(inner.extra[@"from_is_external"], @1);
    XCTAssertEqualObjects(inner.extra[@"from_source_space_name"], @"销售");
}

- (void)test_mergeforward_usersArray_nullGuard {
    WKMergeForwardContent *c = [WKMergeForwardContent new];
    XCTAssertNoThrow([c decodeWithJSON:@{
        @"channel_type": @2,
        @"users": [NSNull null],
        @"msgs": @[],
    }]);
    XCTAssertNil(c.users);
}

@end
