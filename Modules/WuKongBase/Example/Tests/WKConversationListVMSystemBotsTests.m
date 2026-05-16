//
//  WKConversationListVMSystemBotsTests.m
//  LiMaoBase_Tests
//
//  — `WKConversationListVM.ensureSystemBotsVisible` 单元测试。
//
//  场景：后端 sync 在当前 Space 不返回 botfather 时，VM 应本地兜底合成占位
//  conversation；同时尊重 WKBotFatherHidden_<spaceId> 隐藏标记、已存在 entry
//  时无操作、不写入 WKSDK cache。
//
//  对齐 Android Round-3 Fix C 的行为合约，硬约束：
//    - 仅挂在 VM 层 conversationWrapModels，不污染 WKSDK 持久化层（修复）
//    - 用户已删除（WKBotFatherHidden_*） → 不自动恢复
//    - 空 botfatherUID（定制部署） → 不合成
//

@import XCTest;
@import UIKit;
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationListVM.h"
#import "WKConversationWrapModel.h"

// 对齐 WKAppConfig 默认值（-init 中设为 "botfather"）；
// 若默认 UID 变更，测试会在第一个 case 立即炸出来。
static NSString * const kBotfatherUID = @"botfather";
static NSString * const kSpaceKey = @"currentSpaceId";
static NSString * const kHiddenPrefix = @"WKBotFatherHidden_";

@interface WKConversationListVMSystemBotsTests : XCTestCase
@end

@implementation WKConversationListVMSystemBotsTests

- (void)setUp {
    [super setUp];
    [[WKConversationListVM shared] reset];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSpaceKey];
}

- (void)tearDown {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:kSpaceKey];
    if(spaceId.length > 0) {
        NSString *hiddenKey = [NSString stringWithFormat:@"%@%@", kHiddenPrefix, spaceId];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hiddenKey];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSpaceKey];
    [[WKConversationListVM shared] reset];
    [super tearDown];
}

#pragma mark - 合成兜底

- (void)testEnsureSystemBotsVisible_MissingEntry_Synthesized {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_X" forKey:kSpaceKey];

    WKConversationListVM *vm = [WKConversationListVM shared];
    WKChannel *botfatherCh = [WKChannel personWithChannelID:kBotfatherUID];

    XCTAssertNil([vm modelAtChannel:botfatherCh], @"前置：VM 不存在 botfather entry");

    BOOL synthesized = [vm ensureSystemBotsVisible];
    XCTAssertTrue(synthesized, @"sync 未返回且未隐藏 → 应合成占位条目");
    XCTAssertNotNil([vm modelAtChannel:botfatherCh], @"合成后必须能查到");
}

- (void)testEnsureSystemBotsVisible_AlreadyPresent_NoOp {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_X" forKey:kSpaceKey];

    WKConversationListVM *vm = [WKConversationListVM shared];
    WKChannel *botfatherCh = [WKChannel personWithChannelID:kBotfatherUID];

    BOOL first = [vm ensureSystemBotsVisible];
    XCTAssertTrue(first);
    NSInteger countAfterFirst = [[vm allConversations] count];

    BOOL second = [vm ensureSystemBotsVisible];
    XCTAssertFalse(second, @"已存在 entry → 不应重复合成");
    XCTAssertEqual([[vm allConversations] count], countAfterFirst, @"allConversations 长度不应变化");
    XCTAssertNotNil([vm modelAtChannel:botfatherCh]);
}

- (void)testEnsureSystemBotsVisible_SpaceHidden_Skipped {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_X" forKey:kSpaceKey];
    // 模拟用户在 space_X 下主动删除 BotFather
    NSString *hiddenKey = [NSString stringWithFormat:@"%@space_X", kHiddenPrefix];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hiddenKey];

    WKConversationListVM *vm = [WKConversationListVM shared];
    WKChannel *botfatherCh = [WKChannel personWithChannelID:kBotfatherUID];

    BOOL synthesized = [vm ensureSystemBotsVisible];
    XCTAssertFalse(synthesized, @"用户已隐藏 → 不应自动恢复");
    XCTAssertNil([vm modelAtChannel:botfatherCh]);
}

- (void)testEnsureSystemBotsVisible_NoCurrentSpace_StillSynthesize {
    // 无 Space 上下文（罕见：Space 列表未加载完） — 仍应合成让用户看得到
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSpaceKey];

    WKConversationListVM *vm = [WKConversationListVM shared];
    BOOL synthesized = [vm ensureSystemBotsVisible];
    XCTAssertTrue(synthesized);
}

- (void)testEnsureSystemBotsVisible_HiddenInOtherSpace_StillSynthesizeInCurrent {
    // Space A 被用户删除，切到 Space B 时仍应兜底合成（hidden key 是 per-Space）
    NSString *hiddenKeyA = [NSString stringWithFormat:@"%@space_A", kHiddenPrefix];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:hiddenKeyA];
    [[NSUserDefaults standardUserDefaults] setObject:@"space_B" forKey:kSpaceKey];

    WKConversationListVM *vm = [WKConversationListVM shared];
    BOOL synthesized = [vm ensureSystemBotsVisible];
    XCTAssertTrue(synthesized, @"其它 Space 的 hidden 标记不应影响当前 Space");

    // cleanup
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:hiddenKeyA];
}

#pragma mark - 合成条目属性

- (void)testEnsureSystemBotsVisible_SynthesizedEntry_IsEmptyPerson {
    [[NSUserDefaults standardUserDefaults] setObject:@"space_X" forKey:kSpaceKey];
    WKConversationListVM *vm = [WKConversationListVM shared];
    [vm ensureSystemBotsVisible];

    WKChannel *botfatherCh = [WKChannel personWithChannelID:kBotfatherUID];
    WKConversationWrapModel *wrap = [vm modelAtChannel:botfatherCh];
    XCTAssertNotNil(wrap);
    XCTAssertEqual(wrap.channel.channelType, WK_PERSON, @"必须为 Person 频道类型");
    XCTAssertEqualObjects(wrap.channel.channelId, kBotfatherUID);
    XCTAssertEqual(wrap.unreadCount, 0, @"占位 entry 无未读");
    XCTAssertEqual(wrap.lastMsgTimestamp, 0, @"timestamp=0 → 排到列表底部");
}

- (void)testReset_AlsoDropsSynthesizedEntry {
    // 合成 → reset → 占位条目必须随 reset 自然丢弃（对齐 Space 切换 reset → sync 流程）
    [[NSUserDefaults standardUserDefaults] setObject:@"space_X" forKey:kSpaceKey];
    WKConversationListVM *vm = [WKConversationListVM shared];
    [vm ensureSystemBotsVisible];
    WKChannel *botfatherCh = [WKChannel personWithChannelID:kBotfatherUID];
    XCTAssertNotNil([vm modelAtChannel:botfatherCh]);

    [vm reset];
    XCTAssertNil([vm modelAtChannel:botfatherCh], @"reset 后占位条目应被清空");
}

@end
