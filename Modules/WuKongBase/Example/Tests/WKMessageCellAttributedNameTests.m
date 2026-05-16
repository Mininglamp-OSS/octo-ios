// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageCellAttributedNameTests.m
//  WuKongBase Tests
//
//  (iOS) — WKMessageCell `+getFromNameAttributed:viewerSpaceId:`
//  unit tests. 对齐 Web PR #1084 `wk-msg-row-header` 的 5 个 fiber 诊断
//  scenario + Android `WKChatBaseProvider.resolveExternalSpaceSuffix`。
//
//  这里只验证 UI 渲染层是否按 viewer-relative 规则在 baseName 后拼
//  「 @SpaceName」后缀（灰紫 0x8B5CF6）。resolver 的纯函数逻辑已在
//  WKExternalViewerResolverTests 中穷举，不重复。
//

@import XCTest;
#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageCell.h"
#import "WKMessageModel.h"
#import "WKExternalViewerResolver.h"

@interface WKMessageCellAttributedNameTests : XCTestCase
@end

@implementation WKMessageCellAttributedNameTests

// 构造一条群聊消息 model，只填 from_* 字段，避免触及 [WKSDK shared].channelManager。
- (WKMessageModel *)modelWithExtras:(NSDictionary *)extras {
    WKMessage *m = [WKMessage new];
    m.fromUid = @"u_sender";
    m.channel = [[WKChannel alloc] initWith:@"g_group" channelType:WK_GROUP];
    for (NSString *k in extras) {
        m.extra[k] = extras[k];
    }
    return [[WKMessageModel alloc] initWithMessage:m];
}

#pragma mark - 5 scenarios from the ticket

// 1) 同 Space（viewer == sender.home）→ 不渲染 @
- (void)test_sameSpace_NoAtSuffix {
    WKMessageModel *model = [self modelWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceA"];
    XCTAssertNotNil(s);
    // baseName 可能为空字符串（无 from/channelInfo），但关键是没有 @Suffix。
    XCTAssertFalse([s.string containsString:@"@"],
                   @"same-space 不应出现 @SpaceName 后缀, got: '%@'", s.string);
}

// 2) 跨 Space 新字段（fromHomeSpaceId + fromHomeSpaceName 都有）→ 渲染 @HomeSpaceName
- (void)test_crossSpace_NewFields_RendersAtHomeSpaceName {
    WKMessageModel *model = [self modelWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceB"];
    XCTAssertTrue([s.string hasSuffix:@" @OctoWork"],
                  @"跨 Space 应拼 ' @OctoWork', got: '%@'", s.string);

    // 后缀颜色必须是灰紫 0x8B5CF6，对齐 Android ForegroundColorSpan。
    NSRange atRange = [s.string rangeOfString:@" @OctoWork"];
    XCTAssertNotEqual(atRange.location, NSNotFound);
    UIColor *color = [s attribute:NSForegroundColorAttributeName
                          atIndex:atRange.location
                   effectiveRange:NULL];
    XCTAssertNotNil(color);
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    XCTAssertEqualWithAccuracy(r, 0x8B / 255.0, 0.01);
    XCTAssertEqualWithAccuracy(g, 0x5C / 255.0, 0.01);
    XCTAssertEqualWithAccuracy(b, 0xF6 / 255.0, 0.01);
    XCTAssertEqualWithAccuracy(a, 1.0, 0.01);
}

// 3) legacy 降级（无 fromHomeSpaceId + fromIsExternal=1 + fromSourceSpaceName）→ 渲染 @SourceSpaceName
- (void)test_legacyFallback_RendersAtSourceSpaceName {
    WKMessageModel *model = [self modelWithExtras:@{
        @"from_is_external":        @1,
        @"from_source_space_name":  @"Acme",
    }];
    // viewerSpaceId 任意 —— legacy 路径不对比 home_space_id。
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceA"];
    XCTAssertTrue([s.string hasSuffix:@" @Acme"],
                  @"legacy fallback 应拼 ' @Acme', got: '%@'", s.string);
}

// 4) 空字符串（homeSpaceName="" 且 legacy 也无）→ 不渲染
- (void)test_emptyStrings_NoAtSuffix {
    WKMessageModel *model = [self modelWithExtras:@{
        @"from_home_space_id":   @"",
        @"from_home_space_name": @"",
        @"from_is_external":     @0,
    }];
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceA"];
    XCTAssertFalse([s.string containsString:@"@"],
                   @"空字段组合不应渲染 @ 后缀, got: '%@'", s.string);
}

// 5) 私聊频道（channelType=Person）→ 不渲染
- (void)test_personChannel_NoAtSuffix {
    WKMessage *m = [WKMessage new];
    m.fromUid = @"u_peer";
    m.channel = [[WKChannel alloc] initWith:@"u_peer" channelType:WK_PERSON];
    // 即便填了跨 Space 字段，也不应在私聊里拼 @。
    m.extra[@"from_home_space_id"] = @"spaceA";
    m.extra[@"from_home_space_name"] = @"OctoWork";
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:m];
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceB"];
    XCTAssertFalse([s.string containsString:@"@"],
                   @"私聊频道不应渲染 @ 后缀, got: '%@'", s.string);
}

@end
