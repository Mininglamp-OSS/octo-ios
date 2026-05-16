// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRealnameVerifyCallbackTests.m
//  WuKongBase Tests
//
//  Round 2 / Jerry-Xin #112 review blocking 2 — 锁定 Option B:
//  `isVerifiedCallbackURL:` 只认自定义 scheme `<OCTO_URL_SCHEME>://verified`,
//  **不认** Universal Link `https://.../verified`（Aegis host 没在 entitlement
//  applinks:* 里, UL fallback 代码过去就是死码, Round 2 彻底删除; return_to
//  统一走 app scheme）。
//
//  P6-b 起 scheme 从硬编码 `dmwork` 改为从 OctoConfig.xcconfig 的 OCTO_URL_SCHEME
//  动态注入, 默认 `octo`。所有 URL 用全局 `WKRealnameVerifiedURLScheme` 拼装,
//  与产品代码同步, 避免下游改 scheme 后 tests 失效（Allen #121 review 🟡 项）。
//
//  合约（本 suite 把 Option B 固化下来, 防 regress 回 Round 1 的 UL 分支）:
//    1. `<scheme>://verified` + 任意 query / 任意 host case → 通过
//    2. `<scheme>://<other>`                                → 拒绝
//    3. 任意 `https://.../verified`                          → 拒绝（UL fallback 已删）
//    4. 非 http(s) 且 非 <scheme>                            → 拒绝
//    5. nil URL / 空 host                                    → 拒绝
//

@import XCTest;
#import "WKRealnameVerifyManager.h"

@interface WKRealnameVerifyCallbackTests : XCTestCase
@end

@implementation WKRealnameVerifyCallbackTests

static NSURL *URLWithScheme(NSString *fmt) {
    NSString *raw = [NSString stringWithFormat:fmt, WKRealnameVerifiedURLScheme];
    return [NSURL URLWithString:raw];
}

#pragma mark - <scheme>:// 自定义 scheme

- (void)test_customSchemeVerified_accepted {
    NSURL *url = URLWithScheme(@"%@://verified?token=abc&verified=1");
    XCTAssertTrue([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_customSchemeVerified_noQuery_accepted {
    NSURL *url = URLWithScheme(@"%@://verified");
    XCTAssertTrue([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_customScheme_wrongHost_rejected {
    NSURL *url = URLWithScheme(@"%@://other");
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_customScheme_emptyHost_rejected {
    // <scheme>:/// 解析 host 为空
    NSURL *url = URLWithScheme(@"%@:///");
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

#pragma mark - Universal Link (https) 全部拒绝（Option B）

/// Round 2 关键合约: UL 降级通道已删除, iOS 系统根本不把 Aegis https 回跳投给
/// 本 App（entitlement applinks:* 不含 Aegis host）; 即使恶意 / 历史路径把
/// 这种 URL 传进来, 本方法也必须一律拒绝, 避免调用侧误触发回跳处理。

- (void)test_httpsProdAegisVerified_rejected_ULDisabled {
    // 历史上（Round 1 方案）曾接受这种 URL; Round 2 改为一律拒绝。
    NSURL *url = [NSURL URLWithString:@"https://accounts.example.com/verified?token=abc"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url],
                   @"Universal Link must be rejected — Option B (see file header)");
}

- (void)test_httpsTestAegisVerified_rejected_ULDisabled {
    NSURL *url = [NSURL URLWithString:@"https://accounts-test.example.com/verified?token=abc"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_httpsArbitraryHostVerified_rejected {
    // 防御: 哪怕下发的 host 名字花里胡哨, 只要是 https 就一律拒, 回跳通道走 app scheme。
    NSURL *url = [NSURL URLWithString:@"https://accounts-staging.example/verified"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_httpsEvilHostVerified_rejected_notEvenConsidered {
    NSURL *url = [NSURL URLWithString:@"https://evil.example.com/verified"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_httpVerified_rejected {
    // http 同 https 一样, 回跳通道只认 app scheme。
    NSURL *url = [NSURL URLWithString:@"http://accounts-test.example.com/verified"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

#pragma mark - 其它 scheme 一律拒绝

- (void)test_javascriptSchemeVerified_rejected {
    NSURL *url = [NSURL URLWithString:@"javascript:verified"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

- (void)test_httpSchemeDmworkHost_rejected {
    // host 对了但 scheme 错, 同样拒绝
    NSURL *url = [NSURL URLWithString:@"http://verified"];
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:url]);
}

#pragma mark - nil / 空 guard

- (void)test_nilUrl_rejected {
    XCTAssertFalse([WKRealnameVerifyManager isVerifiedCallbackURL:nil]);
}

@end
