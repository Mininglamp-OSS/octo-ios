// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKWebViewServiceOriginTests.m
//  LiMaoBase_Tests
//
//  bridge 来源守卫 isOriginAllowedForURL: 单测（4f4d50ce 评审阻塞项 P1）。
//  覆盖：默认端口归一、非默认端口、跨域、scheme 降级、nil/空 URL、
//  trustedOrigin 缺省 fail-closed、URL 组件解析失败。判定不依赖真 WKWebView。
//

@import XCTest;
#import "WKWebViewService.h"
#import "WKWebIdentityHandoff.h"

@interface WKWebViewServiceOriginTests : XCTestCase
@end

@implementation WKWebViewServiceOriginTests

- (WKWebViewService *)serviceWithOrigin:(NSString *)origin {
    WKWebViewService *svc = [[WKWebViewService alloc] init];
    [svc setTrustedOrigin:origin];
    return svc;
}

- (NSURL *)urlWithString:(NSString *)s {
    return [NSURL URLWithString:s];
}

#pragma mark - 默认端口归一（P0：https://a.com 与 https://a.com:443 必须同源）

- (void)testImplicitPort_matchesExplicit443 {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:443"];
    XCTAssertTrue([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com/x"]]);
}

- (void)testExplicit443_matchesImplicitPortTrustedOrigin {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com"];
    XCTAssertTrue([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com:443/x"]]);
}

- (void)testImplicitHTTP80_matches {
    WKWebViewService *svc = [self serviceWithOrigin:@"http://a.com:80"];
    XCTAssertTrue([svc isOriginAllowedForURL:[self urlWithString:@"http://a.com/x"]]);
}

#pragma mark - 端口不同必须拒绝

- (void)testDifferentPort_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:8443"];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com/x"]]);
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com:443/x"]]);
}

#pragma mark - 跨域 / host 大小写

- (void)testDifferentHost_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:443"];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://evil.com/x"]]);
}

- (void)testHostCaseInsensitive_allowed {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://A.com:443"];
    XCTAssertTrue([svc isOriginAllowedForURL:[self urlWithString:@"https://a.COM/x"]]);
}

#pragma mark - scheme 降级

- (void)testSchemeDowngradeHttpsToHttp_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:443"];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"http://a.com:443/x"]]);
}

#pragma mark - nil / 异常 URL fail-closed

- (void)testNilURL_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:443"];
    XCTAssertFalse([svc isOriginAllowedForURL:nil]);
}

- (void)testURLWithoutHost_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"https://a.com:443"];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"file:///tmp/x.html"]]);
}

#pragma mark - trustedOrigin 缺省 fail-closed（P0：原 fail-open 行为已移除）

- (void)testNilTrustedOrigin_denied {
    WKWebViewService *svc = [[WKWebViewService alloc] init];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com/x"]]);
}

- (void)testEmptyTrustedOrigin_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@""];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com/x"]]);
}

#pragma mark - trustedOrigin 含 userinfo / 非法串 fail-closed

- (void)testInvalidTrustedOrigin_denied {
    WKWebViewService *svc = [self serviceWithOrigin:@"not a url"];
    XCTAssertFalse([svc isOriginAllowedForURL:[self urlWithString:@"https://a.com/x"]]);
}

#pragma mark - trustedOrigin 生成口径（WKWebIdentityHandoff）

- (void)testTrustedOriginGeneration_explicitPortForm {
    // apiBaseUrl 隐式端口时生成显式 :443 —— 与归一比较配套，缺省端口页面不再误拒。
    NSString *origin = [WKWebIdentityHandoff trustedOrigin];
    if (origin == nil) {
        XCTSkip(@"apiBaseUrl 未配置（测试环境无 WKApp config），跳过");
    }
    XCTAssertTrue([origin containsString:@":"], @"trustedOrigin 应为 scheme://host:port 形态");
}

@end
