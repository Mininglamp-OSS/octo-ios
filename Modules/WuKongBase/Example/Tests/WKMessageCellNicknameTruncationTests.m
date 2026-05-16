// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageCellNicknameTruncationTests.m
//  WuKongBase Tests
//
//  — iOS 气泡 @SpaceName 昵称截断修复回归。
//
//  背景：`WKMessageCell.layoutName` 历史上把 nameLbl 宽度硬限到
//  WK_NICKNAME_MAX_WIDTH = 100pt，长昵称 + 长 @SpaceName 会被 UIKit
//  byTruncatingTail 截尾，把视觉焦点「@SpaceName」吞掉。
//
//  本测试覆盖三条不变式：
//   1. `+hasExternalSpaceSuffix:` 正确识别外部 / 非外部 / 私聊。
//   2. `+getNicknameSize:` 在外部场景返回包含 @SpaceName 后缀的宽度，
//      让 WKTextMessageCell.getContentSize 的 `MAX(size.width, nicknameWidth)`
//      能把气泡撑宽。普通群气泡维持原宽度（不受影响）。
//   3. `+getFromNameAttributed:` 为 baseName + 后缀都挂 NSFontAttributeName，
//      保障 boundingRectWithSize: 测量可靠。
//

@import XCTest;
#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMessageCell.h"
#import "WKMessageModel.h"
#import "WKExternalViewerResolver.h"

@interface WKMessageCellNicknameTruncationTests : XCTestCase
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKMessageCellNicknameTruncationTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
}

- (void)tearDown {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (self.savedViewerSpaceId) {
        [d setObject:self.savedViewerSpaceId forKey:@"currentSpaceId"];
    } else {
        [d removeObjectForKey:@"currentSpaceId"];
    }
    [super tearDown];
}

- (WKMessageModel *)modelInGroupWithExtras:(NSDictionary *)extras {
    WKMessage *m = [WKMessage new];
    m.fromUid = @"u_sender";
    m.channel = [[WKChannel alloc] initWith:@"g_group" channelType:WK_GROUP];
    for (NSString *k in extras) {
        m.extra[k] = extras[k];
    }
    return [[WKMessageModel alloc] initWithMessage:m];
}

#pragma mark - hasExternalSpaceSuffix:

// 跨 Space（viewer != sender.home）→ YES
- (void)test_hasExternalSpaceSuffix_crossSpace_YES {
    WKMessageModel *model = [self modelInGroupWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    // viewer 设成 spaceB
    [[NSUserDefaults standardUserDefaults] setObject:@"spaceB" forKey:@"currentSpaceId"];
    XCTAssertTrue([WKMessageCell hasExternalSpaceSuffix:model]);
}

// 同 Space → NO
- (void)test_hasExternalSpaceSuffix_sameSpace_NO {
    WKMessageModel *model = [self modelInGroupWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    [[NSUserDefaults standardUserDefaults] setObject:@"spaceA" forKey:@"currentSpaceId"];
    XCTAssertFalse([WKMessageCell hasExternalSpaceSuffix:model]);
}

// 私聊频道 → NO（与 getFromNameAttributed: 的私聊短路保持一致）
- (void)test_hasExternalSpaceSuffix_personChannel_NO {
    WKMessage *m = [WKMessage new];
    m.fromUid = @"u_peer";
    m.channel = [[WKChannel alloc] initWith:@"u_peer" channelType:WK_PERSON];
    m.extra[@"from_home_space_id"] = @"spaceA";
    m.extra[@"from_home_space_name"] = @"OctoWork";
    WKMessageModel *model = [[WKMessageModel alloc] initWithMessage:m];
    [[NSUserDefaults standardUserDefaults] setObject:@"spaceB" forKey:@"currentSpaceId"];
    XCTAssertFalse([WKMessageCell hasExternalSpaceSuffix:model]);
}

// nil model → NO（防御）
- (void)test_hasExternalSpaceSuffix_nil_NO {
    XCTAssertFalse([WKMessageCell hasExternalSpaceSuffix:nil]);
}

#pragma mark - getNicknameSize: 含 @SpaceName 后缀宽度

// 外部消息 → getNicknameSize 返回宽度 > 普通 baseName 宽度（后缀撑宽）
- (void)test_getNicknameSize_external_includesSuffixWidth {
    WKMessageModel *externalModel = [self modelInGroupWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"VeryLongSpaceNameForTruncationTest",
    }];
    [[NSUserDefaults standardUserDefaults] setObject:@"spaceB" forKey:@"currentSpaceId"];
    CGSize externalSize = [WKMessageCell getNicknameSize:externalModel];

    WKMessageModel *plainModel = [self modelInGroupWithExtras:@{}];
    CGSize plainSize = [WKMessageCell getNicknameSize:plainModel];

    XCTAssertGreaterThan(externalSize.width, plainSize.width,
                         @"external nickname size 应大于 plain（后缀撑宽）, external=%.1f plain=%.1f",
                         externalSize.width, plainSize.width);
}

// 同 Space → getNicknameSize 与不带 home_space 的完全一致（不撑宽，不影响普通气泡）
- (void)test_getNicknameSize_sameSpace_unchanged {
    WKMessageModel *sameSpaceModel = [self modelInGroupWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    [[NSUserDefaults standardUserDefaults] setObject:@"spaceA" forKey:@"currentSpaceId"];
    CGSize sameSize = [WKMessageCell getNicknameSize:sameSpaceModel];

    WKMessageModel *plainModel = [self modelInGroupWithExtras:@{}];
    CGSize plainSize = [WKMessageCell getNicknameSize:plainModel];

    XCTAssertEqualWithAccuracy(sameSize.width, plainSize.width, 0.5,
                               @"same-space 气泡不应被 @SpaceName 撑宽");
}

#pragma mark - getFromNameAttributed: 字体 attr

// 外部路径：baseName 与 suffix 都带 NSFontAttributeName（供测宽用）
- (void)test_getFromNameAttributed_external_hasFontAttr {
    WKMessageModel *model = [self modelInGroupWithExtras:@{
        @"from_home_space_id":   @"spaceA",
        @"from_home_space_name": @"OctoWork",
    }];
    NSAttributedString *s = [WKMessageCell getFromNameAttributed:model viewerSpaceId:@"spaceB"];
    XCTAssertGreaterThan(s.length, 0);
    // 起始位置（baseName 区）
    UIFont *headFont = [s attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
    XCTAssertNotNil(headFont, @"baseName 必须挂 NSFontAttributeName 供 boundingRectWithSize: 用");
    // 末尾位置（suffix 区）
    UIFont *tailFont = [s attribute:NSFontAttributeName atIndex:s.length - 1 effectiveRange:NULL];
    XCTAssertNotNil(tailFont, @"suffix 必须挂 NSFontAttributeName");
    // boundingRectWithSize: 必须返回非零宽度
    CGRect rect = [s boundingRectWithSize:CGSizeMake(500, CGFLOAT_MAX)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  context:nil];
    XCTAssertGreaterThan(rect.size.width, 0.0);
}

@end
