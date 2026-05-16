//
//  WKGroupScanJoinResponseParsingTests.m
//  LiMaoBase_Tests
//
//  — 验证 scanjoin 成功回调对 response 字段（space_id / space_name /
//  group_name / is_external）解析的硬约束。这些约束全部是「grep-style」对
//  `WKGroupScanJoinVC.m` 源码做断言：
//
//    1. `.then(^(id _Nullable resp) {`  ← 不再是空签名 `.then(^{`，必须接住 body
//    2. 解析 `space_id` / `space_name` / `group_name` 三个字段
//    3. 识别 `is_external` 并在 `== 1` 时跳过跨 Space Toast
//    4. 保留 legacy fallback（weakSelf.targetSpaceId / targetSpaceName / groupName）
//    5. 公共群 / 同 Space 的 "不弹" 守卫落在 Helper，call-site 不重复判断
//       （避免 round 2 的 "死代码" 陷阱）
//
//  Phase 2 — 新增 need_space 响应的解析 + pendingGroupInvite 落盘与
//  重放两阶段测试：
//
//    6. 识别 `status == "need_space"` 响应；命中时不走 computeAndSave / 不
//       replacePush (避免误把零 Space 用户推进群 / 弹跨 Space Toast)
//    7. 命中 need_space 时把群邀请上下文落盘到 NSUserDefaults `pendingGroupInvite`
//       （含 group_no / auth_code / name / avatar / member_count / is_member /
//        space_id / space_name）
//    8. 命中 need_space 时 push `WKSpaceGateVC`（通过 WKPOINT_SPACEGATE_SHOW
//        +  mode=push 跨 module 拉起）
//    9. `WKSpaceGateVC::enterApp` 调用 WKPOINT_LOGIN_SUCCESS 之后必须
//       replayPendingGroupInviteIfAny，一次性消费 NSUserDefaults，并通过
//       WKPOINT_SCAN_HANDLER_JOIN_GROUP 重放扫码 handler
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
@property(nonatomic,copy) NSString *spaceGateSource;
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
    NSString *modulesDir = [[pod stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    // modulesDir = .../Modules ; WKSpaceGateVC 在 Modules/WuKongLogin/WuKongLogin/Classes/Login/Src
    NSString *spaceGatePath = [modulesDir stringByAppendingPathComponent:
                               @"WuKongLogin/WuKongLogin/Classes/Login/Src/WKSpaceGateVC.m"];

    NSString *vcPath     = [classes stringByAppendingPathComponent:@"WKGroupScanJoinVC.m"];
    NSString *dialogPath = [classes stringByAppendingPathComponent:@"WKJoinGroupSuccessDialog.m"];

    NSError *err = nil;
    self.vcSource     = [NSString stringWithContentsOfFile:vcPath encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNotNil(self.vcSource, @"无法读取 WKGroupScanJoinVC.m: %@", err);
    self.dialogSource = [NSString stringWithContentsOfFile:dialogPath encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNotNil(self.dialogSource, @"无法读取 WKJoinGroupSuccessDialog.m: %@", err);
    self.spaceGateSource = [NSString stringWithContentsOfFile:spaceGatePath encoding:NSUTF8StringEncoding error:&err];
    XCTAssertNotNil(self.spaceGateSource, @"无法读取 WKSpaceGateVC.m: %@", err);
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
    // call-site 不重复实现 (round 2 死代码教训)。
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

#pragma mark - Phase 2: need_space 分支 & pendingGroupInvite 落盘

- (void)testScanJoinParses_NeedSpaceStatus {
    // 后端 dmworkim PR#1320 契约：无 Space 用户 scanjoin 返回 status=need_space。
    XCTAssertTrue([self.vcSource containsString:@"need_space"],
                  @"scanjoin 必须识别 status=need_space (dmworkim PR#1320 契约)");
    XCTAssertTrue([self.vcSource containsString:@"respStatus"] ||
                  [self.vcSource containsString:@"status"],
                  @"scanjoin 必须从响应读取 status 字段");
}

- (void)testScanJoin_NeedSpace_SavesPendingGroupInviteToNSUserDefaults {
    // 命中 need_space 时把群邀请上下文暂存到 NSUserDefaults key `pendingGroupInvite`。
    XCTAssertTrue([self.vcSource containsString:@"pendingGroupInvite"],
                  @"scanjoin need_space 分支必须把邀请上下文暂存到"
                  @"NSUserDefaults key `pendingGroupInvite`（契约）");
    XCTAssertTrue([self.vcSource containsString:@"NSUserDefaults"],
                  @"need_space 分支必须使用 NSUserDefaults 暂存");
    // 关键字段都要落盘，Space Gate 重放时要用。
    for (NSString *key in @[@"group_no", @"auth_code"]) {
        NSString *needle = [NSString stringWithFormat:@"@\"%@\"", key];
        XCTAssertTrue([self.vcSource containsString:needle],
                      @"pendingGroupInvite 字典必须包含 %@ 字段 (Space Gate 重放用)", key);
    }
}

- (void)testScanJoin_NeedSpace_PushesSpaceGateVC {
    // 命中 need_space 后必须拉起 WKSpaceGateVC；跨 module 走 WKPOINT_SPACEGATE_SHOW
    // 点。参数 mode=push 保留当前导航栈，方便加 Space 完成后重放。
    XCTAssertTrue([self.vcSource containsString:@"WKPOINT_SPACEGATE_SHOW"],
                  @"need_space 分支必须 invoke WKPOINT_SPACEGATE_SHOW 拉起 SpaceGateVC");
    XCTAssertTrue([self.vcSource containsString:@"\"push\""] ||
                  [self.vcSource containsString:@"@\"push\""],
                  @"need_space 分支必须用 mode=push，不能 resetRootViewController");
}

- (void)testScanJoin_NeedSpace_DoesNotCallComputeAndSaveOrReplacePush {
    // 命中 need_space 后不能继续走 computeAndSave（跨 Space Toast 逻辑）也不能
    // replacePush 进群 — 这是硬约束，零 Space 用户必须先加 Space。我们把
    // `return` 放在 need_space 分支的尾部，以此确保控制流提前结束。
    NSRange needSpaceRange = [self.vcSource rangeOfString:@"need_space"];
    XCTAssertTrue(needSpaceRange.location != NSNotFound, @"找不到 need_space 分支");
    // 找到 need_space 分支的 return 点 — 用 "return;" 字面检查（若无 return，
    // 流会往下走到 replacePush，这是回归）。
    NSRange searchRange = NSMakeRange(needSpaceRange.location, self.vcSource.length - needSpaceRange.location);
    NSRange returnRange = [self.vcSource rangeOfString:@"return;" options:0 range:searchRange];
    XCTAssertTrue(returnRange.location != NSNotFound,
                  @"need_space 分支必须以 return; 结束控制流，否则会继续走 computeAndSave");
    NSRange computeRangeAfter = [self.vcSource rangeOfString:@"computeAndSaveWithGroupNo"
                                                    options:0
                                                      range:NSMakeRange(needSpaceRange.location,
                                                                        returnRange.location - needSpaceRange.location)];
    XCTAssertEqual(computeRangeAfter.location, NSNotFound,
                   @"need_space 分支内不得调用 computeAndSaveWithGroupNo（跨 Space Toast 不适用于零 Space 用户）");
}

#pragma mark - Phase 2: WKSpaceGateVC replay 侧

- (void)testSpaceGate_Enter_ReplaysPendingGroupInvite {
    // 加 Space 成功（enterApp）后必须调用 replayPendingGroupInviteIfAny，
    // 一次性消费 NSUserDefaults 并通过 WKPOINT_SCAN_HANDLER_JOIN_GROUP 重放。
    XCTAssertTrue([self.spaceGateSource containsString:@"replayPendingGroupInviteIfAny"],
                  @"WKSpaceGateVC 必须定义 replayPendingGroupInviteIfAny 方法（）");
    XCTAssertTrue([self.spaceGateSource containsString:@"pendingGroupInvite"],
                  @"WKSpaceGateVC 必须读 NSUserDefaults key `pendingGroupInvite`");
    XCTAssertTrue([self.spaceGateSource containsString:@"removeObjectForKey:@\"pendingGroupInvite\""],
                  @"replay 必须做读后即清 (一次性消费)");
    XCTAssertTrue([self.spaceGateSource containsString:@"WKPOINT_SCAN_HANDLER_JOIN_GROUP"],
                  @"replay 必须走 WKPOINT_SCAN_HANDLER_JOIN_GROUP 扫码 handler 重试入群");
}

- (void)testSpaceGate_EnterApp_CallsReplayAfterLoginSuccess {
    // enterApp 先 invoke WKPOINT_LOGIN_SUCCESS（触发 resetRootViewController 到
    // 首页），然后再调用 replay — 顺序很重要，否则 push 到老栈会被 reset 丢弃。
    NSRange loginSuccessRange = [self.spaceGateSource rangeOfString:@"invoke:WKPOINT_LOGIN_SUCCESS"];
    XCTAssertTrue(loginSuccessRange.location != NSNotFound,
                  @"enterApp 必须 invoke WKPOINT_LOGIN_SUCCESS");
    NSRange replayRange = [self.spaceGateSource rangeOfString:@"replayPendingGroupInviteIfAny"
                                                      options:NSLiteralSearch
                                                        range:NSMakeRange(loginSuccessRange.location,
                                                                          self.spaceGateSource.length - loginSuccessRange.location)];
    XCTAssertTrue(replayRange.location != NSNotFound,
                  @"replayPendingGroupInviteIfAny 必须在 WKPOINT_LOGIN_SUCCESS 之后调用");
}

@end
