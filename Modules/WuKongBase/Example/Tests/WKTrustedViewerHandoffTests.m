// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0

@import XCTest;
#import "WKTrustedViewerHandoff.h"
#import "WKTrustedViewerDataStore.h"

@interface WKTrustedViewerHandoffTests : XCTestCase
@end

@implementation WKTrustedViewerHandoffTests

- (void)testAcceptsOnlyConfiguredOriginsAndViewerPaths {
    NSString *api = @"https://api.example/api/v1/";
    XCTAssertTrue(WKIsTrustedViewerURL([NSURL URLWithString:@"https://api.example/s/ST_12?sp=room"], api));
    XCTAssertTrue(WKIsTrustedViewerURL([NSURL URLWithString:@"https://api.example:443/d/doc-1"], api));
    XCTAssertTrue(WKIsTrustedViewerURL([NSURL URLWithString:@"https://api.example/ppt/d/deck-1/"], api));
    NSArray<NSString *> *rejected = @[
        @"https://api.example.evil/s/ST_12", @"https://user@api.example/s/ST_12",
        @"http://api.example/s/ST_12", @"https://api.example:8443/s/ST_12",
        @"https://web.example/s/ST_12", @"https://api.example/s/share/ST_12", @"https://api.example/s/%2e%2e",
        @"https://api.example/d/doc-1/edit", @"https://api.example/d/doc%2Fchild",
        @"https://api.example/api/v1/docs/doc-1/preview", @"https://api.example/file/upload/doc-1"
    ];
    for (NSString *value in rejected) {
        XCTAssertFalse(WKIsTrustedViewerURL([NSURL URLWithString:value], api), @"%@", value);
    }
}

- (void)testCanonicalizesSidWithoutDroppingOtherParameters {
    NSURL *source = [NSURL URLWithString:@"https://api.example/s/ST_12?sp=room&sid=old&%73id=other&next=one%2Btwo#part"];
    NSURL *result = WKTrustedViewerHandoffURL(source, @"https://api.example/api/v1");
    XCTAssertNotNil(result);
    NSURLComponents *components = [NSURLComponents componentsWithURL:result resolvingAgainstBaseURL:NO];
    NSMutableArray *sidValues = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"sid"]) [sidValues addObject:item.value ?: @""];
    }
    XCTAssertEqualObjects(sidValues, (@[@"ios-viewer"]));
    XCTAssertTrue([result.absoluteString containsString:@"sp=room"]);
    NSURLQueryItem *next = [[components.queryItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"next"]] firstObject];
    XCTAssertEqualObjects(next.value, @"one+two");
    XCTAssertEqualObjects(components.fragment, @"part");
    XCTAssertEqualObjects(WKTrustedViewerHandoffURL(result, @"https://api.example/api/v1"), result);
}

- (void)testScriptGuardsRouteAndEscapesIdentity {
    NSURL *url = [NSURL URLWithString:@"https://api.example/s/ST_12?sid=ios-viewer"];
    NSString *script = WKTrustedViewerIdentityScript(url, @"token'</script>\n", @"u+1", @"A\"B", @"space-1");
    XCTAssertTrue([script containsString:@"location.hostname.toLowerCase()"]);
    XCTAssertTrue([script containsString:@"location.pathname"]);
    XCTAssertTrue([script containsString:@"localStorage.setItem('token'+"]);
    XCTAssertTrue([script containsString:@"octo:last-space:"]);
    XCTAssertFalse([script containsString:@"</script>"]);
    XCTAssertFalse([script containsString:@"token'</script>\n"]);
    XCTAssertNil(WKTrustedViewerIdentityScript(url, @"", @"u", @"n", nil));
}

- (void)testDataStoreReusesOnlyCurrentSession {
    WKWebsiteDataStore *first = [WKTrustedViewerDataStore storeForUID:@"u1" token:@"t1" apiBaseURL:@"https://api.example"];
    WKWebsiteDataStore *same = [WKTrustedViewerDataStore storeForUID:@"u1" token:@"t1" apiBaseURL:@"https://api.example"];
    XCTAssertEqual(first, same);

    WKWebsiteDataStore *newToken = [WKTrustedViewerDataStore storeForUID:@"u1" token:@"t2" apiBaseURL:@"https://api.example"];
    XCTAssertNotEqual(first, newToken);
    [WKTrustedViewerDataStore retireStoreIfCurrent:first];
    XCTAssertEqual(newToken, [WKTrustedViewerDataStore storeForUID:@"u1" token:@"t2" apiBaseURL:@"https://api.example"]);

    WKWebsiteDataStore *newOrigin = [WKTrustedViewerDataStore storeForUID:@"u1" token:@"t2" apiBaseURL:@"https://api2.example"];
    XCTAssertNotEqual(newToken, newOrigin);
    WKWebsiteDataStore *newUID = [WKTrustedViewerDataStore storeForUID:@"u2" token:@"t2" apiBaseURL:@"https://api2.example"];
    XCTAssertNotEqual(newOrigin, newUID);

    [[NSNotificationCenter defaultCenter] postNotificationName:WKTrustedViewerSessionDidChangeNotification object:nil];
    XCTAssertNotEqual(newUID, [WKTrustedViewerDataStore storeForUID:@"u2" token:@"t2" apiBaseURL:@"https://api2.example"]);
}

@end
