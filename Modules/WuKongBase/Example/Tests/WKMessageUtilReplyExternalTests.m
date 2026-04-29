//
//  WKMessageUtilReplyExternalTests.m
//  LiMaoBase_Tests
//
//  YUJ-131 · iOS P0 — unit tests for +applyMsgLevelExternalFieldsToReply:dict:.
//  Mirrors the 5 scenarios from dmwork-web PR #1073 Reply.decode tests plus
//  one extra case for the YUJ-53 silent-fail reply-field-missing downgrade.
//
//  These run purely in-process: the helper writes to WKReply associated
//  properties (via WKReply+ExternalGroup), no UI / NSUserDefaults deps.
//

@import XCTest;
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageUtil.h"
#import "WKReply+ExternalGroup.h"
#import "WKExternalViewerResolver.h"

@interface WKMessageUtilReplyExternalTests : XCTestCase
@end

@implementation WKMessageUtilReplyExternalTests

#pragma mark - Helper direct — 6 scenarios

// Scenario 1 — new-path fields populated (home_space_id + home_space_name), legacy empty.
// Expected: reply picks up both new fields; resolver treats as external when viewer!=home.
- (void)testApply_NewPath_HomeIdAndName_Present {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_home_space_id": @"spaceA",
        @"from_home_space_name": @"OctoWork",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    XCTAssertEqualObjects(reply.fromHomeSpaceId, @"spaceA");
    XCTAssertEqualObjects(reply.fromHomeSpaceName, @"OctoWork");
    XCTAssertFalse(reply.fromIsExternal);
    XCTAssertNil(reply.fromSourceSpaceName);

    // End-to-end: feed into resolver with different viewer.
    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"OctoWork");
}

// Scenario 2 — new-path fields with viewer == home. Resolver should say non-external.
- (void)testApply_NewPath_ViewerEqualsHome_NotExternal {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_home_space_id": @"spaceA",
        @"from_home_space_name": @"OctoWork",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

// Scenario 3 — legacy-only fields (no home_space_id). Resolver should fall back.
- (void)testApply_LegacyOnly_IsExternal1_UsesSourceSpaceName {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_is_external": @(1),
        @"from_source_space_name": @"Acme",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    XCTAssertNil(reply.fromHomeSpaceId);
    XCTAssertNil(reply.fromHomeSpaceName);
    XCTAssertTrue(reply.fromIsExternal);
    XCTAssertEqualObjects(reply.fromSourceSpaceName, @"Acme");

    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

// Scenario 4 — new + legacy混合（rollout 中间态）：home_name 缺失，应回落到 source_space_name.
- (void)testApply_NewPath_HomeNameEmpty_FallsBackToLegacySource {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_home_space_id": @"spaceA",
        @"from_home_space_name": @"",          // 空字符串 = 字段缺失
        @"from_is_external": @(1),
        @"from_source_space_name": @"Acme",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    XCTAssertEqualObjects(reply.fromHomeSpaceId, @"spaceA");
    XCTAssertNil(reply.fromHomeSpaceName); // 空串被当作缺失丢弃
    XCTAssertTrue(reply.fromIsExternal);
    XCTAssertEqualObjects(reply.fromSourceSpaceName, @"Acme");

    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

// Scenario 5 — non-external viewer-relative：home_id == viewer，legacy 说 external 也不采信.
// （对齐 resolver 的 "home wins over legacy" 规则，YUJ-93）
- (void)testApply_NewPath_WinsOverLegacy_NotExternal {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_home_space_id": @"spaceA",
        @"from_home_space_name": @"OctoWork",
        @"from_is_external": @(1),
        @"from_source_space_name": @"Legacy",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];

    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

// Scenario 6 — 全缺失降级场景（YUJ-53 silent-fail 防御）：reply dict 不带任何外部群字段时，
// UI 不应该崩溃，也不该误判为 external。
- (void)testApply_AllFieldsMissing_DefaultsToNonExternal {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{ @"from_uid": @"u1", @"from_name": @"Alice" }; // 只有基础字段
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    XCTAssertNil(reply.fromHomeSpaceId);
    XCTAssertNil(reply.fromHomeSpaceName);
    XCTAssertFalse(reply.fromIsExternal);
    XCTAssertNil(reply.fromSourceSpaceName);

    WKExternalResolveResult *r = [WKExternalViewerResolver
        resolveWithHomeSpaceId:reply.fromHomeSpaceId
                 homeSpaceName:reply.fromHomeSpaceName
              isExternalLegacy:@(reply.fromIsExternal ? 1 : 0)
         sourceSpaceNameLegacy:reply.fromSourceSpaceName
                 viewerSpaceId:@"spaceB"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

#pragma mark - Edge cases

// nil reply or nil dict is a no-op, not a crash.
- (void)testApply_NilInputs_NoOp {
    XCTAssertNoThrow([WKMessageUtil applyMsgLevelExternalFieldsToReply:nil dict:@{}]);
    WKReply *reply = [WKReply new];
    XCTAssertNoThrow([WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:nil]);
    XCTAssertNil(reply.fromHomeSpaceId);
}

// Non-dict input (defensive): helper should bail out, not crash.
- (void)testApply_NonDictInput_NoOp {
    WKReply *reply = [WKReply new];
    id fake = (id)@"not a dict";
    XCTAssertNoThrow([WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:fake]);
    XCTAssertNil(reply.fromHomeSpaceId);
    XCTAssertFalse(reply.fromIsExternal);
}

// String "1" is coerced to YES by resolver; helper stores it as BOOL.
- (void)testApply_LegacyStringFlag_Coerced {
    WKReply *reply = [WKReply new];
    NSDictionary *dict = @{
        @"from_is_external": @"1",
        @"from_source_space_name": @"StringAcme",
    };
    [WKMessageUtil applyMsgLevelExternalFieldsToReply:reply dict:dict];
    XCTAssertTrue(reply.fromIsExternal);
    XCTAssertEqualObjects(reply.fromSourceSpaceName, @"StringAcme");
}

@end
