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
    XCTAssertTrue([script containsString:@"\\u003c"]);
    XCTAssertTrue([script containsString:@"\\u003e"]);
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

- (void)testViewerHandoffPreservesSidAndOtherQueryParameters {
    NSString *base = @"https://octo.example/api/v1/";
    NSURL *document = WKViewerHandoffURL([NSURL URLWithString:@"https://octo.example/d/doc-1?sp=a%2Bb&x=1"], base);
    XCTAssertEqualObjects(document.absoluteString, @"https://octo.example/d/doc-1?sp=a%2Bb&x=1&sid=ios");
    NSURL *original = [NSURL URLWithString:@"https://octo.example/s/summary-1?sid=web&sp=a%2Bb"];
    XCTAssertEqualObjects(WKViewerHandoffURL(original, base).absoluteString, original.absoluteString);
    XCTAssertNil(WKViewerHandoffURL([NSURL URLWithString:@"https://evil.example/d/doc-1"], base));
    XCTAssertNil(WKViewerHandoffURL([NSURL URLWithString:@"https://octo.example/d/doc-1/edit"], base));
}

- (void)testViewerHandoffUsesConfiguredRoutePrefix {
    NSString *base = @"https://octo.example/team/api/v1/";
    NSURL *document = [NSURL URLWithString:@"https://octo.example/team/d/doc-1"];
    XCTAssertTrue(WKIsTrustedDocsViewerURL(document, base));
    XCTAssertEqualObjects(WKViewerHandoffURL(document, base).absoluteString,
                          @"https://octo.example/team/d/doc-1?sid=ios");
    XCTAssertNil(WKViewerHandoffURL([NSURL URLWithString:@"https://octo.example/d/doc-1"], base));
    XCTAssertNil(WKViewerHandoffURL([NSURL URLWithString:@"https://octo.example/team-other/d/doc-1"], base));
}

- (void)testEmptySidHandoffPreservesOtherQueryEncodingThroughBootstrap {
    NSString *base = @"https://octo.example/api/v1/";
    NSArray<NSDictionary<NSString *, NSString *> *> *cases = @[
        @{@"query": @"sid=&sp=a%2Bb", @"expected": @"sp=a%2Bb&sid=ios", @"sid": @"ios"},
        @{@"query": @"sid=&sp=a+b", @"expected": @"sp=a+b&sid=ios", @"sid": @"ios"},
        @{@"query": @"sid=&sp=a%2Bb&sid=a+b", @"expected": @"sp=a%2Bb&sid=a+b", @"sid": @"a b"},
        @{@"query": @"sid=&sid=a%2Bb&sp=a%2Bb", @"expected": @"sp=a%2Bb&sid=a%2Bb", @"sid": @"a+b"}
    ];
    for (NSDictionary<NSString *, NSString *> *testCase in cases) {
        NSString *sourceString = [@"https://octo.example/d/doc-1?" stringByAppendingString:testCase[@"query"]];
        NSURL *target = WKViewerHandoffURL([NSURL URLWithString:sourceString], base);
        NSString *expectedURL = [@"https://octo.example/d/doc-1?" stringByAppendingString:testCase[@"expected"]];
        XCTAssertEqualObjects(target.absoluteString, expectedURL, @"%@", sourceString);
        NSString *html = WKViewerBootstrapHTML(target, @"token", @"user", @"name", nil, YES);
        NSString *expectedAssignment = [NSString stringWithFormat:@"var s=\"%@\";", testCase[@"sid"]];
        XCTAssertTrue([html containsString:expectedAssignment], @"%@", sourceString);
        XCTAssertTrue([html containsString:@"localStorage.setItem('token'+s"], @"%@", sourceString);
        NSString *escapedURL = [expectedURL stringByReplacingOccurrencesOfString:@"&" withString:@"\\u0026"];
        NSString *navigation = [NSString stringWithFormat:@"window.location.replace(\"%@\")", escapedURL];
        XCTAssertTrue([html containsString:navigation], @"%@", sourceString);
    }
}

- (void)testBootstrapWritesMatchingSessionBeforeNavigation {
    NSURL *URL = [NSURL URLWithString:@"https://octo.example/d/doc-1?sid=web"];
    NSString *html = WKViewerBootstrapHTML(URL, @"secret</script>", @"user-1", @"Name", @"space-1", YES);
    XCTAssertTrue([html containsString:@"var s=\"web\""]);
    XCTAssertTrue([html containsString:@"localStorage.setItem('token'+s"]);
    XCTAssertTrue([html containsString:@"localStorage.setItem('currentSpaceId'"]);
    XCTAssertTrue([html containsString:@"secret\\u003c"]);
    XCTAssertTrue([html containsString:@"script\\u003e"]);
    XCTAssertTrue([html containsString:@"window.location.replace"]);
    XCTAssertTrue([html rangeOfString:@"localStorage.setItem('token'+s"].location < [html rangeOfString:@"window.location.replace"].location);
}

- (void)testBootstrapDecodesSidLikeViewerQueryParameters {
    NSDictionary<NSString *, NSString *> *cases = @{
        @"a+b": @"a b",
        @"a%2Bb": @"a+b",
        @"a%20b": @"a b"
    };
    for (NSString *encodedSid in cases) {
        NSString *URLString = [@"https://octo.example/d/doc-1?sid=" stringByAppendingString:encodedSid];
        NSURL *URL = [NSURL URLWithString:URLString];
        NSString *expectedSid = cases[encodedSid];
        NSString *expectedAssignment = [NSString stringWithFormat:@"var s=\"%@\";", expectedSid];
        NSString *loginHTML = WKViewerBootstrapHTML(URL, @"token", @"user", @"name", nil, YES);
        NSString *logoutHTML = WKViewerBootstrapHTML(URL, nil, nil, nil, nil, YES);
        XCTAssertTrue([loginHTML containsString:expectedAssignment], @"%@", URLString);
        XCTAssertTrue([logoutHTML containsString:expectedAssignment], @"%@", URLString);
        XCTAssertTrue([loginHTML containsString:@"localStorage.setItem('token'+s"], @"%@", URLString);
        XCTAssertTrue([logoutHTML containsString:@"localStorage.removeItem('token'+s"], @"%@", URLString);
        XCTAssertEqualObjects(URL.absoluteString, URLString);
    }
}

@end
