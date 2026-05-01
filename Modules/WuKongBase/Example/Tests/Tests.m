//
//  Tests.m
//  WuKongBase Tests
//
//  Unit tests for WuKongBase (EP1 YUJ-92 + EP3 YUJ-94 / WKSpaceFilter).
//

@import XCTest;
#import <WuKongBase/WKChannelUtil.h>
#import <WuKongBase/WKMessageUtil.h>
#import <WuKongBase/WKMessageModel.h>
#import <WuKongBase/WKMergeForwardContent.h>
#import "WKSpaceFilter.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

#pragma mark - Stub Provider

@interface WKStubSpaceFilterProvider : NSObject <WKSpaceFilterDataProvider>
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *spaceMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *sourceMap;
@end

@implementation WKStubSpaceFilterProvider
- (instancetype)init {
    if (self = [super init]) {
        _spaceMap = [NSMutableDictionary dictionary];
        _sourceMap = [NSMutableDictionary dictionary];
    }
    return self;
}
- (NSString *)_key:(NSString *)cid type:(uint8_t)t {
    return [NSString stringWithFormat:@"%@#%u", cid ?: @"", (unsigned)t];
}
- (NSString *)spaceIdForChannelId:(NSString *)channelId channelType:(uint8_t)channelType {
    return self.spaceMap[[self _key:channelId type:channelType]];
}
- (NSString *)mySourceSpaceIdForChannelId:(NSString *)channelId channelType:(uint8_t)channelType {
    return self.sourceMap[[self _key:channelId type:channelType]];
}
- (void)setChannelSpace:(NSString *)sid forChannelId:(NSString *)cid type:(uint8_t)t {
    if (sid) self.spaceMap[[self _key:cid type:t]] = sid;
}
- (void)setMySourceSpace:(NSString *)sid forChannelId:(NSString *)cid type:(uint8_t)t {
    if (sid) self.sourceMap[[self _key:cid type:t]] = sid;
}
@end

#pragma mark - WuKongBase EP1 Tests (YUJ-92)

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

#pragma mark - WKSpaceFilter Tests (YUJ-94 / EP3)

@interface WKSpaceFilterTests : XCTestCase
@end

@implementation WKSpaceFilterTests

// 32-hex test space ids（对齐 web `s{32hex}_` 格式）
static NSString * const SP_A = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; // 32 × 'a'
static NSString * const SP_B = @"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"; // 32 × 'b'

#pragma mark 纯函数分支

/// branch 1: space-empty — currentSpaceId=nil 不过滤
- (void)testDecide_SpaceEmpty_ReturnsKeep {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:nil
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);

    d = [WKSpaceFilter decideWithChannelId:@"g1"
                              channelType:WK_GROUP
                           currentSpaceId:@""
                           channelSpaceId:SP_B
                          mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

/// branch 2: space-prefix match
- (void)testDecide_SpacePrefix_Match_ReturnsKeep {
    NSString *cid = [NSString stringWithFormat:@"s%@_group1", SP_A];
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:cid
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:nil
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

/// branch 2: space-prefix mismatch **不直接 skip**，而是 fall-through 到 cache/source 判定
/// （外部群 owning Space 前缀 ≠ current 时，必须给 source_space_id 兜底机会）
- (void)testDecide_SpacePrefixMismatch_NoCache_FallsThroughToFailOpen {
    NSString *cid = [NSString stringWithFormat:@"s%@_group1", SP_A];
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:cid
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_B
                                                   channelSpaceId:nil
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionFailOpen,
                   @"前缀不匹配 + 无缓存 → fail-open（等 channelInfo 回调）而非立即 Skip");
}

/// branch 2: 前缀不匹配 + cache 也 B + member 已缓存且 source=B → cached-mismatch Skip
- (void)testDecide_SpacePrefixMismatch_CachedMismatch_ReturnsSkip {
    NSString *cid = [NSString stringWithFormat:@"s%@_group1", SP_B];
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:cid
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:SP_B]; // 明确非外部成员
    XCTAssertEqual(d, WKSpaceFilterDecisionSkip);
}

/// 🔴 Codex P2 回归：外部群 channelId = `s{B}_...`，current=A，source=A → Keep
- (void)testDecide_SpacePrefixMismatch_ExternalMember_ReturnsKeep {
    NSString *cid = [NSString stringWithFormat:@"s%@_externalGroup", SP_B];
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:cid
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B           // 群归 B
                                                  mySourceSpaceId:SP_A];         // 我以 A 身份加入
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep,
                   @"外部群 owning Space 前缀 ≠ current，但 member.source_space_id == current 应放行");
}

/// 前缀不匹配 + info 未回 + subscriber 就绪 → 走 info-miss-source-match 分支 Keep
- (void)testDecide_SpacePrefixMismatch_InfoMissSourceMatch_ReturnsKeep {
    NSString *cid = [NSString stringWithFormat:@"s%@_externalGroup", SP_B];
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:cid
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:nil
                                                  mySourceSpaceId:SP_A];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

/// 非法前缀（长度 ≠ 32 / 非 hex）不走前缀路径，回落到 cache 判定
- (void)testDecide_InvalidPrefix_FallsThroughToCache {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"sfoo_group"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_A
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep, @"非法前缀应走 cache 判定");
}

/// branch 3: person-pass — 私聊永不按 channelId 过滤
- (void)testDecide_Person_ReturnsKeep {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"user1"
                                                      channelType:WK_PERSON
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

/// branch 4: cached-match — 群 space_id == current
- (void)testDecide_CachedMatch_ReturnsKeep {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_A
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

/// branch 5: cached-external-member — 群 space 不匹配但我 source_space_id 匹配（外部成员兜底）
- (void)testDecide_CachedExternalMember_ReturnsKeep {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B        // 群归属 B
                                                  mySourceSpaceId:SP_A];      // 我以 A 身份加入 → 放行
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep,
                   @"外部群兜底：source_space_id == currentSpaceId 应放行");
}

/// branch 6: cached-mismatch — 群归其他 Space + member 记录已缓存但 source 不匹配 → Skip
/// （member 数据就绪是 Skip 的前提，否则会错杀 member sync 未完成的外部群）
- (void)testDecide_CachedMismatch_ReturnsSkip {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:SP_B]; // member.source = B (非外部成员)
    XCTAssertEqual(d, WKSpaceFilterDecisionSkip);
}

/// member 未缓存 → fail-open（不能武断判为非成员，避免外部群短暂消失的竞态）
- (void)testDecide_CachedSpaceMismatch_MemberNotCached_ReturnsFailOpen {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:nil]; // member 未同步
    XCTAssertEqual(d, WKSpaceFilterDecisionFailOpen,
                   @"channel space 不匹配但 member 未就绪 → fail-open 让 whitelist 兜底");
}

/// source_space_id 存在但也不匹配 → 仍 skip
- (void)testDecide_MismatchWithUnrelatedSource_ReturnsSkip {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:SP_B
                                                  mySourceSpaceId:SP_B];
    XCTAssertEqual(d, WKSpaceFilterDecisionSkip);
}

/// branch 7: fail-open — 无 channelSpaceId、无 mySourceSpaceId
- (void)testDecide_FailOpen {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:nil
                                                  mySourceSpaceId:nil];
    XCTAssertEqual(d, WKSpaceFilterDecisionFailOpen);
}

/// info 未缓存但 subscriber source 就绪 → 也走外部成员放行（早期 sync 场景）
- (void)testDecide_InfoMissButSourceMatches_ReturnsKeep {
    WKSpaceFilterDecision d = [WKSpaceFilter decideWithChannelId:@"g1"
                                                      channelType:WK_GROUP
                                                   currentSpaceId:SP_A
                                                   channelSpaceId:nil
                                                  mySourceSpaceId:SP_A];
    XCTAssertEqual(d, WKSpaceFilterDecisionKeep);
}

#pragma mark 实例路径（走 provider）

- (void)testShouldSkipChannelForSpace_UsesProvider {
    WKStubSpaceFilterProvider *stub = [WKStubSpaceFilterProvider new];
    [stub setChannelSpace:SP_B forChannelId:@"g1" type:WK_GROUP];
    [stub setMySourceSpace:SP_A forChannelId:@"g1" type:WK_GROUP];

    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    id<WKSpaceFilterDataProvider> original = [WKSpaceFilter shared].provider;
    [WKSpaceFilter shared].provider = stub;
    @try {
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"g1" channelType:WK_GROUP],
                       @"外部群 source_space_id == current → 不跳过");

        // 另一群 g2 归 B 我已明确不是外部成员（member.source=B）→ 跳过
        [stub setChannelSpace:SP_B forChannelId:@"g2" type:WK_GROUP];
        [stub setMySourceSpace:SP_B forChannelId:@"g2" type:WK_GROUP];
        XCTAssertTrue([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"g2" channelType:WK_GROUP]);

        // g3 归 B，member 数据未同步 → fail-open（shouldSkip 返回 NO），让 whitelist 兜底
        [stub setChannelSpace:SP_B forChannelId:@"g3" type:WK_GROUP];
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"g3" channelType:WK_GROUP],
                       @"member 未缓存 → fail-open，不武断 Skip");
    } @finally {
        [WKSpaceFilter shared].provider = original;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

- (void)testCurrentSpaceId_TrimsEmpty {
    [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"currentSpaceId"];
    XCTAssertNil([[WKSpaceFilter shared] currentSpaceId]);

    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    XCTAssertEqualObjects([[WKSpaceFilter shared] currentSpaceId], SP_A);

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    XCTAssertNil([[WKSpaceFilter shared] currentSpaceId]);
}

#pragma mark 消息级

- (void)testShouldSkipMessageForSpace_NonPerson_ReturnsNO {
    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    WKMessage *msg = [WKMessage new];
    WKMessageContent *content = [WKMessageContent new];
    content.contentDict = @{ @"space_id": SP_B };
    msg.content = content;
    @try {
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipMessageForSpace:msg channelType:WK_GROUP]);
    } @finally {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

- (void)testShouldSkipMessageForSpace_PersonMismatch_ReturnsYES {
    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    WKMessage *msg = [WKMessage new];
    WKMessageContent *content = [WKMessageContent new];
    content.contentDict = @{ @"space_id": SP_B };
    msg.content = content;
    @try {
        XCTAssertTrue([[WKSpaceFilter shared] shouldSkipMessageForSpace:msg channelType:WK_PERSON]);
    } @finally {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

- (void)testShouldSkipMessageForSpace_LegacyEmptySpaceId_ReturnsNO {
    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    WKMessage *msg = [WKMessage new];
    WKMessageContent *content = [WKMessageContent new];
    content.contentDict = @{}; // 历史消息无 space_id
    msg.content = content;
    @try {
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipMessageForSpace:msg channelType:WK_PERSON],
                       @"历史无 space_id 消息应放行（向前兼容）");
    } @finally {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

- (void)testShouldSkipMessageForSpace_PersonMatch_ReturnsNO {
    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    WKMessage *msg = [WKMessage new];
    WKMessageContent *content = [WKMessageContent new];
    content.contentDict = @{ @"space_id": SP_A };
    msg.content = content;
    @try {
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipMessageForSpace:msg channelType:WK_PERSON]);
    } @finally {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

#pragma mark YUJ-209 — 新消息 + 外部群 + 非当前 Space 串台分支

/// viewer 停留 Space A，Space B 的外部群有新消息到达：
/// channelInfo.space_id=B 且 member.source_space_id=B（我不是 A 的外部成员）
/// → cached-mismatch，必须 Skip，防止该群污染 A 的会话列表（YUJ-209 串台 bug）。
- (void)testYUJ209_NewMessageForOtherSpaceExternalGroup_ReturnsSkip {
    WKStubSpaceFilterProvider *stub = [WKStubSpaceFilterProvider new];
    [stub setChannelSpace:SP_B forChannelId:@"ext_group_b" type:WK_GROUP];
    [stub setMySourceSpace:SP_B forChannelId:@"ext_group_b" type:WK_GROUP];

    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    id<WKSpaceFilterDataProvider> original = [WKSpaceFilter shared].provider;
    [WKSpaceFilter shared].provider = stub;
    @try {
        WKSpaceFilterDecision d = [[WKSpaceFilter shared]
                                    decideChannel:@"ext_group_b"
                                      channelType:WK_GROUP];
        XCTAssertEqual(d, WKSpaceFilterDecisionSkip,
                       @"YUJ-209: 外部群归属 B + 我在 B 的身份 → 在 A 视角必须 Skip");
        XCTAssertTrue([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"ext_group_b"
                                                            channelType:WK_GROUP]);
    } @finally {
        [WKSpaceFilter shared].provider = original;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

/// 同一外部群，viewer 是以 A 身份扫码加入的（member.source=A，但群 owning Space 仍为 B）
/// → cached-external-member，Keep。新消息到达时必须允许浮到 A 列表顶部（验收条件 2）。
- (void)testYUJ209_NewMessageForMyExternalGroup_ReturnsKeep {
    WKStubSpaceFilterProvider *stub = [WKStubSpaceFilterProvider new];
    [stub setChannelSpace:SP_B forChannelId:@"ext_group_b" type:WK_GROUP];
    [stub setMySourceSpace:SP_A forChannelId:@"ext_group_b" type:WK_GROUP];

    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    id<WKSpaceFilterDataProvider> original = [WKSpaceFilter shared].provider;
    [WKSpaceFilter shared].provider = stub;
    @try {
        WKSpaceFilterDecision d = [[WKSpaceFilter shared]
                                    decideChannel:@"ext_group_b"
                                      channelType:WK_GROUP];
        XCTAssertEqual(d, WKSpaceFilterDecisionKeep,
                       @"YUJ-209: A 身份的外部群新消息必须出现在 A 列表");
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"ext_group_b"
                                                             channelType:WK_GROUP]);
    } @finally {
        [WKSpaceFilter shared].provider = original;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

/// 新消息路径 fail-open：channelInfo 尚未缓存（EP1 未回写）→ FailOpen。
/// 此时 WKConversationListVC.filterConversationsBySpace 会降级走原有白名单，
/// 保证行为等价 develop（不会比现状更糟），满足「source_space_id 未加载按 fail-open 降级」约束。
- (void)testYUJ209_NewMessageFailOpenWhenChannelInfoMissing {
    WKStubSpaceFilterProvider *stub = [WKStubSpaceFilterProvider new];
    // 不设置 spaceMap 也不设置 sourceMap → 两者均 nil
    [[NSUserDefaults standardUserDefaults] setObject:SP_A forKey:@"currentSpaceId"];
    id<WKSpaceFilterDataProvider> original = [WKSpaceFilter shared].provider;
    [WKSpaceFilter shared].provider = stub;
    @try {
        WKSpaceFilterDecision d = [[WKSpaceFilter shared]
                                    decideChannel:@"unknown_group"
                                      channelType:WK_GROUP];
        XCTAssertEqual(d, WKSpaceFilterDecisionFailOpen,
                       @"YUJ-209: EP1 未就绪 → FailOpen，让调用方走 whitelist 兜底");
        XCTAssertFalse([[WKSpaceFilter shared] shouldSkipChannelForSpace:@"unknown_group"
                                                             channelType:WK_GROUP],
                       @"FailOpen 状态不应被 shouldSkip 误判为 Skip");
    } @finally {
        [WKSpaceFilter shared].provider = original;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentSpaceId"];
    }
}

@end
