// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

// WKWebIdentityHandoff 纯函数契约测试（依赖 WKApp.config.apiBaseUrl /
// loginInfo.token，测试内直接注入 WKApp 单例状态）。

@import XCTest;
#import "WKApp.h"
#import "WKWebIdentityHandoff.h"

@interface WKWebIdentityHandoffTests : XCTestCase
@end

@implementation WKWebIdentityHandoffTests

static NSString * const kBase = @"https://octo.example/api/v1/";

- (void)setUp {
    [super setUp];
    [WKApp shared].config.apiBaseUrl = kBase;
    WKLoginInfo *info = [WKLoginInfo shared];
    info.token = @"test-token";
    info.uid = @"uid-1";
}

- (void)tearDown {
    [[WKLoginInfo shared] clear];
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

- (void)testReportPathExcludedButNeighborPathsNot {
    XCTAssertNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/report.html?channel_id=x"]]);
    XCTAssertNotNil([WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/reports/list"]]);
}

- (void)testExistingSidReplacedEvenWhenEmpty {
    // 已有 sid（含空值）一律替换为 ios，避免 web 端取第一个空值造成分桶错位。
    NSURL *out = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?sid=web"]];
    XCTAssertEqualObjects(out.absoluteString, @"https://octo.example/d/abc?sid=ios");
    NSURL *empty = [WKWebIdentityHandoff handoffURLForURL:[NSURL URLWithString:@"https://octo.example/d/abc?sid="]];
    XCTAssertEqualObjects(empty.absoluteString, @"https://octo.example/d/abc?sid=ios");
}

#pragma mark - identityJavaScriptForURL:

- (void)testScriptWritesKeysAndRuntimeOriginGuard {
    NSString *js = [WKWebIdentityHandoff identityJavaScriptForURL:[NSURL URLWithString:@"https://octo.example/s/ST1"]];
    XCTAssertNotNil(js);
    XCTAssertTrue([js containsString:@"tokenios"]);
    XCTAssertTrue([js containsString:@"uidios"]);
    XCTAssertTrue([js containsString:@"nameios"]);
    XCTAssertTrue([js containsString:@"octo.session.sid"]);
    // 运行时 origin 守卫存在：后续跨域导航不写凭证
    XCTAssertTrue([js containsString:@"location.hostname"]);
    XCTAssertTrue([js containsString:@"/report"]);
}

- (void)testScriptEscapesSidInKeys {
    NSString *evil = @"x'+(globalThis.sidExecuted=true)+'";
    NSString *raw = [NSString stringWithFormat:@"https://octo.example/d/abc?sid=%@",
        [evil stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSString *js = [WKWebIdentityHandoff identityJavaScriptForURL:[NSURL URLWithString:raw]];
    XCTAssertNotNil(js);
    XCTAssertFalse([js containsString:@"tokenx'+"], @"sid 不得裸插值进 JS 字面量");
}

- (void)testScriptNilWhenLoggedOut {
    [[WKLoginInfo shared] clear];
    XCTAssertNil([WKWebIdentityHandoff identityJavaScriptForURL:[NSURL URLWithString:@"https://octo.example/s/ST1"]]);
}

@end
