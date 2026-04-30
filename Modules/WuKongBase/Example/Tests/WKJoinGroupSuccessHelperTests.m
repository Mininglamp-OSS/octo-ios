//
//  WKJoinGroupSuccessHelperTests.m
//  LiMaoBase_Tests
//
//  YUJ-141 (iOS) — `WKJoinGroupSuccessHelper` 单元测试。对齐 Web PR#1068 的
//  `computeAndSaveJoinSuccess` + `consumeJoinSuccessNotice` 契约：
//    - 只在「viewer 与 target 不同 Space」时保存跨 Space 通知；
//    - consume 是一次性（读后即清）；
//    - 缺必要字段 → 不保存，不抛异常；
//    - UserDefaults 过期（> 24h）→ 丢弃不重放。
//

@import XCTest;
#import "WKJoinGroupSuccessHelper.h"

// 内部常量镜像 —— 与 .m 里 `kWKJoinSuccessNoticeKey` 对齐；
// 如果 key 改了，这里会第一时间在测试里炸出来。
static NSString * const kNoticeKey = @"WKJoinGroupSuccessNoticeV1";
static NSString * const kViewerKey = @"currentSpaceId";

@interface WKJoinGroupSuccessHelperTests : XCTestCase
@end

@implementation WKJoinGroupSuccessHelperTests

- (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kNoticeKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kViewerKey];
    [WKJoinGroupSuccessHelper clear];
}

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kNoticeKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kViewerKey];
    [WKJoinGroupSuccessHelper clear];
    [super tearDown];
}

#pragma mark - computeAndSave

- (void)testComputeAndSave_CrossSpace_Persisted {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];

    BOOL saved = [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                         targetSpaceId:@"space_target"
                                                             groupName:@"测试群"
                                                             spaceName:@"OctoWork"];
    XCTAssertTrue(saved, @"跨 Space 加群应当保存通知");

    WKJoinGroupSuccessNotice *notice = [WKJoinGroupSuccessHelper peekNotice];
    XCTAssertNotNil(notice);
    XCTAssertEqualObjects(notice.groupNo, @"g1");
    XCTAssertEqualObjects(notice.targetSpaceId, @"space_target");
    XCTAssertEqualObjects(notice.viewerSpaceId, @"space_viewer");
    XCTAssertEqualObjects(notice.groupName, @"测试群");
    XCTAssertEqualObjects(notice.spaceName, @"OctoWork");
}

- (void)testComputeAndSave_SameSpace_NotPersisted {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_same" forKey:kViewerKey];

    BOOL saved = [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                         targetSpaceId:@"space_same"
                                                             groupName:@"测试群"
                                                             spaceName:@"同 Space"];
    XCTAssertFalse(saved, @"同 Space 加群不应保存跨 Space 通知");
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
}

- (void)testComputeAndSave_NoViewerSpaceId_NotPersisted {
    // viewer 未设置 currentSpaceId（罕见，但防御：空 from → 切换按钮无意义）
    BOOL saved = [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                         targetSpaceId:@"space_target"
                                                             groupName:@"测试群"
                                                             spaceName:@"OctoWork"];
    XCTAssertFalse(saved);
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
}

- (void)testComputeAndSave_MissingGroupNo_NotPersisted {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];
    XCTAssertFalse([WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:nil
                                                          targetSpaceId:@"space_target"
                                                              groupName:@"x"
                                                              spaceName:@"y"]);
    XCTAssertFalse([WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@""
                                                          targetSpaceId:@"space_target"
                                                              groupName:@"x"
                                                              spaceName:@"y"]);
    XCTAssertFalse([WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"   "
                                                          targetSpaceId:@"space_target"
                                                              groupName:@"x"
                                                              spaceName:@"y"]);
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
}

- (void)testComputeAndSave_MissingTargetSpaceId_NotPersisted {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];
    XCTAssertFalse([WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                          targetSpaceId:nil
                                                              groupName:@"x"
                                                              spaceName:@"y"]);
    XCTAssertFalse([WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                          targetSpaceId:@""
                                                              groupName:@"x"
                                                              spaceName:@"y"]);
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
}

- (void)testComputeAndSave_NilSpaceName_StillSavesWithNil {
    // spaceName 允许缺失（老后端兼容），UI 层会用"其它"兜底。
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];
    BOOL saved = [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                                         targetSpaceId:@"space_target"
                                                             groupName:@"group"
                                                             spaceName:nil];
    XCTAssertTrue(saved);
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice].spaceName);
}

#pragma mark - consume / clear

- (void)testConsumeNotice_ReadOnce_ThenCleared {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];
    [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                          targetSpaceId:@"space_target"
                                              groupName:@"group"
                                              spaceName:@"OctoWork"];

    WKJoinGroupSuccessNotice *first = [WKJoinGroupSuccessHelper consumeNotice];
    XCTAssertNotNil(first);
    XCTAssertEqualObjects(first.groupNo, @"g1");

    WKJoinGroupSuccessNotice *second = [WKJoinGroupSuccessHelper consumeNotice];
    XCTAssertNil(second, @"consume 必须一次性，防止主列表重复弹窗");
}

- (void)testClear_RemovesInMemoryAndPersistedNotice {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];
    [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                          targetSpaceId:@"space_target"
                                              groupName:@"group"
                                              spaceName:@"OctoWork"];
    XCTAssertNotNil([WKJoinGroupSuccessHelper peekNotice]);

    [WKJoinGroupSuccessHelper clear];
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
    XCTAssertNil([[NSUserDefaults standardUserDefaults] dictionaryForKey:kNoticeKey]);
}

- (void)testComputeAndSave_OverwritesPreviousNotice {
    // 用户连续点了两次邀请链接（加两个外部群），后一次要覆盖前一次的 notice —
    // 和 Web sessionStorage 语义一致（同 key 覆盖）。
    [[NSUserDefaults standardUserDefaults] setObject:@"space_viewer" forKey:kViewerKey];

    [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g1"
                                          targetSpaceId:@"space_a"
                                              groupName:@"group1"
                                              spaceName:@"A"];
    [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:@"g2"
                                          targetSpaceId:@"space_b"
                                              groupName:@"group2"
                                              spaceName:@"B"];
    WKJoinGroupSuccessNotice *notice = [WKJoinGroupSuccessHelper peekNotice];
    XCTAssertEqualObjects(notice.groupNo, @"g2");
    XCTAssertEqualObjects(notice.targetSpaceId, @"space_b");
    XCTAssertEqualObjects(notice.spaceName, @"B");
}

#pragma mark - UserDefaults 兜底 / 冷启动

- (void)testPeekNotice_ColdStart_RestoreFromUserDefaults {
    // 模拟 app 重启：手动写 NSUserDefaults，内存态为空。
    NSDictionary *dict = @{
        @"groupNo": @"g9",
        @"groupName": @"冷启群",
        @"targetSpaceId": @"space_t",
        @"spaceName": @"Target",
        @"viewerSpaceId": @"space_v",
        @"savedAt": @([[NSDate date] timeIntervalSince1970]),
    };
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kNoticeKey];

    WKJoinGroupSuccessNotice *notice = [WKJoinGroupSuccessHelper peekNotice];
    XCTAssertNotNil(notice);
    XCTAssertEqualObjects(notice.groupNo, @"g9");
    XCTAssertEqualObjects(notice.targetSpaceId, @"space_t");
}

- (void)testPeekNotice_ExpiredOlderThan24h_Dropped {
    NSTimeInterval old = [[NSDate date] timeIntervalSince1970] - (25 * 60 * 60); // 25h
    NSDictionary *dict = @{
        @"groupNo": @"g_old",
        @"targetSpaceId": @"space_t",
        @"savedAt": @(old),
    };
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kNoticeKey];

    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice], @"24h 前的 notice 不应该再弹");
    // 并且该调用应顺手清掉残留
    XCTAssertNil([[NSUserDefaults standardUserDefaults] dictionaryForKey:kNoticeKey]);
}

- (void)testPeekNotice_CorruptedUserDefaults_IgnoredGracefully {
    [[NSUserDefaults standardUserDefaults] setObject:@{} forKey:kNoticeKey];
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);

    [[NSUserDefaults standardUserDefaults] setObject:@{@"groupNo": @123} forKey:kNoticeKey];
    XCTAssertNil([WKJoinGroupSuccessHelper peekNotice]);
}

@end
