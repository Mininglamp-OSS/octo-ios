//
//  WKMentionUserCellTests.m
//  LiMaoBase_Tests
//
//  YUJ-135 — @Mention 候选菜单外部成员 @SpaceName 后缀单元测试。
//
//  参考：
//    - WKMemberCell (YUJ-93 PR #66) — 同款 viewer-relative 规则的 UI 对齐
//    - Android RemindMemberAdapter.java — 跨端行为对齐
//    - Web createMentionSuggestion — @SpaceName 行为对齐
//
//  覆盖 4 个场景 + 1 个 YUJ-98 坑点专项（cell 复用时 attributedText 与 text 互斥）。
//  测试直接驱动 cell.refresh:，断言 nameLbl.text / nameLbl.attributedText。
//  设 viewerSpaceId 通过 NSUserDefaults "currentSpaceId"，与 WKExternalViewerResolver.currentViewerSpaceId 对齐。
//

@import XCTest;
@import UIKit;
#import "WKMentionUserCell.h"
#import "WKExternalViewerResolver.h"

@interface WKMentionUserCellTests : XCTestCase
@property(nonatomic,strong) WKMentionUserCell *cell;
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKMentionUserCellTests

- (void)setUp {
    [super setUp];
    // 保留并替换 currentSpaceId，确保各用例独立。
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
    [d setObject:@"spaceViewer" forKey:@"currentSpaceId"];

    self.cell = [[WKMentionUserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:@"WKMentionUserCellTests"];
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

// 取 nameLbl 的可见字符串 — attributedText 优先（外部成员路径），
// 否则 plain text（非外部路径）。便于断言拼接结果。
- (NSString *)visibleNameString {
    UILabel *lbl = [self.cell valueForKey:@"nameLbl"];
    if (lbl.attributedText.length > 0) {
        return lbl.attributedText.string;
    }
    return lbl.text ?: @"";
}

- (UILabel *)nameLbl {
    return [self.cell valueForKey:@"nameLbl"];
}

#pragma mark - 场景 1：外部成员 / 新字段 / home_space_id ≠ viewer → 追加 @SpaceName

- (void)testExternalMember_NewPath_RendersAttributedWithSpaceSuffix {
    WKMentionUserCellModel *m = [WKMentionUserCellModel uid:@"u1"
                                                        name:@"Alice"
                                                   avatarURL:nil
                                                       robot:NO
                                                      extras:@{
        @"home_space_id": @"spaceA",
        @"home_space_name": @"OctoWork",
    }];
    [self.cell refresh:m];

    UILabel *lbl = [self nameLbl];
    // 外部路径必须走 attributedText（YUJ-98 互斥约束：attributedText 非空时 text 不可见）。
    XCTAssertNotNil(lbl.attributedText);
    XCTAssertGreaterThan(lbl.attributedText.length, 0);
    XCTAssertEqualObjects([self visibleNameString], @"Alice @OctoWork");
}

#pragma mark - 场景 2：同 Space / home_space_id == viewer → 不追加后缀 plain text

- (void)testSameSpaceMember_NewPath_RendersPlainText {
    WKMentionUserCellModel *m = [WKMentionUserCellModel uid:@"u2"
                                                        name:@"Bob"
                                                   avatarURL:nil
                                                       robot:NO
                                                      extras:@{
        @"home_space_id": @"spaceViewer", // 与 NSUserDefaults currentSpaceId 一致 → 非外部
        @"home_space_name": @"OctoWork",
    }];
    [self.cell refresh:m];

    UILabel *lbl = [self nameLbl];
    // 非外部路径必须清空 attributedText 并走 plain text，否则 cell 复用时残留上一次外部富文本。
    XCTAssertNil(lbl.attributedText);
    XCTAssertEqualObjects(lbl.text, @"Bob");
}

#pragma mark - 场景 3：Legacy 降级 / 无 home_space_id 但 is_external=1 → 追加 source_space_name

- (void)testLegacyExternalMember_FallbackPath_RendersAttributedWithLegacyName {
    WKMentionUserCellModel *m = [WKMentionUserCellModel uid:@"u3"
                                                        name:@"Carol"
                                                   avatarURL:nil
                                                       robot:NO
                                                      extras:@{
        @"is_external": @(1),
        @"source_space_name": @"CustomerCo",
    }];
    [self.cell refresh:m];

    UILabel *lbl = [self nameLbl];
    XCTAssertNotNil(lbl.attributedText);
    XCTAssertEqualObjects([self visibleNameString], @"Carol @CustomerCo");
}

#pragma mark - 场景 4：无 extras / 非外部 → 不追加 plain text（向后兼容）

- (void)testNoExtras_RendersPlainText {
    WKMentionUserCellModel *m = [WKMentionUserCellModel uid:@"u4"
                                                        name:@"Dan"
                                                   avatarURL:nil
                                                       robot:NO
                                                      extras:nil];
    [self.cell refresh:m];

    UILabel *lbl = [self nameLbl];
    XCTAssertNil(lbl.attributedText);
    XCTAssertEqualObjects(lbl.text, @"Dan");
}

#pragma mark - YUJ-98 坑点：cell 复用时 attributedText / text 互斥，必须显式清空

- (void)testCellReuse_ExternalThenInternal_ClearsAttributedText {
    // 第一轮：外部成员 → attributedText 有后缀
    WKMentionUserCellModel *ext = [WKMentionUserCellModel uid:@"u1"
                                                          name:@"Alice"
                                                     avatarURL:nil
                                                         robot:NO
                                                        extras:@{
        @"home_space_id": @"spaceA",
        @"home_space_name": @"OctoWork",
    }];
    [self.cell refresh:ext];
    XCTAssertGreaterThan([self nameLbl].attributedText.length, 0);

    // 第二轮：同 cell 绑定一个非外部成员 → 必须清空 attributedText，否则 UI 会残留 "Alice @OctoWork"。
    WKMentionUserCellModel *internal = [WKMentionUserCellModel uid:@"u2"
                                                               name:@"Bob"
                                                          avatarURL:nil
                                                              robot:NO
                                                             extras:@{
        @"home_space_id": @"spaceViewer",
    }];
    [self.cell refresh:internal];

    UILabel *lbl = [self nameLbl];
    XCTAssertNil(lbl.attributedText);
    XCTAssertEqualObjects(lbl.text, @"Bob");
}

@end
