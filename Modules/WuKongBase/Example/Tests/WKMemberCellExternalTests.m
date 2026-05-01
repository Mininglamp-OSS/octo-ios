//
//  WKMemberCellExternalTests.m
//  LiMaoBase_Tests
//
//  YUJ-190 — 群成员面板外部成员 @SpaceName 换行显示单元测试。
//
//  参考：
//    - WKMentionUserCellTests (YUJ-135) — 同款 viewer-relative 规则 + 复用测试模式
//    - Android PR#141 (YUJ-184) — @SpaceName 换行到第二行，企微样式对齐
//    - Web PR#1013 — @SpaceName 后缀数据规则
//
//  覆盖 3 个场景：
//    1. 外部成员 → attributedText 含换行符（\n）+ 多行 (numberOfLines == 2)
//    2. 同 Space 成员 → plain text，单行
//    3. cell 复用：外部 → 内部，numberOfLines 回落到 1，attributedText 清空
//

@import XCTest;
@import UIKit;
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKMemberCell.h"
#import "WKExternalViewerResolver.h"

@interface WKMemberCellExternalTests : XCTestCase
@property(nonatomic,strong) WKMemberCell *cell;
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKMemberCellExternalTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
    [d setObject:@"spaceViewer" forKey:@"currentSpaceId"];

    self.cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                    reuseIdentifier:@"WKMemberCellExternalTests"];
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

- (UILabel *)nameLbl {
    return [self.cell valueForKey:@"nameLbl"];
}

- (WKChannelMember *)memberWithName:(NSString *)name extras:(NSDictionary *)extras {
    WKChannelMember *m = [WKChannelMember new];
    m.memberUid = [@"u_" stringByAppendingString:name];
    m.memberName = name;
    m.memberAvatar = @"";
    m.extra = extras ? [extras mutableCopy] : [NSMutableDictionary dictionary];
    return m;
}

#pragma mark - 场景 1：外部成员 → @SpaceName 前插 `\n`，走 attributedText + 2 行布局

- (void)testExternalMember_WrapsSpaceSuffixToSecondLine {
    WKChannelMember *m = [self memberWithName:@"Alice"
                                       extras:@{@"home_space_id": @"spaceA",
                                                @"home_space_name": @"OctoWork"}];
    [self.cell refresh:m checkOn:NO online:nil];

    UILabel *lbl = [self nameLbl];
    XCTAssertNotNil(lbl.attributedText);
    XCTAssertGreaterThan(lbl.attributedText.length, 0);
    // YUJ-190 关键断言：@SpaceName 前必须是换行符而不是空格，防止 tail truncate 折断 SpaceName
    NSString *visible = lbl.attributedText.string;
    XCTAssertTrue([visible containsString:@"\n@OctoWork"],
                  @"expected '\\n@OctoWork' suffix, got: %@", visible);
    XCTAssertFalse([visible containsString:@" @OctoWork"],
                   @"should not fall back to space-prefixed suffix; got: %@", visible);
    XCTAssertEqual(lbl.numberOfLines, 2);
}

#pragma mark - 场景 2：同 Space 成员 → plain text，单行

- (void)testSameSpaceMember_RendersPlainTextSingleLine {
    WKChannelMember *m = [self memberWithName:@"Bob"
                                       extras:@{@"home_space_id": @"spaceViewer", // 同 viewer space
                                                @"home_space_name": @"OctoWork"}];
    [self.cell refresh:m checkOn:NO online:nil];

    UILabel *lbl = [self nameLbl];
    XCTAssertNil(lbl.attributedText);
    XCTAssertEqualObjects(lbl.text, @"Bob");
    XCTAssertEqual(lbl.numberOfLines, 1);
}

#pragma mark - 场景 3：cell 复用 → 外部 → 同 Space，numberOfLines 回退到 1 并清空 attributedText

- (void)testCellReuse_ExternalThenInternal_ResetsLayout {
    WKChannelMember *ext = [self memberWithName:@"Alice"
                                         extras:@{@"home_space_id": @"spaceA",
                                                  @"home_space_name": @"OctoWork"}];
    [self.cell refresh:ext checkOn:NO online:nil];
    XCTAssertGreaterThan([self nameLbl].attributedText.length, 0);
    XCTAssertEqual([self nameLbl].numberOfLines, 2);

    WKChannelMember *internal = [self memberWithName:@"Bob"
                                              extras:@{@"home_space_id": @"spaceViewer"}];
    [self.cell refresh:internal checkOn:NO online:nil];

    UILabel *lbl = [self nameLbl];
    XCTAssertNil(lbl.attributedText);
    XCTAssertEqualObjects(lbl.text, @"Bob");
    XCTAssertEqual(lbl.numberOfLines, 1);
}

@end
