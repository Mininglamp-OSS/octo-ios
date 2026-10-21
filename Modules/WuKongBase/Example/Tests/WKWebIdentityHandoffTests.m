// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

// WKWebIdentityHandoff 纯函数契约测试（依赖 WKApp.config.apiBaseUrl /
// loginInfo.token，测试内注入 WKApp 单例状态并在 tearDown 恢复原值——
// 单例状态是进程共享的，直接 clear 会删掉持久化登录归档并污染后续
// 测试类，评审 P2 指出必须保存/恢复而非清除）。

@import XCTest;
#import "WKApp.h"
#import "WKWebIdentityHandoff.h"

@interface WKWebIdentityHandoffTests : XCTestCase
@end

@implementation WKWebIdentityHandoffTests

static NSString * const kBase = @"https://octo.example/api/v1/";

// 被本类触碰的单例状态原值，tearDown 恢复。
static NSString *savedBase = nil;
static NSString *savedToken = nil;
static NSString *savedUid = nil;

- (void)setUp {
    [super setUp];
    savedBase = [WKApp shared].config.apiBaseUrl;
    savedToken = [WKLoginInfo shared].token;
    savedUid = [WKLoginInfo shared].uid;
    [WKApp shared].config.apiBaseUrl = kBase;
    WKLoginInfo *info = [WKLoginInfo shared];
    info.token = @"test-token";
    info.uid = @"uid-1";
}

- (void)tearDown {
    // 恢复原值而非 clear（clear 会删除持久化 LoginInfoKey 归档，影响其它
    // 测试类与本进程登录态）。本类未触碰的字段保持原样。
    [WKApp shared].config.apiBaseUrl = savedBase;
    WKLoginInfo *info = [WKLoginInfo shared];
    info.token = savedToken;
    info.uid = savedUid;
    [super tearDown];
}

#pragma mark - handoffURLForURL: 门控

- (void)testSameOrigin_acceptsAndAppendsSid {
    NSURL *out = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/s/ST1?sp=default"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/s/ST1?sp=default&sid=ios");
    // 默认端口隐式归一
    XCTAssertTrue([[WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example:443/d/abc"]].absoluteString containsString:@"sid=ios"]);
}

- (void)testRejectsCrossOriginUserinfoAndMissingBase {
    NSString *base = [WKApp shared].config.apiBaseUrl;
    [WKApp shared].config.apiBaseUrl = @"";
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc"]]);
    [WKApp shared].config.apiBaseUrl = base;

    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:nil]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example.evil/d/abc"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"http://octo.example/d/abc"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example:8443/d/abc"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://user@octo.example/d/abc"]]);
}

#pragma mark - 路径白名单（P1：注入范围从全 origin 收窄到免登路由）

- (void)testHandoffPathAllowlist {
    // 白名单内：/s/{task_no}（服务端 summaryDeepLink 形状）、/d/、/ppt/d/、/docs/*/present
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/s/TN_20260713_abcd?sp=spc_x"]]);
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc123"]]);
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/ppt/d/abc123"]]);
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/docs/abc123/present"]]);
    // 末尾一个斜杠允许
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc123/"]]);
}

- (void)testNonAllowlistPathsDenied {
    // 白名单外一律不注入：report（生产形状）、同 origin 其它 H5/文件路由、
    // 相邻前缀、嵌套路径、多段 id、空 id。
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/api/v1/report/html?channel_id=x"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/report.html?channel_id=x"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/file/preview/image/x.png"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/some/other/page"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/ss/abc"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc/extra"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/a/b"]]);
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/"]]);
    // id 含非法字符（/ . 之外再拒非白名单字符集）
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc$x"]]);
    // 路径带百分号编码不匹配白名单（白名单只认字面 id 字符）
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/%61bc"]]);
}

#pragma mark - sid 替换 / 编码保留

- (void)testExistingSidReplacedEvenWhenEmpty {
    // 已有 sid（含空值）一律替换为 ios，避免 web 端取第一个空值造成分桶错位。
    NSURL *out = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?sid=web"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/d/abc?sid=ios");
    NSURL *empty = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?sid="]];
    XCTAssertEqualObjects(empty.absoluteString, @"https://octo.example/d/abc?sid=ios");
}

- (void)testMultipleSidAllReplaced {
    // 多个 sid 只保留一个 ios：web 端 URLSearchParams.get 取第一个之外的场景
    // （getAll / 遍历）不应看到残留旧 sid。
    NSURL *out = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?sid=a&x=1&sid=b"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/d/abc?x=1&sid=ios");
}

- (void)testExistingPercentEncodingPreserved {
    // 追加/替换 sid 不得改动既有参数的编码字节：%2B（+）不能被 queryItems
    // 往返改写成空格语义的 +，%3A 不能变 :。
    NSURL *out = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?q=a%2Bb%3Ac&sid=web"]];
    XCTAssertTrue([out.absoluteString containsString:@"q=a%2Bb%3Ac"], @"既有参数须字节级保留，实际：%@", out.absoluteString);
    XCTAssertTrue([out.absoluteString containsString:@"sid=ios"]);
}

#pragma mark - identityJavaScriptForURL:

- (void)testScriptWritesKeysAndRuntimeGuards {
    NSString *js = [WKWebIdentityHandoff identityJavaScriptForURL:[NSURL URLWithString:@"https://octo.example/s/ST1"]];
    XCTAssertNotNil(js);
    XCTAssertTrue([js containsString:@"tokenios"]);
    XCTAssertTrue([js containsString:@"uidios"]);
    XCTAssertTrue([js containsString:@"nameios"]);
    XCTAssertTrue([js containsString:@"octo.session.sid"]);
    // 运行时 origin 守卫存在：后续跨域导航不写凭证
    XCTAssertTrue([js containsString:@"location.hostname"]);
    // 运行时路径白名单存在：白名单外路由（report/外链/重定向落点）不写凭证
    XCTAssertTrue([js containsString:@"pathname"]);
    XCTAssertTrue([js containsString:@"present"]);
}

- (void)testScriptNilWhenLoggedOut {
    NSString *saved = [WKLoginInfo shared].token;
    [WKLoginInfo shared].token = @"";
    XCTAssertNil([WKWebIdentityHandoff identityJavaScriptForURL:[NSURL URLWithString:@"https://octo.example/s/ST1"]]);
    [WKLoginInfo shared].token = saved;
}

#pragma mark - WKJSONString 转义契约（Octo-Q P2：转义须在值真正到达转义器的
// 路径上测——经 sid 注入的恶意值在进转义前已被替换成 ios，那类断言恒绿）

- (void)testJSONStringEscapesQuoteBackslashNewline {
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:@"a\"b"], @"\"a\\\"b\"");
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:@"a\\b"], @"\"a\\\\b\"");
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:@"a\nb"], @"\"a\\nb\"");
    // 逃逸探针：'+(expr)+' 必须整体包在字符串字面量里，不能成为可执行代码
    NSString *evil = @"x'+(globalThis.sidExecuted=true)+'";
    NSString *out = [WKWebIdentityHandoff JSONString:evil];
    XCTAssertTrue([out hasPrefix:@"\""] && [out hasSuffix:@"\""], @"输出必须是带引号的 JS 字符串字面量");
    XCTAssertFalse([out containsString:@"';"], @"引号必须被转义，不得提前终止字面量");
}

- (void)testJSONStringEscapesLineSeparators {
    // U+2028/U+2029 在 JS 字符串字面量里是行终止符（ES2019 前），必须转义
    NSString *out = [WKWebIdentityHandoff JSONString:@"a b c"];
    XCTAssertFalse([out containsString:@" "], @"U+2028 必须转义");
    XCTAssertFalse([out containsString:@" "], @"U+2029 必须转义");
    XCTAssertTrue([out containsString:@"\\u2028"]);
    XCTAssertTrue([out containsString:@"\\u2029"]);
}

- (void)testJSONStringHandlesNilAndEmpty {
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:nil], @"\"\"");
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:@""], @"\"\"");
    // 非 ASCII 原样保留（NSJSONSerialization 不转义非 ASCII）
    XCTAssertEqualObjects([WKWebIdentityHandoff JSONString:@"用户"], "\"用户\"");
}

#pragma mark - sanitizedURLForExternalUse:

- (void)testSanitizedURLStripsSidOnly {
    NSURL *out = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://octo.example/s/ST1?sp=a&sid=ios&x=1"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/s/ST1?sp=a&x=1");
    // 无 sid 时原样返回
    NSURL *clean = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://octo.example/s/ST1?sp=a"]];
    XCTAssertEqualObjects(clean.absoluteString, @"https://octo.example/s/ST1?sp=a");
    XCTAssertNil([WKWebIdentityHandoff sanitizedURLForExternalUse:nil]);
}

- (void)testSanitizedURLPercentEncodingPreserved {
    // 剥 sid 不经过 queryItems 往返：其余参数的 %2B / %3A 字节原样保留。
    NSURL *out = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://octo.example/s/ST1?q=a%2Bb%3Ac&sid=ios"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/s/ST1?q=a%2Bb%3Ac");
}

- (void)testSanitizedURLNoDanglingQuestionMark {
    // sid 是唯一 query item 时剥掉后不得留下孤立 "?"
    NSURL *out = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://octo.example/s/ST1?sid=ios"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/s/ST1");
}

- (void)testSanitizedURLPreservesThirdPartySid {
    // P1 收窄：只有「同源 + 免登白名单路由」上的 sid 是我们注入的，才剥；
    // 第三方页面自带的 sid（跨域、或同源但白名单外路由）是外链自身业务
    // 参数，必须原样保留，一个字节不动。
    NSURL *crossOrigin = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://vendor.example/page?sid=vendor-session&x=1"]];
    XCTAssertEqualObjects(crossOrigin.absoluteString, @"https://vendor.example/page?sid=vendor-session&x=1");
    NSURL *sameOriginOffPath = [WKWebIdentityHandoff sanitizedURLForExternalUse:[NSURL URLWithString:@"https://octo.example/report.html?sid=web-ctx"]];
    XCTAssertEqualObjects(sameOriginOffPath.absoluteString, @"https://octo.example/report.html?sid=web-ctx");
}

@end
