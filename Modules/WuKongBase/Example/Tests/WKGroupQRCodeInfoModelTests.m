//
//  WKGroupQRCodeInfoModelTests.m
//  LiMaoBase_Tests
//
//  (iOS EP8) — ChannelQrcodeResp.invite_url 字段透传单元测试。
//
//  对齐 web PR #971 / #972：二维码页复制的应该是 `invite_url`（跨 Space 扫码
//  入群链接），而不是 `qrcode` 字段（二维码图片内容）。
//
//  这些用例是对 静默失败模式的直接防御：如果后端字段改名或类型变化，
//  model 层必须归一化为 nil，而不是把错误类型的对象塞到 UI 层。
//

@import XCTest;
#import "WKGroupQRCodeVM.h"

@interface WKGroupQRCodeInfoModelTests : XCTestCase
@end

@implementation WKGroupQRCodeInfoModelTests

#pragma mark - 正常字段透传

- (void)testFromMap_InviteUrlPresent_ParsedAsIs {
    NSDictionary *dict = @{
        @"day": @7,
        @"expire": @"2026-05-06",
        @"qrcode": @"wk://group/g1?token=abc",
        @"invite_url": @"https://im.example.com/invite/g1?token=xyz",
    };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertEqualObjects(m.inviteUrl, @"https://im.example.com/invite/g1?token=xyz");
    // 不能覆盖 qrcode 字段 — 两者是独立来源
    XCTAssertEqualObjects(m.qrcode, @"wk://group/g1?token=abc");
    XCTAssertEqual(m.day, 7);
    XCTAssertEqualObjects(m.expire, @"2026-05-06");
}

- (void)testFromMap_InviteUrlDifferentFromQrcode_NotConfused {
    // 明确锁死：UI 层拿到的 invite_url 和 qrcode 是两个独立字段，
    // 避免 web 历史上出现过的 "复制按钮复制了 qrcode 图片 URL" 这种回归。
    NSDictionary *dict = @{
        @"qrcode": @"QRCODE_IMAGE_PAYLOAD",
        @"invite_url": @"INVITE_URL_TEXT",
    };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertEqualObjects(m.inviteUrl, @"INVITE_URL_TEXT");
    XCTAssertEqualObjects(m.qrcode, @"QRCODE_IMAGE_PAYLOAD");
    XCTAssertNotEqualObjects(m.inviteUrl, m.qrcode);
}

#pragma mark - 兼容旧后端

- (void)testFromMap_InviteUrlMissing_Nil {
    // 后端老版本不返回 invite_url — 不能崩溃，inviteUrl 必须是 nil 以便
    // UI 层把按钮藏起来。
    NSDictionary *dict = @{
        @"day": @3,
        @"qrcode": @"wk://group/g2",
    };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertNil(m.inviteUrl);
}

- (void)testFromMap_InviteUrlNSNull_Nil {
    // NSNull 是 NSJSONSerialization 对 JSON null 的默认产物，必须归一为 nil。
    NSDictionary *dict = @{
        @"invite_url": [NSNull null],
        @"qrcode": @"wk://x",
    };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertNil(m.inviteUrl);
}

- (void)testFromMap_InviteUrlWrongType_Nil {
    // 如果后端误发 number / dict，宁可让按钮隐藏，也绝不把错误类型塞给
    // UIPasteboard（那会 crash）。
    NSDictionary *dict = @{ @"invite_url": @(12345) };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertNil(m.inviteUrl);

    NSDictionary *dict2 = @{ @"invite_url": @{@"nested": @"x"} };
    WKGroupQRCodeInfoModel *m2 = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict2 type:0];
    XCTAssertNil(m2.inviteUrl);
}

- (void)testFromMap_InviteUrlEmptyString_KeepsEmptyString {
    // 空字符串也由 model 透传，UI 层负责 trim 后再决定是否隐藏按钮。
    // 这里不做隐式转换，避免 "空串 vs nil" 的歧义。
    NSDictionary *dict = @{ @"invite_url": @"" };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:dict type:0];
    XCTAssertEqualObjects(m.inviteUrl, @"");
}

#pragma mark - 契约锁死（防 ）

- (void)testFromMap_KeyIsInviteUrl_NotInviteURL {
    // 锁死字段名大小写：后端契约是 snake_case `invite_url`。
    // 如果有人误写成 `inviteUrl` 或 `invite_URL`，这条 assert 会失败。
    NSDictionary *wrong = @{ @"inviteUrl": @"should_not_match" };
    WKGroupQRCodeInfoModel *m = (WKGroupQRCodeInfoModel *)[WKGroupQRCodeInfoModel fromMap:wrong type:0];
    XCTAssertNil(m.inviteUrl);
}

@end
