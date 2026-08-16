// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

@import XCTest;
#import "WKDocsViewerSpaceHandoff.h"

@interface WKDocsViewerSpaceHandoffTests : XCTestCase
@end

@implementation WKDocsViewerSpaceHandoffTests

- (void)testAllowsSameOriginViewerRoutesAndEffectiveDefaultPort {
    NSString *base = @"https://octo.example/api/v1/";
    XCTAssertTrue(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example/d/doc-1"], base));
    XCTAssertTrue(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example:443/ppt/d/deck-1/"], base));
    XCTAssertTrue(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example/docs/deck-1/present?slide=2"], base));
}

- (void)testRejectsOriginSpoofingAndPortMismatch {
    NSString *base = @"https://octo.example/api/v1/";
    XCTAssertFalse(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example.evil/d/doc-1"], base));
    XCTAssertFalse(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example@evil.example/d/doc-1"], base));
    XCTAssertFalse(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"http://octo.example/d/doc-1"], base));
    XCTAssertFalse(WKIsTrustedDocsViewerURL([NSURL URLWithString:@"https://octo.example:8443/d/doc-1"], base));
}

- (void)testRejectsNonViewerAndNearMatchPaths {
    NSString *base = @"https://octo.example/api/v1/";
    NSArray<NSString *> *URLs = @[
        @"https://octo.example/", @"https://octo.example/docs", @"https://octo.example/d/",
        @"https://octo.example/d/doc-1/edit", @"https://octo.example/ppt/d/deck-1/edit",
        @"https://octo.example/docs/deck-1", @"https://octo.example/docs/deck-1/present/extra"
    ];
    for (NSString *value in URLs) {
        XCTAssertFalse(WKIsTrustedDocsViewerURL([NSURL URLWithString:value], base), @"%@", value);
    }
}

- (void)testScriptSetsEscapedSnapshot {
    NSString *lineSeparator = [NSString stringWithFormat:@"%C", (unichar)0x2028];
    NSString *paragraphSeparator = [NSString stringWithFormat:@"%C", (unichar)0x2029];
    NSString *space = [NSString stringWithFormat:@"space'\\\"\n%@%@</script>", lineSeparator, paragraphSeparator];
    NSString *script = WKDocsViewerSpaceJavaScript(space, @"https://octo.example/api/v1");
    XCTAssertTrue([script containsString:@"localStorage.setItem('currentSpaceId'"]);
    XCTAssertTrue([script containsString:@"space'\\\\\\\""]);
    XCTAssertTrue([script containsString:@"\\n"]);
    XCTAssertTrue([script containsString:@"\\u2028"]);
    XCTAssertTrue([script containsString:@"\\u2029"]);
    XCTAssertTrue([script containsString:@"<\\/script>"]);
    XCTAssertFalse([script containsString:lineSeparator]);
    XCTAssertFalse([script containsString:paragraphSeparator]);
}

- (void)testScriptRemovesForNilOrEmptySpace {
    NSString *remove = WKDocsViewerSpaceJavaScript(nil, @"https://octo.example/api/v1");
    XCTAssertTrue([remove containsString:@"localStorage.removeItem('currentSpaceId')"]);
    XCTAssertTrue([remove containsString:@"p===\"https\""]);
    XCTAssertTrue([remove containsString:@"h===\"octo.example\""]);
    XCTAssertTrue([remove containsString:@"n===443"]);
    XCTAssertEqualObjects(WKDocsViewerSpaceJavaScript(@"", @"https://octo.example/api/v1"), remove);
}

@end
