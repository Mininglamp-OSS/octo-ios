//
//  WKOidcProviderConfigParseTests.m
//  WuKongBase Tests
//
//  YUJ-396 P-S2 / Jerry-Xin #112 review suggestion 2 —
//    锁 WKOidcProviderConfig.parseArray 的 entry 筛选合约。
//
//  cover:
//    1. nil / 非数组 raw → @[]
//    2. 空数组 → @[]
//    3. entry 不是 dict → 跳过
//    4. id 缺失 / 非 string / 空串 → 跳过 entry
//    5. authorize_path 非合规（缺 / '//' 开头 / 不 '/' 开头 / 非 string）→ 跳过 entry
//    6. name 缺失 / 空串 → 保留 entry（YUJ-396 P-S1 改动）, name=nil
//    7. account_url 非 https（http / javascript: / 无 host）→ entry 保留, accountUrl=nil
//    8. 正常 entry → 字段齐全拼回
//    9. 混合合法 / 非法 entries → 只保留合法部分
//

@import XCTest;
#import "WKOidcProviderConfig.h"

@interface WKOidcProviderConfigParseTests : XCTestCase
@end

@implementation WKOidcProviderConfigParseTests

#pragma mark - raw guard

- (void)test_nilRaw_returnsEmptyArray {
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:nil], @[]);
}

- (void)test_nonArrayRaw_returnsEmptyArray {
    // 传 dict / string / NSNumber 都视为「数组不合法」, 不抛错, 返 @[]。
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:(NSArray *)@{@"k": @"v"}], @[]);
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:(NSArray *)@"bad"], @[]);
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:(NSArray *)@42], @[]);
}

- (void)test_emptyArray_returnsEmptyArray {
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:@[]], @[]);
}

- (void)test_nonDictEntry_isSkipped {
    NSArray *raw = @[@"bad", @42, [NSNull null]];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

#pragma mark - id required

- (void)test_missingId_entrySkipped {
    NSArray *raw = @[@{
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

- (void)test_emptyId_entrySkipped {
    NSArray *raw = @[@{
        @"id": @"",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

- (void)test_nonStringId_entrySkipped {
    NSArray *raw = @[@{
        @"id": @42,
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

#pragma mark - authorize_path required + safety

- (void)test_missingAuthorizePath_entrySkipped {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

- (void)test_authorizePathNotLeadingSlash_entrySkipped {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"auth/oidc/xming",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

- (void)test_authorizePathDoubleSlashPrefix_entrySkipped {
    // 防 '//evil.com/...' 协议相对 URL 跳站外
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"//evil.com/authorize",
    }];
    XCTAssertEqualObjects([WKOidcProviderConfig parseArray:raw], @[]);
}

#pragma mark - name optional (YUJ-396 P-S1)

- (void)test_missingName_entryKept_nameNil {
    // name 缺失 → entry 保留, name=nil（UI 侧 fallback 到 providerId）
    NSArray *raw = @[@{
        @"id": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts-test.imocto.cn",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    WKOidcProviderConfig *p = out.firstObject;
    XCTAssertEqualObjects(p.providerId, @"xming");
    XCTAssertNil(p.name);
    XCTAssertEqualObjects(p.accountUrl, @"https://accounts-test.imocto.cn");
}

- (void)test_emptyName_entryKept_nameNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"",
        @"authorize_path": @"/auth/oidc/xming/authorize",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.name);
}

- (void)test_nonStringName_entryKept_nameNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @42,
        @"authorize_path": @"/auth/oidc/xming/authorize",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.name);
}

#pragma mark - account_url sanitize (https only)

- (void)test_httpAccountUrl_entryKept_accountUrlNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"http://accounts-test.imocto.cn",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.accountUrl);
}

- (void)test_javascriptAccountUrl_entryKept_accountUrlNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"javascript:alert(1)",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.accountUrl);
}

#pragma mark - account_url rejects query / fragment (YUJ-396 Round 2 suggestion)

// buildVerifyURLFromAccountUrl: 在 accountUrl 末尾拼固定 path `/profile/info?anchor=verification`。
// 若 accountUrl 本身已经带 query 或 fragment, 拼出来的 URL 语义歧义:
// 例如 `https://acc.example?x=1` + `/profile/info?anchor=verification`
// → `https://acc.example?x=1/profile/info?anchor=verification`, `x` 的 value
// 把 /profile/info 吞进去, 且同一 URL 出现两个 '?'。
// parser 层直接拒收, accountUrl 的语义就是「基址 URL」。

- (void)test_accountUrlWithQuery_entryKept_accountUrlNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts-test.imocto.cn?x=1",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.accountUrl,
                 @"base URL with ?query must be rejected (parser layer)");
}

- (void)test_accountUrlWithFragment_entryKept_accountUrlNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts-test.imocto.cn#anchor",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.accountUrl,
                 @"base URL with #fragment must be rejected (parser layer)");
}

- (void)test_accountUrlWithQueryAndFragment_entryKept_accountUrlNil {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts-test.imocto.cn/base?x=1#f",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertNil(out.firstObject.accountUrl);
}

- (void)test_accountUrlWithPathButNoQueryFragment_entryKept_accountUrlRetained {
    // path 本身是允许的: base URL 可以是 `https://acc.example/account-center`。
    // 拼 `/account-center/profile/info?anchor=verification` 仍然合法。
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts.example.com/account-center",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    XCTAssertEqualObjects(out.firstObject.accountUrl, @"https://accounts.example.com/account-center");
}

#pragma mark - happy path

- (void)test_wellFormedEntry_fieldsPopulated {
    NSArray *raw = @[@{
        @"id": @"xming",
        @"name": @"xming",
        @"authorize_path": @"/auth/oidc/xming/authorize",
        @"account_url": @"https://accounts-test.imocto.cn",
        @"reset_password_url": @"https://accounts-test.imocto.cn/reset",
    }];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 1u);
    WKOidcProviderConfig *p = out.firstObject;
    XCTAssertEqualObjects(p.providerId, @"xming");
    XCTAssertEqualObjects(p.name, @"xming");
    XCTAssertEqualObjects(p.authorizePath, @"/auth/oidc/xming/authorize");
    XCTAssertEqualObjects(p.accountUrl, @"https://accounts-test.imocto.cn");
    XCTAssertEqualObjects(p.resetPasswordUrl, @"https://accounts-test.imocto.cn/reset");
}

- (void)test_mixedValidAndInvalidEntries_onlyValidKept {
    NSArray *raw = @[
        @{  // valid — kept
            @"id": @"xming",
            @"name": @"xming",
            @"authorize_path": @"/auth/oidc/xming/authorize",
        },
        @{  // missing id — skipped
            @"name": @"broken",
            @"authorize_path": @"/auth/oidc/broken/authorize",
        },
        @{  // '//' authorize_path — skipped
            @"id": @"evil",
            @"name": @"evil",
            @"authorize_path": @"//evil.com/x",
        },
        @{  // valid, name missing — kept w/ name=nil
            @"id": @"octo",
            @"authorize_path": @"/auth/oidc/octo/authorize",
            @"account_url": @"https://accounts-octo.example",
        },
    ];
    NSArray<WKOidcProviderConfig *> *out = [WKOidcProviderConfig parseArray:raw];
    XCTAssertEqual(out.count, 2u);
    XCTAssertEqualObjects(out[0].providerId, @"xming");
    XCTAssertEqualObjects(out[1].providerId, @"octo");
    XCTAssertNil(out[1].name);
    XCTAssertEqualObjects(out[1].accountUrl, @"https://accounts-octo.example");
}

@end
