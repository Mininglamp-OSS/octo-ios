// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKJoinGroupSuccessHelper.m
//  WuKongBase
//
//  — see header for contract.
//

#import "WKJoinGroupSuccessHelper.h"

/// NSUserDefaults 兜底 key —— 如果 app 在 toast 消费前被杀，下次冷启动
/// 仍可重放一次跨 Space 通知。与 Web sessionStorage 语义略有区别（Web
/// 关闭 tab 即丢），但 iOS 的"冷启动后再弹一次"在用户预期内更友好。
static NSString * const kWKJoinSuccessNoticeKey = @"WKJoinGroupSuccessNoticeV1";

/// Notice 有效期（秒）。超过就当作过期丢弃，避免用户几天前加过群今天
/// 启动 app 还莫名弹切换提示。
static const NSTimeInterval kWKJoinSuccessNoticeTTL = 24 * 60 * 60;

@implementation WKJoinGroupSuccessNotice

- (NSDictionary *)toDict {
    return @{
        @"groupNo": self.groupNo ?: @"",
        @"groupName": self.groupName ?: @"",
        @"targetSpaceId": self.targetSpaceId ?: @"",
        @"spaceName": self.spaceName ?: @"",
        @"viewerSpaceId": self.viewerSpaceId ?: @"",
        @"savedAt": @(self.savedAt),
    };
}

+ (instancetype)fromDict:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    WKJoinGroupSuccessNotice *n = [WKJoinGroupSuccessNotice new];
    n.groupNo = [dict[@"groupNo"] isKindOfClass:[NSString class]] ? dict[@"groupNo"] : @"";
    n.groupName = [dict[@"groupName"] isKindOfClass:[NSString class]] ? dict[@"groupName"] : @"";
    n.targetSpaceId = [dict[@"targetSpaceId"] isKindOfClass:[NSString class]] ? dict[@"targetSpaceId"] : @"";
    n.spaceName = [dict[@"spaceName"] isKindOfClass:[NSString class]] ? dict[@"spaceName"] : nil;
    n.viewerSpaceId = [dict[@"viewerSpaceId"] isKindOfClass:[NSString class]] ? dict[@"viewerSpaceId"] : nil;
    n.savedAt = [dict[@"savedAt"] isKindOfClass:[NSNumber class]] ? [dict[@"savedAt"] doubleValue] : 0;
    return n;
}

@end

@implementation WKJoinGroupSuccessHelper

/// 持有一份内存态 notice。UserDefaults 只是兜底（进程被杀 / 冷启动场景），
/// 同进程内以内存态为准以避免 I/O 延迟 + 多次写盘。
static WKJoinGroupSuccessNotice *sInMemoryNotice = nil;
static dispatch_queue_t _noticeQueue() {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        q = dispatch_queue_create("com.dmwork.joingroup.notice", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

+ (NSString *)normalizedString:(id)value {
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (nullable NSString *)currentViewerSpaceId {
    NSString *sid = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    sid = [[self normalizedString:sid] length] > 0 ? sid : nil;
    return sid;
}

+ (BOOL)computeAndSaveWithGroupNo:(NSString *)groupNo
                    targetSpaceId:(NSString *)targetSpaceId
                        groupName:(NSString *)groupName
                        spaceName:(NSString *)spaceName {
    NSString *normalizedGroupNo = [self normalizedString:groupNo];
    NSString *normalizedTargetSpaceId = [self normalizedString:targetSpaceId];
    NSString *viewerSpaceId = [self currentViewerSpaceId];

    // 契约：group_no 必填，target space_id 必填，否则 UI 层没法弹切换按钮。
    if (normalizedGroupNo.length == 0 || normalizedTargetSpaceId.length == 0) {
        return NO;
    }

    // 同 Space（包括 viewer 也没登录到任何 Space 且 target 未知）— 走普通 toast。
    // Web computeAndSaveJoinSuccess 里 crossSpace = viewerSpaceId && targetSpaceId && viewerSpaceId !== targetSpaceId；
    // iOS 对齐。
    if (viewerSpaceId.length > 0 && [viewerSpaceId isEqualToString:normalizedTargetSpaceId]) {
        // 用户其实在目标 Space，不需要切换；清空 stale 通知以免上次残留。
        [self clear];
        return NO;
    }
    // 没有 viewerSpaceId 的情况（比如刚登录还没选 Space）也当同 Space 处理，
    // 因为这时候弹「切换过去」没有意义（没 from 可切）。
    if (viewerSpaceId.length == 0) {
        [self clear];
        return NO;
    }

    WKJoinGroupSuccessNotice *notice = [WKJoinGroupSuccessNotice new];
    notice.groupNo = normalizedGroupNo;
    notice.groupName = [groupName isKindOfClass:[NSString class]] ? groupName : @"";
    notice.targetSpaceId = normalizedTargetSpaceId;
    notice.spaceName = [spaceName isKindOfClass:[NSString class]] ? spaceName : nil;
    notice.viewerSpaceId = viewerSpaceId;
    notice.savedAt = [[NSDate date] timeIntervalSince1970];

    dispatch_sync(_noticeQueue(), ^{
        sInMemoryNotice = notice;
    });

    // 写 NSUserDefaults 兜底；UI 消费后会调用 clear。
    [[NSUserDefaults standardUserDefaults] setObject:[notice toDict] forKey:kWKJoinSuccessNoticeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    return YES;
}

+ (nullable WKJoinGroupSuccessNotice *)peekNotice {
    __block WKJoinGroupSuccessNotice *mem = nil;
    dispatch_sync(_noticeQueue(), ^{
        mem = sInMemoryNotice;
    });
    if (mem) {
        return mem;
    }
    // Fallback: 从 UserDefaults 恢复（冷启动）。
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kWKJoinSuccessNoticeKey];
    WKJoinGroupSuccessNotice *restored = [WKJoinGroupSuccessNotice fromDict:dict];
    if (!restored || restored.groupNo.length == 0 || restored.targetSpaceId.length == 0) {
        return nil;
    }
    // 过期 → 丢弃
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (restored.savedAt > 0 && (now - restored.savedAt) > kWKJoinSuccessNoticeTTL) {
        [self clear];
        return nil;
    }
    dispatch_sync(_noticeQueue(), ^{
        sInMemoryNotice = restored;
    });
    return restored;
}

+ (nullable WKJoinGroupSuccessNotice *)consumeNotice {
    WKJoinGroupSuccessNotice *notice = [self peekNotice];
    if (notice) {
        [self clear];
    }
    return notice;
}

+ (void)clear {
    dispatch_sync(_noticeQueue(), ^{
        sInMemoryNotice = nil;
    });
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWKJoinSuccessNoticeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
