// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSearchMessageCellExternalTests.m
//  LiMaoBase_Tests
//
//  — 搜索消息结果 cell 外部群/发送者 @SpaceName 后缀单元测试。
//
//  覆盖：
//    1. 外部频道（home_space_id ≠ viewer）→ nameLbl.attributedText 含 " @SpaceName"
//    2. 同 Space → plain text，attributedText 为 nil
//    3. Legacy 降级 is_external + source_space_name → @SpaceName 仍生效
//    4. cell 复用：外部 → 内部 → attributedText 必须清空（坑点）
//
//  注：消息名来自 channelInfo.displayName（SDK 管理），无 channelInfo 时 name=""，
//  因此测试直接 set model 的频道，允许 name 为空；重点断言 attributedText 组件。
//

@import XCTest;
@import UIKit;
#import "WKSearchMessageCell.h"
#import "WKExternalViewerResolver.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKSearchMessageCellExternalTests : XCTestCase
@property(nonatomic,strong) WKSearchMessageCell *cell;
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKSearchMessageCellExternalTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
    [d setObject:@"spaceViewer" forKey:@"currentSpaceId"];

    self.cell = [[WKSearchMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:@"WKSearchMessageCellExternalTests"];
}

- (void)tearDown {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (self.savedViewerSpaceId) {
        [d setObject:self.savedViewerSpaceId forKey:@"currentSpaceId"];
    } else {
        [d removeObjectForKey:@"currentSpaceId"];
    }
    self.cell = nil;
    [super tearDown];
}

- (UILabel *)nameLbl { return [self.cell valueForKey:@"nameLbl"]; }

- (WKSearchMessageModel *)modelWithHomeSpaceId:(NSString *)homeSpaceId
                                  homeSpaceName:(NSString *)homeSpaceName
                                     isExternal:(NSNumber *)isExternal
                                sourceSpaceName:(NSString *)sourceSpaceName {
    WKSearchMessageModel *m = [WKSearchMessageModel new];
    m.channel = [WKChannel groupWithChannelID:@"g_test"];
    m.content = @"";
    m.keyword = @"";
    m.messageCount = @(0);
    m.home_space_id = homeSpaceId;
    m.home_space_name = homeSpaceName;
    m.is_external = isExternal;
    m.source_space_name = sourceSpaceName;
    return m;
}

- (void)testExternalSender_AppendsSpaceSuffix {
    WKSearchMessageModel *m = [self modelWithHomeSpaceId:@"spaceA"
                                            homeSpaceName:@"OctoWork"
                                               isExternal:nil
                                          sourceSpaceName:nil];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertNotNil(lbl.attributedText);
    XCTAssertTrue([lbl.attributedText.string hasSuffix:@" @OctoWork"]);
}

- (void)testSameSpace_PlainText {
    WKSearchMessageModel *m = [self modelWithHomeSpaceId:@"spaceViewer"
                                            homeSpaceName:@"OctoWork"
                                               isExternal:nil
                                          sourceSpaceName:nil];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertNil(lbl.attributedText);
}

- (void)testLegacyExternal_UsesSourceSpaceName {
    WKSearchMessageModel *m = [self modelWithHomeSpaceId:nil
                                            homeSpaceName:nil
                                               isExternal:@(1)
                                          sourceSpaceName:@"CustomerCo"];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertNotNil(lbl.attributedText);
    XCTAssertTrue([lbl.attributedText.string hasSuffix:@" @CustomerCo"]);
}

// 坑点：cell 复用时 attributedText / text 互斥，refresh 必须显式重置。
- (void)testCellReuse_ExternalThenInternal_ClearsAttributedText {
    WKSearchMessageModel *ext = [self modelWithHomeSpaceId:@"spaceA"
                                              homeSpaceName:@"OctoWork"
                                                 isExternal:nil
                                            sourceSpaceName:nil];
    [self.cell refresh:ext];
    XCTAssertNotNil([self nameLbl].attributedText);
    XCTAssertTrue([[self nameLbl].attributedText.string hasSuffix:@" @OctoWork"]);

    WKSearchMessageModel *internal = [self modelWithHomeSpaceId:@"spaceViewer"
                                                   homeSpaceName:@"OctoWork"
                                                      isExternal:nil
                                                 sourceSpaceName:nil];
    [self.cell refresh:internal];
    XCTAssertNil([self nameLbl].attributedText);
}

@end
