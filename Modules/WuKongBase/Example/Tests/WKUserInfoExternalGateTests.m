//
//  WKUserInfoExternalGateTests.m
//  WuKongBase_Tests
//
//  YUJ-137 (iOS P1) — DM gate unit tests, parallel to web
//  `UserInfoExternalHint.test.tsx` (PR #1021) and Android UserDetail
//  viewer-relative DM suppression.
//
//  Only the gate is exercised here; button / label layout lives in
//  WKUserInfoVC and is verified via Simulator screenshots (see
//  attached QA evidence on YUJ-137).
//

@import XCTest;
#import "WKUserInfoExternalGate.h"
#import "WKExternalViewerResolver.h"

@interface WKUserInfoExternalGateTests : XCTestCase
@end

@implementation WKUserInfoExternalGateTests

#pragma mark - 1. External member (home_space_id != viewer) → hide DM

- (void)testExternalMember_HidesDM {
    NSDictionary *memberExtras = @{
        WKExternalExtrasKeyHomeSpaceId:   @"space_home",
        WKExternalExtrasKeyHomeSpaceName: @"OctoWork",
    };
    BOOL hide = [WKUserInfoExternalGate
        shouldHideDMWithMemberExtras:memberExtras
                   channelInfoExtras:nil
                       viewerSpaceId:@"space_viewer"
                              isSelf:NO];
    XCTAssertTrue(hide, @"外部成员（home_space_id != viewer）应隐藏 DM 按钮");
}

#pragma mark - 2. Same-space member (home_space_id == viewer) → show DM,
//                 even if stale legacy is_external=1 sits on channelInfo

- (void)testSameSpaceMember_ShowsDM_EvenWithStaleLegacyOnChannelInfo {
    NSDictionary *memberExtras = @{
        WKExternalExtrasKeyHomeSpaceId: @"space_viewer",
    };
    // Stale cache pretending "external" on channelInfo — must NOT win.
    NSDictionary *channelInfoExtras = @{
        WKExternalExtrasKeyIsExternal:        @(1),
        WKExternalExtrasKeySourceSpaceName:   @"OldSpace",
    };
    BOOL hide = [WKUserInfoExternalGate
        shouldHideDMWithMemberExtras:memberExtras
                   channelInfoExtras:channelInfoExtras
                       viewerSpaceId:@"space_viewer"
                              isSelf:NO];
    XCTAssertFalse(hide, @"同 Space 成员即便旧 legacy=1 也不应隐藏 DM（对齐 web PR #1021 stale-cache 反面用例）");
}

#pragma mark - 3. Self → never hide, regardless of external flags

- (void)testSelf_NeverHidesDM {
    NSDictionary *memberExtras = @{
        WKExternalExtrasKeyHomeSpaceId:   @"space_other",
        WKExternalExtrasKeyHomeSpaceName: @"SomewhereElse",
    };
    BOOL hide = [WKUserInfoExternalGate
        shouldHideDMWithMemberExtras:memberExtras
                   channelInfoExtras:nil
                       viewerSpaceId:@"space_viewer"
                              isSelf:YES];
    XCTAssertFalse(hide, @"自看 UserInfo 永远不隐藏 DM/好友入口");
}

#pragma mark - 4. Legacy-only fallback: channelInfo.extra carries
//                 is_external=1 and no group-member context → hide DM.
//                 Guards against the YUJ-137 backend-rollout window where
//                 /users/{uid} still writes legacy keys.

- (void)testLegacyChannelInfoFallback_HidesDM_WhenNoMemberExtras {
    NSDictionary *channelInfoExtras = @{
        WKExternalExtrasKeyIsExternal:      @(1),
        WKExternalExtrasKeySourceSpaceName: @"FinanceOrg",
    };
    BOOL hide = [WKUserInfoExternalGate
        shouldHideDMWithMemberExtras:nil
                   channelInfoExtras:channelInfoExtras
                       viewerSpaceId:@"space_viewer"
                              isSelf:NO];
    XCTAssertTrue(hide, @"无群成员上下文时应按 channelInfo 的 legacy is_external 降级判定");
}

@end
