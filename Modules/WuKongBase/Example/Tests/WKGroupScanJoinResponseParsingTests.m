//
//  WKGroupScanJoinResponseParsingTests.m
//  LiMaoBase_Tests
//
//  YUJ-213 — 验证 scanjoin 成功回调对 response 字段（space_id / space_name /
//  group_name / is_external）解析的硬约束。这些约束全部是「grep-style」对
//  `WKGroupScanJoinVC.m` 源码做断言：
//
//    1. `.then(^(id _Nullable resp) {`  ← 不再是空签名 `.then(^{`，必须接住 body
//    2. 解析 `space_id` / `space_name` / `group_name` 三个字段
//    3. 识别 `is_external` 并在 `== 1` 时跳过跨 Space Toast
//    4. 保留 legacy fallback（weakSelf.targetSpaceId / targetSpaceName / groupName）
//    5. 公共群 / 同 Space 的 "不弹" 守卫落在 Helper，call-site 不重复判断
//       （避免 YUJ-170 round 2 的 "死代码" 陷阱）
//
//  跨端 i18n key 对齐（三端统一）：`group_join_cross_space_notice`。
//  Dialog 中必须出现该 key 的注释引用，便于跨仓检索。
//
//  为什么 grep 而不是端到端：`WKGroupScanJoinVC` 依赖真实 `WKNavigationManager`
//  / `WKAPIClient` / view hierarchy，单测里 stub 成本高；参见
//  `WKJoinGroupSuccessHelperTests` 已覆盖 helper 的纯逻辑行为。本组 UT 专注
//  "VC 里这段解析代码没被回归掉" 的防御。
//

@import XCTest;
#import <Foundation/Foundation.h>

@interface WKGroupScanJoinResponseParsingTests : XCTestCase
@property(nonatomic,copy) NSString *vcSource;
@property(nonatomic,copy) NSString *dialogSource;
@end

@implementation WKGroupScanJoinResponseParsingTests

- (void)setUp {
    [super setUp];

    // 文件相对路径：Tests.bundle → Podspec 源码树。用 __FILE__ 定位是最稳的
    // 方式，因为 Bundle resource 不包含 Classes/*.m。
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    NSString *tests    = [thisFile stringByDeletingLastPathComponent];
    NSString *example  = [tests stringByDeletingLastPathComponent];
    NSString *pod      = [example stringByDeletingLastPathComponent];
    NSString *classes  = [pod stringByAppendingPathComponent:@"WuKongBase/Classes/Sections/Group"];

    NSString *vcPath     = [classes stringByAppendingPathComponent:@"WKGroupScanJoinVC.m"];
    NSString *dialogPath = [classes stringByAppendingPathComponent:@"WKJoinGroupSuccessDialog.m"];

    NSError *err = nil;
    self.vcSource     = [NSString stringWithContentsOfFile:vcPath encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNotNil(self.vcSource, @"无法读取 WKGroupScanJoinVC.m: %@", err);
    self.dialogSource = [NSString stringWithContentsOfFile:dialogPath encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNotNil(self.dialogSource, @"无法读取 WKJoinGroupSuccessDialog.m: %@", err);
}

#pragma mark - scanjoin response body shape

- (void)testScanJoinThenBlock_AcceptsResponseBody_NotEmptySignature {
    // .then(^{ ... }) 会丢掉 body — 必须是接住参数的形式。
    XCTAssertFalse([self.vcSource containsString:@".then(^{"],
                   @"scanjoin 不能再用空签名 .then(^{ ... })，必须接收 resp");
    XCTAssertTrue([self.vcSource containsString:@".then(^(id _Nullable resp)"] ||
                  [self.vcSource containsString:@".then(^(NSDictionary"],
                   @"scanjoin then 必须接住 response body 才能取 space_id/space_name");
}

- (void)testScanJoinParses_SpaceId_SpaceName_GroupName {
    XCTAssertTrue([self.vcSource containsString:@"space_id"],
                  @"scanjoin 需从响应读取 space_id (PR#1250 契约)");
    XCTAssertTrue([self.vcSource containsString:@"space_name"],
                  @"scanjoin 需从响应读取 space_name");
    XCTAssertTrue([self.vcSource containsString:@"group_name"],
                  @"scanjoin 需从响应读取 group_name");
}

- (void)testScanJoinRespectsIsExternal_SkipsCrossSpaceToast {
    XCTAssertTrue([self.vcSource containsString:@"is_external"],
                  @"scanjoin 必须解析 is_external，满足硬约束"
                  @"「is_external=1 不走此 Toast」");
    // 具体形态：is_external 识别 + 在 isExternal 为真时跳过 computeAndSave。
    NSRange externalRange = [self.vcSource rangeOfString:@"isExternal"];
    XCTAssertTrue(externalRange.location != NSNotFound,
                  @"预期存在 isExternal 局部变量/守卫");
    XCTAssertTrue([self.vcSource containsString:@"if (!isExternal)"] ||
                  [self.vcSource containsString:@"!isExternal"],
                  @"预期以 !isExternal 作为进入 computeAndSave 的前置");
}

- (void)testScanJoinStillFallsBackToLegacyVCProperties {
    // 兼容：旧服务端没有响应字段时，legacy 通道（扫码解析器注入的
    // self.targetSpaceId / targetSpaceName / groupName）仍然可以兜底。
    XCTAssertTrue([self.vcSource containsString:@"weakSelf.targetSpaceId"],
                  @"仍需 fallback 到 VC 属性以兼容旧后端");
    XCTAssertTrue([self.vcSource containsString:@"weakSelf.targetSpaceName"],
                  @"仍需 fallback 到 VC 属性以兼容旧后端");
    XCTAssertTrue([self.vcSource containsString:@"weakSelf.groupName"],
                  @"仍需 fallback 到 VC 属性以兼容旧后端");
}

- (void)testScanJoinStillCallsComputeAndSaveHelper {
    // 避免回归：同/跨 Space 判定仍然下沉到 WKJoinGroupSuccessHelper，
    // call-site 不重复实现 (YUJ-170 round 2 死代码教训)。
    XCTAssertTrue([self.vcSource containsString:@"computeAndSaveWithGroupNo"],
                  @"跨 Space 判定必须委托给 Helper，不能 call-site 重写");
    XCTAssertTrue([self.vcSource containsString:@"WKJoinGroupSuccessHelper"],
                  @"未见 Helper 引用");
}

- (void)testScanJoinPopsBackOnCrossSpaceSaved_KeepsPushOnSameSpace {
    XCTAssertTrue([self.vcSource containsString:@"popViewControllerAnimated"],
                  @"跨 Space 成功写通知后必须 pop 回主列表，由主列表消费 Dialog");
    XCTAssertTrue([self.vcSource containsString:@"replacePushViewController:vc animated:YES"],
                  @"同 Space / external 仍然直接进群（走旧行为）");
}

#pragma mark - i18n key 对齐

- (void)testDialogDocumentsUnifiedI18NKey {
    // 三端文案 i18n key 统一 `group_join_cross_space_notice`。iOS 的
    // Localizable.strings 用"中文即 key"约定，所以我们在代码注释里记录
    // 逻辑 key 便于跨仓 grep。
    XCTAssertTrue([self.dialogSource containsString:@"group_join_cross_space_notice"],
                  @"Dialog 中必须出现统一 i18n 逻辑 key 的引用，便于跨端对齐");
}

@end
