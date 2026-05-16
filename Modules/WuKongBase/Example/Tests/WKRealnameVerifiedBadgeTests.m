//
//  WKRealnameVerifiedBadgeTests.m
//  WuKongBase Tests
//
//  / Phase A — 聊天气泡 + 群成员列表实名 ✓ 徽章
//  可见性单元测试。跨端对齐：web `RealnameVerifiedBadge` / android
//  `ic_realname_verified.xml`。
//
//  覆盖：
//    1. WKChannelUtil isRealnameVerifiedFromExtra: — tri-state 纯函数
//       (P1-2)：@YES / @NO / nil 三态，NSNumber / NSString /
//       nil / NSNull / 未预期类型 多种形态容忍度。
//    2. WKMemberCell — 显式 true 显；显式 false 隐；字段缺失隐；cell 复用；
//       image 必须非 nil（P0-1 回归保护：Images.xcassets/Common/
//       provides-namespace 漏 Common/ 前缀时 imageNamed: 返 nil，单测拦截）。
//    3. WKMessageCell — 属性存在性（保证编译面）。
//

@import XCTest;
@import UIKit;
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKChannelUtil.h"
#import "WKMemberCell.h"
#import "WKMessageCell.h"

@interface WKRealnameVerifiedBadgeTests : XCTestCase
@end

@implementation WKRealnameVerifiedBadgeTests

#pragma mark - 1. WKChannelUtil isRealnameVerifiedFromExtra: (tri-state)

// nil 输入 / 非 dict 输入 → nil（字段不存在，允许 fallback）
- (void)test_extra_nilReturnsNil {
    XCTAssertNil([WKChannelUtil isRealnameVerifiedFromExtra:nil]);
}

- (void)test_extra_missingKeyReturnsNil {
    XCTAssertNil([WKChannelUtil isRealnameVerifiedFromExtra:@{@"other": @1}]);
}

- (void)test_extra_NSNullReturnsNil {
    XCTAssertNil([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": [NSNull null]}]);
}

// 显式 true（数字 / 字符串多形态）→ @YES
- (void)test_extra_number1ReturnsYES {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @1}], @YES);
}

- (void)test_extra_numberYESReturnsYES {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @YES}], @YES);
}

- (void)test_extra_stringTrueReturnsYES {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"1"}], @YES);
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"true"}], @YES);
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"YES"}], @YES);
}

// 显式 false → @NO（注意：不是 nil，避免 fallback 到 person cache）
- (void)test_extra_number0ReturnsExplicitNO {
    NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @0}];
    XCTAssertNotNil(flag, @"显式 false 必须返 @NO 而非 nil，否则调用方会 fallback");
    XCTAssertEqualObjects(flag, @NO);
}

- (void)test_extra_numberNOReturnsExplicitNO {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @NO}], @NO);
}

- (void)test_extra_stringFalseReturnsExplicitNO {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"0"}], @NO);
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"false"}], @NO);
}

- (void)test_extra_emptyStringTreatedAsExplicitNO {
    XCTAssertEqualObjects([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @""}], @NO);
}

// 未预期类型 / 未预期字符串 → nil（让 fallback 生效）
- (void)test_extra_unexpectedTypeReturnsNil {
    XCTAssertNil([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @[@1]}]);
    XCTAssertNil([WKChannelUtil isRealnameVerifiedFromExtra:@{@"realname_verified": @"maybe"}]);
}

#pragma mark - 2. WKMemberCell realnameVerifiedImgView 可见性 + image 非 nil

- (WKChannelMember *)memberWithName:(NSString *)name extras:(NSDictionary *)extras {
    WKChannelMember *m = [WKChannelMember new];
    m.memberUid = [@"u_" stringByAppendingString:name];
    m.memberName = name;
    m.memberAvatar = @"";
    m.extra = extras ? [extras mutableCopy] : [NSMutableDictionary dictionary];
    return m;
}

- (UIImageView *)badgeOnCell:(WKMemberCell *)cell {
    return [cell valueForKey:@"realnameVerifiedImgView"];
}

// P0-1 回归保护：image 必须非 nil（Images.xcassets/Common/ namespace 路径正确）
- (void)test_memberCell_badgeImageNotNil {
    WKMemberCell *cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"t"];
    WKChannelMember *m = [self memberWithName:@"Alice"
                                       extras:@{@"realname_verified": @1}];
    [cell refresh:m checkOn:NO online:nil];

    UIImageView *badge = [self badgeOnCell:cell];
    XCTAssertNotNil(badge);
    XCTAssertNotNil(badge.image,
                    @"图片资源必须加载成功 — Common/ namespace 前缀遗漏会让 imageNamed: 返 nil (P0)");
}

- (void)test_memberCell_verifiedShowsBadge {
    WKMemberCell *cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"t"];
    WKChannelMember *m = [self memberWithName:@"Alice"
                                       extras:@{@"realname_verified": @1}];
    [cell refresh:m checkOn:NO online:nil];

    UIImageView *badge = [self badgeOnCell:cell];
    XCTAssertNotNil(badge);
    XCTAssertFalse(badge.hidden, @"realname_verified=1 下应显示 ✓");
    XCTAssertNotNil(badge.image, @"显示时 image 必须存在 (否则 UIImageView 是空框)");
}

- (void)test_memberCell_unverifiedHidesBadge {
    WKMemberCell *cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"t"];
    WKChannelMember *m = [self memberWithName:@"Bob"
                                       extras:@{@"realname_verified": @0}];
    [cell refresh:m checkOn:NO online:nil];

    UIImageView *badge = [self badgeOnCell:cell];
    XCTAssertTrue(badge.hidden, @"realname_verified=0 下徽章必须隐藏");
}

- (void)test_memberCell_missingFieldHidesBadge {
    WKMemberCell *cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"t"];
    WKChannelMember *m = [self memberWithName:@"Carol" extras:nil];
    [cell refresh:m checkOn:NO online:nil];

    UIImageView *badge = [self badgeOnCell:cell];
    XCTAssertTrue(badge.hidden,
                  @"字段缺失且 person cache 无命中时，徽章必须隐藏 (不给未实名用户加任何标)");
}

// cell 复用：verified → unverified 必须把 hidden 重置回 YES
- (void)test_memberCell_reuseVerifiedThenUnverifiedResetsHidden {
    WKMemberCell *cell = [[WKMemberCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:@"t"];

    WKChannelMember *a = [self memberWithName:@"Alice"
                                       extras:@{@"realname_verified": @1}];
    [cell refresh:a checkOn:NO online:nil];
    XCTAssertFalse([self badgeOnCell:cell].hidden);

    WKChannelMember *b = [self memberWithName:@"Bob"
                                       extras:@{@"realname_verified": @0}];
    [cell refresh:b checkOn:NO online:nil];
    XCTAssertTrue([self badgeOnCell:cell].hidden,
                  @"cell 复用后，未实名成员必须把 ✓ 隐藏回去");
}

#pragma mark - 3. WKMessageCell 属性存在性（保证编译面）

- (void)test_messageCell_hasRealnameVerifiedImgView {
    // 只做 class 层面的 selector introspection，避免触发 WKMessageCell
    // 的 initUI / WKApp / AsyncDisplayKit 依赖。
    XCTAssertTrue([WKMessageCell instancesRespondToSelector:@selector(realnameVerifiedImgView)],
                  @"WKMessageCell 必须声明 realnameVerifiedImgView 属性");
    XCTAssertTrue([WKMessageCell instancesRespondToSelector:@selector(setRealnameVerifiedImgView:)],
                  @"WKMessageCell 必须声明 realnameVerifiedImgView setter");
}

@end
