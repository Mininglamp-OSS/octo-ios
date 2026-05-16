// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRealnameVerifyURLBuilderTests.m
//  WuKongBase Tests
//
//  / —
//    iOS 端「去认证」URL 按环境从 appconfig.oidc_providers[].account_url 读,
//    不再硬编码 prod 域。这里用纯函数测试 URL 拼接 + https/host 安全守卫合约,
//    与 Web 端 resolveRealnameVerifyUrl 对齐口径。
//
//  covers: WKRealnameVerifyManager.buildVerifyURLFromAccountUrl:
//    1. prod accountUrl → 拼 prod verify URL
//    2. test accountUrl (accounts-test.example.com) → 拼 test verify URL
//    3. 末尾斜杠剥离
//    4. nil / 空串 → nil
//    5. 非 https (http/javascript) → nil（安全守卫）
//    6. 缺 host → nil
//

@import XCTest;
#import "WKRealnameVerifyManager.h"

@interface WKRealnameVerifyURLBuilderTests : XCTestCase
@end

@implementation WKRealnameVerifyURLBuilderTests

#pragma mark - happy path

- (void)test_prodAccountUrl_buildsProdVerifyURL {
    NSURL *url = [WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"https://accounts.example.com"];
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString,
                          @"https://accounts.example.com/profile/info?anchor=verification");
}

- (void)test_testAccountUrl_buildsTestVerifyURL_imTestScenario {
    // 本测试就是 修复的核心目标: im-test 环境不能再跳 prod Aegis。
    NSURL *url = [WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"https://accounts-test.example.com"];
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString,
                          @"https://accounts-test.example.com/profile/info?anchor=verification");
    XCTAssertEqualObjects(url.host, @"accounts-test.example.com");
}

- (void)test_trailingSlashOnAccountUrl_isStripped {
    // 防 `//profile/info?...` 协议相对 URL 泄漏。
    NSURL *url = [WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"https://accounts-test.example.com/"];
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString,
                          @"https://accounts-test.example.com/profile/info?anchor=verification");
}

- (void)test_multipleTrailingSlashes_allStripped {
    NSURL *url = [WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"https://accounts.example.com///"];
    XCTAssertNotNil(url);
    XCTAssertEqualObjects(url.absoluteString,
                          @"https://accounts.example.com/profile/info?anchor=verification");
}

#pragma mark - security / nil 守卫

- (void)test_nilAccountUrl_returnsNil {
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:nil]);
}

- (void)test_emptyAccountUrl_returnsNil {
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@""]);
}

- (void)test_httpAccountUrl_returnsNil_httpsOnly {
    // 客户端比 Web 端更严：Aegis 账户页涉及密码 / OIDC token, 必须 TLS。
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"http://accounts-test.example.com"]);
}

- (void)test_javascriptProtocolAccountUrl_returnsNil_noScriptInjection {
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"javascript:alert(1)"]);
}

- (void)test_accountUrlMissingHost_returnsNil {
    // 仅 scheme 没有 host 的 URL, NSURL 可能接受但我们应拒绝。
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:@"https://"]);
}

#pragma mark - defense-in-depth: query / fragment (R3 suggestion 1)

// buildVerifyURLFromAccountUrl: 作为 public header 方法, 允许外部调用者绕过
// WKOidcProviderConfig.parseArray 直接传 accountUrl。深层防御: 就算 parser 层
// 改坏 / 外部绕过, builder 层也不能拼出 `<base>?x=1/profile/info?anchor=...`
// 这种双 '?' / 语义歧义 URL。与 parser 的 query/fragment 守卫同语义。

- (void)test_accountUrlWithQuery_returnsNil_defenseInDepth {
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:
                    @"https://accounts-test.example.com?x=1"]);
}

- (void)test_accountUrlWithFragment_returnsNil_defenseInDepth {
    XCTAssertNil([WKRealnameVerifyManager buildVerifyURLFromAccountUrl:
                    @"https://accounts.example.com#section"]);
}

@end
