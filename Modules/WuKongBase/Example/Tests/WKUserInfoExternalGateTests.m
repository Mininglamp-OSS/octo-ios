//
//  WKUserInfoExternalGateTests.m
//  WuKongBase_Tests
//
//  (iOS P1) — DM gate unit tests, parallel to web
//  `UserInfoExternalHint.test.tsx` (PR #1021) and Android UserDetail
//  viewer-relative DM suppression.
//
//  Only the gate is exercised here; button / label layout lives in
//  WKUserInfoVC and is verified via Simulator screenshots (see
//  attached QA evidence on ).
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
//                 Guards against the backend-rollout window where
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

#pragma mark - Space-mode 免好友短路分支（shouldUseSpaceModeSendMessage）
//                 锁定优先级：external hint > self > Space-mode 非bot → sendMsg
//                 > Space-mode bot > 非Space-mode follow

- (void)testSpaceModeSendMsg_HumanNonFriendInSpace_ReturnsYES {
    BOOL yes = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:@"space_viewer"
                                              isBot:NO
                                             follow:0];
    XCTAssertTrue(yes, @"同 Space 非好友人类应走 sendBtn 分支（对齐 web UserInfo/index.tsx:52-55）");
}

- (void)testSpaceModeSendMsg_External_ReturnsNO {
    BOOL yes = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:YES
                                      viewerSpaceId:@"space_viewer"
                                              isBot:NO
                                             follow:0];
    XCTAssertFalse(yes, @"跨 Space 外部成员让路给 shouldHideDM → footer hint 分支");
}

- (void)testSpaceModeSendMsg_Bot_ReturnsNO {
    BOOL yes = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:@"space_viewer"
                                              isBot:YES
                                             follow:0];
    XCTAssertFalse(yes, @"Space 模式下 bot 仍走 addFriendBtn → bot_add_friend 审批流");
}

- (void)testSpaceModeSendMsg_NonSpaceMode_ReturnsNO {
    BOOL nilSpace = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:nil
                                              isBot:NO
                                             follow:0];
    XCTAssertFalse(nilSpace, @"nil viewerSpaceId 视为非 Space 模式，保留 follow + vercode 老路径");

    BOOL emptySpace = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:@""
                                              isBot:NO
                                             follow:0];
    XCTAssertFalse(emptySpace, @"空串 viewerSpaceId 同样视为非 Space 模式");
}

- (void)testSpaceModeSendMsg_AlreadyFriend_ReturnsNO {
    BOOL yes = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:@"space_viewer"
                                              isBot:NO
                                             follow:1];
    XCTAssertFalse(yes, @"follow=1 由原 sendBtn 分支处理，此 gate 应短路返回 NO");
}

/*
 嘉伟 bot 硬约束（产品决策）：bot + friend + Space → 原 sendBtn 分支接管。
 优先级 #4：gate 短路返回 NO（follow != 0 先于 isBot 判断），让 VC 既有的
 isActualFriend 分支统一走 sendBtn，不干扰 bot add-friend 审批流（仅 follow=0 生效）。
 */
- (void)testSpaceModeSendMsg_BotFriendInSpace_ReturnsNO {
    BOOL yes = [WKUserInfoExternalGate
        shouldUseSpaceModeSendMessageWithIsExternal:NO
                                      viewerSpaceId:@"space_viewer"
                                              isBot:YES
                                             follow:1];
    XCTAssertFalse(yes, @"bot+friend+Space：gate 让路给 isActualFriend → sendBtn 分支，优先级 #4");
}

@end
