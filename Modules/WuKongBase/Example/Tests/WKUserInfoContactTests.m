// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

@import XCTest;
@import WuKongBase;
#import <objc/runtime.h>
#import "WKApp.h"
#import "WKUserInfoVC.h"
#import "WKEndpoint.h"
#import "WKModel.h"

@interface WKUserInfoVC (ContactConfigTesting)
- (void)requestContactInfoConfig;
@end

@interface WKContactConfigStub : WKAppRemoteConfig
@property(nonatomic,copy) void (^pendingCallback)(NSError *);
@property(nonatomic,assign) NSInteger requestCount;
@end
@implementation WKContactConfigStub
- (void)requestConfig:(void (^)(NSError *))callback {
    self.requestCount++;
    if(callback) { self.pendingCallback = callback; }
}
@end

@interface WKContactReloadSpy : WKUserInfoVM
@property(nonatomic,assign) NSInteger reloadCount;
@end
@implementation WKContactReloadSpy
- (void)reloadData { self.reloadCount++; }
@end

// Exercise the real endpoint and per-page VM; no API or persisted contacts.
@interface WKUserInfoContactTests : XCTestCase
@property(nonatomic,strong) id savedRemoteConfig;
@property(nonatomic,copy) NSString *savedUID;
@property(nonatomic,strong) NSArray<WKEndpoint *> *savedEndpoints;
@property(nonatomic,strong) WKUserInfoVM *vm;
@end

@implementation WKUserInfoContactTests

- (void)setUp {
    [super setUp];
    WKApp *app = [WKApp shared];
    self.savedRemoteConfig = object_getIvar(app, class_getInstanceVariable(WKApp.class, "_remoteConfig"));
    WKAppRemoteConfig *config = [WKAppRemoteConfig new];
    config.requestSuccess = YES;
    config.requestAppModuleSuccess = YES;
    config.profileContactInfoOn = YES;
    [app setValue:config forKey:@"remoteConfig"];
    self.savedUID = app.loginInfo.uid;
    app.loginInfo.uid = @"contact-test-viewer";
    self.savedEndpoints = [[app getEndpointsWithCategory:WKPOINT_CATEGORY_USER_INFO_ITEM] copy];
    [app unregisterEndpointWithCategory:WKPOINT_CATEGORY_USER_INFO_ITEM];
    self.vm = [self profileForUID:@"contact-test-peer"];
}

- (void)tearDown {
    WKApp *app = [WKApp shared];
    [app unregisterEndpointWithCategory:WKPOINT_CATEGORY_USER_INFO_ITEM];
    for(WKEndpoint *endpoint in self.savedEndpoints) {
        [app registerEndpoint:endpoint];
    }
    app.loginInfo.uid = self.savedUID;
    [app setValue:self.savedRemoteConfig forKey:@"remoteConfig"];
    self.vm = nil;
    [super tearDown];
}

- (WKUserInfoVM *)profileForUID:(NSString *)uid {
    WKUserInfoVM *vm = [WKUserInfoVM new];
    vm.uid = uid;
    vm.channelInfo = [WKChannelInfo new];
    vm.channelInfo.channel = [WKChannel personWithChannelID:uid];
    vm.channelInfo.name = @"Test user";
    [vm setValue:@"13800001234" forKey:@"userPhone"];
    [vm setValue:@"person@example.invalid" forKey:@"userEmail"];
    return vm;
}

- (NSDictionary *)contacts:(WKUserInfoVM *)vm {
    // Use the same endpoint inputs as tableSectionMaps, including this VM's context.
    NSMutableDictionary *param = [@{@"uid":vm.uid, @"channel_info":vm.channelInfo,
                                    @"context":[vm valueForKey:@"contextDict"],
                                    @"accountState":[vm valueForKey:@"userAccountState"],
                                    @"reload":^{}} mutableCopy];
    param[@"phone"] = [vm valueForKey:@"userPhone"];
    param[@"email"] = [vm valueForKey:@"userEmail"];
    param[@"zone"] = [vm valueForKey:@"userZone"];
    param[@"phoneCountryCode"] = [vm valueForKey:@"userPhoneCountryCode"];
    return [[WKApp shared] invoke:@"user.info.phoneEmail" param:param];
}

- (void)testAccountStatesRetainIntegerValuesFromAPI {
    Class modelClass = NSClassFromString(@"UserModel");
    XCTAssertNotNil(modelClass);
    for(id raw in @[@0, @1, @2, @"0", @"1", @"2"]) {
        id user = [modelClass fromMap:@{@"is_destroy":raw} type:ModelMapTypeAPI];
        XCTAssertEqual([[user valueForKey:@"accountState"] integerValue], [raw integerValue]);
    }
    XCTAssertNoThrow([modelClass fromMap:@{@"is_destroy":NSNull.null} type:ModelMapTypeAPI]);
}

- (void)testPeerAccountStateMatrix {
    for(NSNumber *state in @[@0, @1, @2]) {
        [self.vm setValue:state forKey:@"userAccountState"];
        XCTAssertEqual([self contacts:self.vm] != nil, state.integerValue == 0);
    }
}

- (void)testCoolingOffSelfStillSeesFullPhoneButFlagAndRobotOverride {
    self.vm.uid = [WKApp shared].loginInfo.uid;
    [self.vm setValue:@1 forKey:@"userAccountState"];
    NSDictionary *phone = [self contacts:self.vm][@"items"][0];
    XCTAssertEqualObjects(phone[@"value"], @"13800001234");
    XCTAssertEqualObjects(phone[@"valueCopy"], @YES);
    [WKApp shared].remoteConfig.profileContactInfoOn = NO;
    XCTAssertNil([self contacts:self.vm]);
    [WKApp shared].remoteConfig.profileContactInfoOn = YES;
    self.vm.channelInfo.robot = YES;
    XCTAssertNil([self contacts:self.vm]);
}

- (void)testFlagOffAndRobotHidePeer {
    [WKApp shared].remoteConfig.profileContactInfoOn = NO;
    XCTAssertNil([self contacts:self.vm]);
    [WKApp shared].remoteConfig.profileContactInfoOn = YES;
    self.vm.channelInfo.robot = YES;
    XCTAssertNil([self contacts:self.vm]);
}

- (void)testMissingNullAndInvalidFieldsDoNotBecomePlaceholders {
    Class modelClass = NSClassFromString(@"UserModel");
    for(NSDictionary *payload in @[@{}, @{@"phone":NSNull.null, @"email":NSNull.null},
                                   @{@"phone":@123, @"email":@[]},
                                   @{@"phone":@{}, @"email":@42}]) {
        id user = [modelClass fromMap:payload type:ModelMapTypeAPI];
        XCTAssertNil([user valueForKey:@"phone"]);
        XCTAssertNil([user valueForKey:@"email"]);
        [self.vm setValue:[user valueForKey:@"phone"] forKey:@"userPhone"];
        [self.vm setValue:[user valueForKey:@"email"] forKey:@"userEmail"];
        XCTAssertNil([self contacts:self.vm]);
    }
}

- (void)testEmptyFieldsHaveNoninteractivePlaceholders {
    id user = [NSClassFromString(@"UserModel") fromMap:@{@"phone":@"", @"email":@""} type:ModelMapTypeAPI];
    [self.vm setValue:[user valueForKey:@"phone"] forKey:@"userPhone"];
    [self.vm setValue:[user valueForKey:@"email"] forKey:@"userEmail"];
    NSArray *rows = [self contacts:self.vm][@"items"];
    XCTAssertEqual(rows.count, 2U);
    for(NSDictionary *row in rows) {
        XCTAssertGreaterThan([row[@"value"] length], 0U);
        XCTAssertNil(row[@"onClick"]);
        XCTAssertFalse([row[@"valueCopy"] boolValue]);
    }
}

- (void)testRevealAndConcealOnSameVM {
    NSDictionary *hidden = [self contacts:self.vm][@"items"][0];
    XCTAssertFalse([hidden[@"valueCopy"] boolValue]);
    XCTAssertNotEqualObjects(hidden[@"value"], @"13800001234");
    void (^reveal)(void) = hidden[@"onClick"];
    reveal();
    NSDictionary *revealed = [self contacts:self.vm][@"items"][0];
    XCTAssertEqualObjects(revealed[@"value"], @"13800001234");
    XCTAssertTrue([revealed[@"valueCopy"] boolValue]);
    [self.vm concealContactPhone];
    XCTAssertEqualObjects([self contacts:self.vm][@"items"][0][@"value"], hidden[@"value"]);
    XCTAssertFalse([[self contacts:self.vm][@"items"][0][@"valueCopy"] boolValue]);
}

- (void)testLeavingVCConcealsRetainedProfile {
    WKUserInfoVC *vc = [WKUserInfoVC new];
    vc.viewModel = self.vm;
    void (^reveal)(void) = [self contacts:self.vm][@"items"][0][@"onClick"];
    reveal();
    [vc viewWillDisappear:NO];
    XCTAssertFalse([[self contacts:self.vm][@"items"][0][@"valueCopy"] boolValue]);
}

- (void)testSimultaneousCardsKeepSeparateStateAfterEndpointReregistration {
    void (^reveal)(void) = [self contacts:self.vm][@"items"][0][@"onClick"];
    reveal();
    WKUserInfoVM *other = [self profileForUID:@"contact-test-other"];
    XCTAssertFalse([[self contacts:other][@"items"][0][@"valueCopy"] boolValue]);
    XCTAssertTrue([[self contacts:self.vm][@"items"][0][@"valueCopy"] boolValue]);
    [other setValue:@1 forKey:@"userAccountState"];
    XCTAssertNil([self contacts:other]);
    XCTAssertNotNil([self contacts:self.vm]);
}

- (void)testCountryCodeFallbackAndPreferredCode {
    self.vm.uid = [WKApp shared].loginInfo.uid;
    for(NSString *zone in @[@"+86", @"0086", @"86"]) {
        [self.vm setValue:zone forKey:@"userZone"];
        XCTAssertEqualObjects([self contacts:self.vm][@"items"][0][@"value"], @"+86 13800001234");
    }
    [self.vm setValue:@"44" forKey:@"userPhoneCountryCode"];
    XCTAssertEqualObjects([self contacts:self.vm][@"items"][0][@"value"], @"+44 13800001234");
    self.vm.uid = @"contact-test-peer";
    void (^reveal)(void) = [self contacts:self.vm][@"items"][0][@"onClick"];
    reveal();
    XCTAssertEqualObjects([self contacts:self.vm][@"items"][0][@"value"], @"13800001234");
}

- (void)testNullZoneAndCountryCodeAreSafe {
    id user = [NSClassFromString(@"UserModel") fromMap:@{@"zone":NSNull.null, @"phone_country_code":@[]} type:ModelMapTypeAPI];
    self.vm.uid = [WKApp shared].loginInfo.uid;
    [self.vm setValue:[user valueForKey:@"zone"] forKey:@"userZone"];
    [self.vm setValue:[user valueForKey:@"phoneCountryCode"] forKey:@"userPhoneCountryCode"];
    XCTAssertEqualObjects([self contacts:self.vm][@"items"][0][@"value"], @"13800001234");
}

- (void)testSingleRowHasNoTrailingSeparator {
    for(NSString *missingKey in @[@"userPhone", @"userEmail"]) {
        WKUserInfoVM *vm = [self profileForUID:@"contact-test-peer"];
        [vm setValue:nil forKey:missingKey];
        NSArray *rows = [self contacts:vm][@"items"];
        XCTAssertEqual(rows.count, 1U);
        XCTAssertFalse([rows[0][@"showBottomLine"] boolValue]);
    }
    NSArray *rows = [self contacts:self.vm][@"items"];
    XCTAssertTrue([rows[0][@"showBottomLine"] boolValue]);
    XCTAssertFalse([rows[1][@"showBottomLine"] boolValue]);
    XCTAssertEqualObjects(rows[0][@"bottomLeftSpace"], @17);
    XCTAssertEqualObjects(rows[0][@"bottomRightSpace"], @17);
}

- (void)testRemarkGapOnlyWhenContactsExist {
    NSArray *sections = [self.vm tableSectionMaps];
    XCTAssertEqual([sections[0][@"items"] count], 2U);
    XCTAssertEqualObjects(sections[1][@"height"], @10);
    [WKApp shared].remoteConfig.profileContactInfoOn = NO;
    XCTAssertEqualObjects([self.vm tableSectionMaps][0][@"height"], @0);
    [WKApp shared].remoteConfig.profileContactInfoOn = YES;
    [self.vm setValue:nil forKey:@"userPhone"];
    [self.vm setValue:nil forKey:@"userEmail"];
    XCTAssertEqualObjects([self.vm tableSectionMaps][0][@"height"], @0);
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"config callback on main queue"];
    dispatch_async(dispatch_get_main_queue(), ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:2];
}

- (void)testEarlyModuleCallbackDoesNotSuppressLaterConfigAndDuplicatesDoNotReload {
    WKContactConfigStub *config = [WKContactConfigStub new];
    config.requestSuccess = YES;
    config.requestAppModuleSuccess = YES;
    [WKApp.shared setValue:config forKey:@"remoteConfig"];
    WKUserInfoVC *vc = [WKUserInfoVC new];
    WKContactReloadSpy *vm = [WKContactReloadSpy new];
    vc.viewModel = vm;
    [vc requestContactInfoConfig];
    if(config.pendingCallback) { config.pendingCallback(nil); } // appmodule completed before appconfig
    [self drainMainQueue];
    XCTAssertEqual(vm.reloadCount, 0);
    config.profileContactInfoOn = YES;
    if(config.pendingCallback) { config.pendingCallback(nil); }
    if(config.pendingCallback) { config.pendingCallback(nil); }
    [self drainMainQueue];
    XCTAssertEqual(vm.reloadCount, 1);
}

- (void)testFailedConfigCallbackDoesNotStartAnotherRequest {
    WKContactConfigStub *config = [WKContactConfigStub new];
    config.requestSuccess = YES;
    config.requestAppModuleSuccess = YES;
    config.profileContactInfoOn = YES;
    [WKApp.shared setValue:config forKey:@"remoteConfig"];
    WKUserInfoVC *vc = [WKUserInfoVC new];
    WKContactReloadSpy *vm = [WKContactReloadSpy new];
    vc.viewModel = vm;
    [vc requestContactInfoConfig];
    config.requestSuccess = NO;
    config.profileContactInfoOn = NO;
    if(config.pendingCallback) { config.pendingCallback([NSError errorWithDomain:@"ContactTest" code:1 userInfo:nil]); }
    [self drainMainQueue];
    XCTAssertEqual(config.requestCount, 1);
    XCTAssertEqual(vm.reloadCount, 1);
}

- (void)testLaterConfigChangesRevokeCardAndResetRevealWithoutAnotherRequest {
    WKContactConfigStub *config = [WKContactConfigStub new];
    config.requestSuccess = YES;
    config.requestAppModuleSuccess = YES;
    config.profileContactInfoOn = YES;
    [WKApp.shared setValue:config forKey:@"remoteConfig"];
    WKUserInfoVC *vc = [WKUserInfoVC new];
    WKContactReloadSpy *spy = [WKContactReloadSpy new];
    vc.viewModel = spy;
    NSMutableDictionary *context = [spy valueForKey:@"contextDict"];
    context[@"phoneRevealed"] = @YES;
    [vc requestContactInfoConfig];
    XCTAssertNotNil([self contacts:self.vm]);
    // The initial request is over; later refreshes have no controller callback.
    config.pendingCallback = nil;
    config.profileContactInfoOn = NO;
    XCTAssertNil([self contacts:self.vm]);
    XCTAssertNil(context[@"phoneRevealed"]);
    XCTAssertTrue(spy.reloadCount > 0);
    NSInteger revokedCount = spy.reloadCount;
    config.profileContactInfoOn = NO;
    XCTAssertEqual(spy.reloadCount, revokedCount);
    config.profileContactInfoOn = YES;
    XCTAssertNotNil([self contacts:self.vm]);
    XCTAssertNil(context[@"phoneRevealed"]);
    XCTAssertEqual(spy.reloadCount, revokedCount + 1);
    XCTAssertEqual(config.requestCount, 1);
    __weak WKUserInfoVC *weakVC = vc;
    vc = nil;
    XCTAssertNil(weakVC);
    XCTAssertNoThrow(config.profileContactInfoOn = NO);
}

@end
