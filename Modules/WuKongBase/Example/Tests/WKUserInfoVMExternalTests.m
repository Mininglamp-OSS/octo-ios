//
//  WKUserInfoVMExternalTests.m
//  LiMaoBase_Tests
//
//  — WKUserInfoVM.isExternalForViewer viewer-relative 判定单元测试。
//  直接锁住「外部成员 → UserInfo 页不显示申请加好友按钮」的判定规则。
//
//  参考：
//    - Web PR#1013/#1091 `resolveExternalForViewer` — 同规则
//    - Android PR#135 ExternalViewerResolver.isExternalForViewer — 跨端对齐
//
//  覆盖：
//    1. 群内路径 memberOfUser.extra.home_space_id ≠ viewer → external=YES
//    2. 群内路径 memberOfUser.extra.home_space_id == viewer → external=NO
//    3. 非 Space 模式（currentSpaceId 空） → external=NO（避免误伤单 Space）
//    4. Legacy fallback：member.extra.is_external=1 + 无 home_space_id → external=YES
//

@import XCTest;
@import UIKit;
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKUserInfoVM.h"
#import "WKExternalViewerResolver.h"

@interface WKUserInfoVMExternalTests : XCTestCase
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKUserInfoVMExternalTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
    [d setObject:@"spaceViewer" forKey:@"currentSpaceId"];
}

- (void)tearDown {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (self.savedViewerSpaceId) {
        [d setObject:self.savedViewerSpaceId forKey:@"currentSpaceId"];
    } else {
        [d removeObjectForKey:@"currentSpaceId"];
    }
    [super tearDown];
}

- (WKChannelMember *)memberWithExtras:(NSDictionary *)extras {
    WKChannelMember *m = [WKChannelMember new];
    m.memberUid = @"u1";
    m.memberName = @"Alice";
    m.memberAvatar = @"";
    m.extra = extras ? [extras mutableCopy] : [NSMutableDictionary dictionary];
    return m;
}

#pragma mark - 1. 群内 home_space_id ≠ viewer → external=YES

- (void)testGroupMember_HomeSpaceDiffersFromViewer_IsExternal {
    WKUserInfoVM *vm = [[WKUserInfoVM alloc] init];
    vm.memberOfUser = [self memberWithExtras:@{@"home_space_id": @"spaceA",
                                                @"home_space_name": @"OctoWork"}];
    XCTAssertTrue([vm isExternalForViewer]);
}

#pragma mark - 2. 群内 home_space_id == viewer → external=NO

- (void)testGroupMember_HomeSpaceMatchesViewer_IsNotExternal {
    WKUserInfoVM *vm = [[WKUserInfoVM alloc] init];
    vm.memberOfUser = [self memberWithExtras:@{@"home_space_id": @"spaceViewer",
                                                @"home_space_name": @"OctoWork"}];
    XCTAssertFalse([vm isExternalForViewer]);
}

#pragma mark - 3. 非 Space 模式（currentSpaceId 空） → external=NO

- (void)testNoSpaceMode_ReturnsNotExternal {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:@"currentSpaceId"];

    WKUserInfoVM *vm = [[WKUserInfoVM alloc] init];
    vm.memberOfUser = [self memberWithExtras:@{@"home_space_id": @"spaceA"}];
    // 非 Space 模式下不做跨 Space 判定，保留原有 isFriend / 申请加好友行为
    XCTAssertFalse([vm isExternalForViewer]);
}

#pragma mark - 4. Legacy fallback：is_external=1 + 无 home_space_id → external=YES

- (void)testLegacyExternalFlag_FallbackToExternal {
    WKUserInfoVM *vm = [[WKUserInfoVM alloc] init];
    vm.memberOfUser = [self memberWithExtras:@{@"is_external": @(1),
                                                @"source_space_name": @"CustomerCo"}];
    XCTAssertTrue([vm isExternalForViewer]);
}

#pragma mark - 5. 无 memberOfUser + 无 user home_space_id cache → external=NO

- (void)testNoMemberNoCache_ReturnsNotExternal {
    WKUserInfoVM *vm = [[WKUserInfoVM alloc] init];
    // 未 loadPersonChannelInfo，也没有 fromChannel member cache
    XCTAssertFalse([vm isExternalForViewer]);
}

@end
