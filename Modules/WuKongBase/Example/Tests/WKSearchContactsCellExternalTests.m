//
//  WKSearchContactsCellExternalTests.m
//  LiMaoBase_Tests
//
//  — 搜索结果外部成员/群 @SpaceName 后缀单元测试。
//
//  覆盖：
//    1. 外部成员（home_space_id ≠ viewer）→ nameLbl.attributedText 尾部含 " @SpaceName"
//    2. 同 Space 成员（home_space_id == viewer）→ 不拼后缀（仅高亮）
//    3. Legacy 路径（is_external=1 + source_space_name）→ 走 source_space_name
//    4. cell 复用：外部 → 内部 → attributedText 不残留
//

@import XCTest;
@import UIKit;
#import "WKSearchContactsCell.h"
#import "WKExternalViewerResolver.h"

@interface WKSearchContactsCellExternalTests : XCTestCase
@property(nonatomic,strong) WKSearchContactsCell *cell;
@property(nonatomic,copy) NSString *savedViewerSpaceId;
@end

@implementation WKSearchContactsCellExternalTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self.savedViewerSpaceId = [[d stringForKey:@"currentSpaceId"] copy];
    [d setObject:@"spaceViewer" forKey:@"currentSpaceId"];

    self.cell = [[WKSearchContactsCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"WKSearchContactsCellExternalTests"];
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

- (WKSearchContactsModel *)modelWithName:(NSString *)name
                             homeSpaceId:(NSString *)homeSpaceId
                           homeSpaceName:(NSString *)homeSpaceName
                              isExternal:(NSNumber *)isExternal
                         sourceSpaceName:(NSString *)sourceSpaceName {
    WKSearchContactsModel *m = [WKSearchContactsModel new];
    m.name = name;
    m.avatar = @"";
    m.home_space_id = homeSpaceId;
    m.home_space_name = homeSpaceName;
    m.is_external = isExternal;
    m.source_space_name = sourceSpaceName;
    return m;
}

- (void)testExternalMember_AppendsSpaceSuffix {
    WKSearchContactsModel *m = [self modelWithName:@"Alice"
                                        homeSpaceId:@"spaceA"
                                      homeSpaceName:@"OctoWork"
                                         isExternal:nil
                                    sourceSpaceName:nil];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertGreaterThan(lbl.attributedText.length, 0);
    XCTAssertEqualObjects(lbl.attributedText.string, @"Alice @OctoWork");
}

- (void)testSameSpaceMember_NoSuffix {
    WKSearchContactsModel *m = [self modelWithName:@"Bob"
                                        homeSpaceId:@"spaceViewer"
                                      homeSpaceName:@"OctoWork"
                                         isExternal:nil
                                    sourceSpaceName:nil];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertEqualObjects(lbl.attributedText.string, @"Bob");
}

- (void)testLegacyExternalMember_UsesSourceSpaceName {
    WKSearchContactsModel *m = [self modelWithName:@"Carol"
                                        homeSpaceId:nil
                                      homeSpaceName:nil
                                         isExternal:@(1)
                                    sourceSpaceName:@"CustomerCo"];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertEqualObjects(lbl.attributedText.string, @"Carol @CustomerCo");
}

- (void)testNoExternalFields_NoSuffix {
    WKSearchContactsModel *m = [self modelWithName:@"Dan"
                                        homeSpaceId:nil
                                      homeSpaceName:nil
                                         isExternal:nil
                                    sourceSpaceName:nil];
    [self.cell refresh:m];
    UILabel *lbl = [self nameLbl];
    XCTAssertEqualObjects(lbl.attributedText.string, @"Dan");
}

// 坑点：cell 复用时外部后缀必须随 refresh 重置，否则残留上一次 @Space
- (void)testCellReuse_ExternalThenInternal_ClearsSuffix {
    WKSearchContactsModel *ext = [self modelWithName:@"Alice"
                                          homeSpaceId:@"spaceA"
                                        homeSpaceName:@"OctoWork"
                                           isExternal:nil
                                      sourceSpaceName:nil];
    [self.cell refresh:ext];
    XCTAssertEqualObjects([self nameLbl].attributedText.string, @"Alice @OctoWork");

    WKSearchContactsModel *internal = [self modelWithName:@"Bob"
                                               homeSpaceId:@"spaceViewer"
                                             homeSpaceName:@"OctoWork"
                                                isExternal:nil
                                           sourceSpaceName:nil];
    [self.cell refresh:internal];
    XCTAssertEqualObjects([self nameLbl].attributedText.string, @"Bob");
}

@end
