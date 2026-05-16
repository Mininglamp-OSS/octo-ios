//
//  WKExternalViewerResolverTests.m
//  LiMaoBase_Tests
//
//  (iOS EP2) — viewer-relative external-member resolver unit tests.
//
//  Mirror of Android `ExternalViewerResolverTest` (14 cases) and
//  dmwork-web `externalViewer.test.ts` (9 cases). The resolver is pure —
//  no NSUserDefaults / UIKit deps — so these run entirely in-process.
//
//  The extras-key-contract cases are the direct defense against the
//  silent-fail pattern (backend renames a field, client still
//  reads the old key, UI silently shows nothing).
//

@import XCTest;
#import "WKExternalViewerResolver.h"

@interface WKExternalViewerResolverTests : XCTestCase
@end

@implementation WKExternalViewerResolverTests

#pragma mark - Pure resolver — new-field path

- (void)testNewPath_HomeDifferent_IsExternal_ShowsHomeName {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:@"spaceA"
                                                                     homeSpaceName:@"OctoWork"
                                                                  isExternalLegacy:@(0)
                                                             sourceSpaceNameLegacy:nil
                                                                     viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"OctoWork");
}

- (void)testNewPath_HomeSameAsViewer_NotExternal_NoName {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:@"spaceA"
                                                                     homeSpaceName:@"OctoWork"
                                                                  isExternalLegacy:@(1)  // legacy says external, but home wins
                                                             sourceSpaceNameLegacy:@"Legacy"
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

- (void)testNewPath_HomeDifferent_HomeNameMissing_FallsBackToLegacyName {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:@"spaceA"
                                                                     homeSpaceName:@""  // empty string = missing
                                                                  isExternalLegacy:@(1)
                                                             sourceSpaceNameLegacy:@"Acme"
                                                                     viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

- (void)testNewPath_NullViewerSpaceId_TreatsAsExternal {
    // No viewer context — we can't prove "same space", so behave as web
    // PR #997 does: render the external affordance when we have a name.
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:@"spaceA"
                                                                     homeSpaceName:@"OctoWork"
                                                                  isExternalLegacy:nil
                                                             sourceSpaceNameLegacy:nil
                                                                     viewerSpaceId:nil];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"OctoWork");
}

#pragma mark - Pure resolver — legacy fallback path

- (void)testLegacyPath_IsExternal1_ShowsLegacyName {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:nil
                                                                     homeSpaceName:nil
                                                                  isExternalLegacy:@(1)
                                                             sourceSpaceNameLegacy:@"Acme"
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

- (void)testLegacyPath_IsExternal0_NotExternal {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:nil
                                                                     homeSpaceName:nil
                                                                  isExternalLegacy:@(0)
                                                             sourceSpaceNameLegacy:@"Acme"
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

- (void)testLegacyPath_EmptyHomeAndEmptyFlag_NotExternal {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:@""
                                                                     homeSpaceName:@""
                                                                  isExternalLegacy:nil
                                                             sourceSpaceNameLegacy:nil
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

- (void)testLegacyPath_StringFlag_One_IsExternal {
    // Some backends send JSON strings instead of numbers (NSString @"1")
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:nil
                                                                     homeSpaceName:nil
                                                                  isExternalLegacy:@"1"
                                                             sourceSpaceNameLegacy:@"Acme"
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

- (void)testLegacyPath_NSNullValues_DefaultToNotExternal {
    // Defensive: raw parsers occasionally surface NSNull; must not crash.
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveWithHomeSpaceId:[NSNull null]
                                                                     homeSpaceName:[NSNull null]
                                                                  isExternalLegacy:[NSNull null]
                                                             sourceSpaceNameLegacy:[NSNull null]
                                                                     viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

#pragma mark - resolveFromExtras contract

- (void)testResolveFromExtras_NilExtras_NotExternal {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveFromExtras:nil
                                                              viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

- (void)testResolveFromExtras_EmptyExtras_NotExternal {
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveFromExtras:@{}
                                                              viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
}

- (void)testResolveFromExtras_NewPath_FromDict {
    NSDictionary *extras = @{
        @"home_space_id": @"spaceA",
        @"home_space_name": @"OctoWork",
        @"is_external": @(1),
        @"source_space_name": @"stale",
    };
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveFromExtras:extras
                                                              viewerSpaceId:@"spaceB"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"OctoWork"); // new-path name wins
}

- (void)testResolveFromExtras_ExtrasKeyContract {
    // This test locks the contract between data-layer writers and
    // resolver readers. If these literals diverge from WKDataSourceModel
    // / WKChannelUtil / resolver, the UI will silently show nothing —
    // the failure mode we MUST prevent. Keep in sync with
    // Android ExternalViewerResolverTest.extrasKeyContract().
    XCTAssertEqualObjects(WKExternalExtrasKeyHomeSpaceId, @"home_space_id");
    XCTAssertEqualObjects(WKExternalExtrasKeyHomeSpaceName, @"home_space_name");
    XCTAssertEqualObjects(WKExternalExtrasKeyIsExternal, @"is_external");
    XCTAssertEqualObjects(WKExternalExtrasKeySourceSpaceId, @"source_space_id");
    XCTAssertEqualObjects(WKExternalExtrasKeySourceSpaceName, @"source_space_name");
}

#pragma mark - Edge cases

- (void)testResolveFromExtras_HomeSpaceIdEmptyString_FallsBackToLegacy {
    // Empty string must be treated as "missing" so legacy fallback
    // applies. Web resolveExternalForViewer does the same.
    NSDictionary *extras = @{
        @"home_space_id": @"",
        @"home_space_name": @"",
        @"is_external": @(1),
        @"source_space_name": @"Acme",
    };
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveFromExtras:extras
                                                              viewerSpaceId:@"spaceA"];
    XCTAssertTrue(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"Acme");
}

- (void)testSelfViewing_HomeEqualsViewer_NotExternal {
    // Self-view invariant: viewer is spaceA, viewing their own profile
    // (home=spaceA). Must NOT render @SpaceName suffix.
    NSDictionary *extras = @{
        @"home_space_id": @"spaceA",
        @"home_space_name": @"OctoWork",
    };
    WKExternalResolveResult *r = [WKExternalViewerResolver resolveFromExtras:extras
                                                              viewerSpaceId:@"spaceA"];
    XCTAssertFalse(r.isExternal);
    XCTAssertEqualObjects(r.sourceSpaceName, @"");
}

@end
