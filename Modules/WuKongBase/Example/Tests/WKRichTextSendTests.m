// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextSendTests.m
//  LiMaoBase_Tests
//
//  图文混排 RichText(=14) 发送侧 schema 单测（与接收侧 #16 共用同一份定义）。
//  对称 web #227 的发送侧用例：
//   - block 构造（textBlock / imageBlock）
//   - image block size=0 / name 空 不注入 wire（防 byte-match 污染）
//   - contentWithBlocks 本地填 plain 占位（image → 非本地化 [图片] wire token）
//   - encode↔decode 往返：发送构造的 payload 可被接收侧解析回同一 blocks
//

@import XCTest;
#import "WKRichTextContent.h"

@interface WKRichTextSendTests : XCTestCase
@end

@implementation WKRichTextSendTests

#pragma mark - block 构造

- (void)testTextBlock_producesTextBlock {
    WKRichTextBlock *b = [WKRichTextContent textBlock:@"hi"];
    XCTAssertEqual(b.type, WKRichTextBlockTypeText);
    XCTAssertEqualObjects(b.text, @"hi");
}

- (void)testTextBlock_nilTextFallsBackToEmpty {
    WKRichTextBlock *b = [WKRichTextContent textBlock:nil];
    XCTAssertEqual(b.type, WKRichTextBlockTypeText);
    XCTAssertEqualObjects(b.text, @"");
}

- (void)testImageBlock_requiredFieldsSet {
    WKRichTextBlock *b = [WKRichTextContent imageBlock:@"https://x/a.png"
                                                 width:10
                                                height:20
                                                  size:123
                                                  name:@"a.png"];
    XCTAssertEqual(b.type, WKRichTextBlockTypeImage);
    XCTAssertEqualObjects(b.url, @"https://x/a.png");
    XCTAssertEqual(b.width, 10);
    XCTAssertEqual(b.height, 20);
    XCTAssertEqual(b.size, 123);
    XCTAssertEqualObjects(b.name, @"a.png");
}

#pragma mark - encode：size=0 / name 空 不注入 wire

- (void)testEncode_imageWithSizeAndName_included {
    WKRichTextBlock *b = [WKRichTextContent imageBlock:@"https://x/a.png"
                                                 width:10
                                                height:20
                                                  size:123
                                                  name:@"a.png"];
    WKRichTextContent *c = [WKRichTextContent contentWithBlocks:@[b]];
    NSDictionary *wire = [c encodeWithJSON];
    NSDictionary *img = [wire[@"content"] firstObject];
    XCTAssertEqualObjects(img[@"type"], @"image");
    XCTAssertEqualObjects(img[@"url"], @"https://x/a.png");
    XCTAssertEqualObjects(img[@"width"], @10);
    XCTAssertEqualObjects(img[@"height"], @20);
    XCTAssertEqualObjects(img[@"size"], @123);
    XCTAssertEqualObjects(img[@"name"], @"a.png");
}

- (void)testEncode_imageSizeZeroAndNameEmpty_notInjected {
    WKRichTextBlock *b = [WKRichTextContent imageBlock:@"https://x/a.png"
                                                 width:1
                                                height:1
                                                  size:0
                                                  name:nil];
    WKRichTextContent *c = [WKRichTextContent contentWithBlocks:@[b]];
    NSDictionary *wire = [c encodeWithJSON];
    NSDictionary *img = [wire[@"content"] firstObject];
    XCTAssertNil(img[@"size"], @"size=0 不应注入 wire");
    XCTAssertNil(img[@"name"], @"name 空 不应注入 wire");
    // 必填字段仍在。
    XCTAssertEqualObjects(img[@"url"], @"https://x/a.png");
    XCTAssertEqualObjects(img[@"width"], @1);
    XCTAssertEqualObjects(img[@"height"], @1);
}

#pragma mark - plain 本地占位（非本地化 wire token）

- (void)testContentWithBlocks_fillsWirePlainPlaceholder {
    NSArray *blocks = @[
        [WKRichTextContent textBlock:@"看图："],
        [WKRichTextContent imageBlock:@"https://x/a.png" width:10 height:20 size:0 name:nil],
        [WKRichTextContent textBlock:@"怎么样？"],
    ];
    WKRichTextContent *c = [WKRichTextContent contentWithBlocks:blocks];
    // image → 非本地化 [图片] wire token（跨端一致，server #232 Finalize 会覆盖）。
    XCTAssertEqualObjects(c.plain, @"看图：[图片]怎么样？");
}

#pragma mark - encode↔decode 往返

- (void)testRoundTrip_encodeThenDecode_preservesBlocks {
    NSArray *sentBlocks = @[
        [WKRichTextContent textBlock:@"hello"],
        [WKRichTextContent imageBlock:@"https://x/a.png" width:10 height:20 size:81920 name:@"a.png"],
    ];
    WKRichTextContent *sent = [WKRichTextContent contentWithBlocks:sentBlocks];
    NSDictionary *wire = [sent encodeWithJSON];

    WKRichTextContent *received = [WKRichTextContent new];
    [received decodeWithJSON:wire];

    XCTAssertEqual(received.content.count, 2);
    WKRichTextBlock *t = received.content[0];
    XCTAssertEqual(t.type, WKRichTextBlockTypeText);
    XCTAssertEqualObjects(t.text, @"hello");
    WKRichTextBlock *i = received.content[1];
    XCTAssertEqual(i.type, WKRichTextBlockTypeImage);
    XCTAssertEqualObjects(i.url, @"https://x/a.png");
    XCTAssertEqual(i.width, 10);
    XCTAssertEqual(i.height, 20);
    XCTAssertEqual(i.size, 81920);
    XCTAssertEqualObjects(i.name, @"a.png");
}

@end
