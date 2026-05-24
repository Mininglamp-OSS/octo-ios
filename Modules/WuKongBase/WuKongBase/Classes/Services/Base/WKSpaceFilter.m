//
//  WKSpaceFilter.m
//  WuKongBase
//
//  Created by Titan on 2026-04-29.
//

#import "WKSpaceFilter.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKApp.h"
#import "WKSpaceConvSyncCache.h"

static NSString *const kSpaceIdUserDefaultsKey = @"currentSpaceId";
static NSString *const kChannelSpaceIdExtraKey = @"space_id";
static NSString *const kMemberSourceSpaceIdExtraKey = @"source_space_id";

#pragma mark - Default Provider

@interface WKDefaultSpaceFilterDataProvider : NSObject <WKSpaceFilterDataProvider>
@end

@implementation WKDefaultSpaceFilterDataProvider

- (nullable NSString *)spaceIdForChannelId:(NSString *)channelId
                               channelType:(uint8_t)channelType {
    if (channelId.length == 0) return nil;
    WKChannel *channel = [WKChannel channelID:channelId channelType:channelType];
    WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:channel];
    // 1) DB（权威源）：依赖 `WKChannelUtil.toChannelInfo2:` / `WKGroupManagerDelegateImp`
    //    把 group 详情同步下来的 `space_id` 写入 `channelInfo.extra`。
    if (info && info.extra) {
        id value = info.extra[kChannelSpaceIdExtraKey];
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
            return (NSString *)value;
        }
    }
    // 2) 内存缓存兜底：conv sync（octo-server PR#154）已经下发 `space_id`，
    //    但群详情/channelInfo 还没到。PR #136 round-2 改用内存缓存而非 DB stub，
    //    以避免 stub channelInfo 阻塞 UI 的 `fetchChannelInfo` 真实加载（群名/头像）。
    NSString *cached = [[WKSpaceConvSyncCache shared] spaceIdForChannelId:channelId
                                                              channelType:channelType];
    if (cached.length > 0) {
        return cached;
    }
    return nil;
}

- (nullable NSString *)mySourceSpaceIdForChannelId:(NSString *)channelId
                                       channelType:(uint8_t)channelType {
    if (channelId.length == 0) return nil;
    if (channelType != WK_GROUP) return nil; // 私聊无 subscriber
    NSString *myUID = [WKApp shared].loginInfo.uid;
    if (![myUID isKindOfClass:[NSString class]] || myUID.length == 0) return nil;
    WKChannel *channel = [WKChannel channelID:channelId channelType:channelType];
    // 1) DB（权威源）：依赖 `WKGroupMemberModel.toChannelMember` 把
    //    `source_space_id` 写入 member.extra。注意 `get:memberUID:` 内部
    //    会过滤 `status=1`（active）+ `is_deleted=0`。
    WKChannelMember *member = [[WKChannelMemberDB shared] get:channel memberUID:myUID];
    if (member && member.extra) {
        id value = member.extra[kMemberSourceSpaceIdExtraKey];
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
            return (NSString *)value;
        }
    }
    // 2) 内存缓存兜底：conv sync 已下发 `my_source_space_id`，但 member 全量
    //    同步还没完成。PR #136 round-2 改用内存缓存而非 DB stub，原因：
    //    - `addOrUpdateMembers:` 写入的 row 默认 status=inactive，被
    //      `get:memberUID:` 的 `status=1` 过滤掉，stub 写了也读不回来；
    //    - 在已存在的 inactive row 上 upsert 还会错把已离群的人 mark 回 active。
    NSString *cached = [[WKSpaceConvSyncCache shared] mySourceSpaceIdForChannelId:channelId
                                                                      channelType:channelType];
    if (cached.length > 0) {
        return cached;
    }
    return nil;
}

@end


#pragma mark - WKSpaceFilter

@implementation WKSpaceFilter

+ (instancetype)shared {
    static WKSpaceFilter *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[WKSpaceFilter alloc] init];
        _instance.provider = [[WKDefaultSpaceFilterDataProvider alloc] init];
    });
    return _instance;
}

- (nullable NSString *)currentSpaceId {
    NSString *sid = [[NSUserDefaults standardUserDefaults] stringForKey:kSpaceIdUserDefaultsKey];
    if (![sid isKindOfClass:[NSString class]] || sid.length == 0) return nil;
    return sid;
}

#pragma mark - 前缀辅助

+ (BOOL)_isHex32:(NSString *)s {
    if (s.length != 32) return NO;
    for (NSUInteger i = 0; i < 32; i++) {
        unichar c = [s characterAtIndex:i];
        BOOL ok = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
        if (!ok) return NO;
    }
    return YES;
}

/// 检测并返回 `s{32hex}_rest` 格式中的 spaceId
+ (nullable NSString *)_spaceIdFromChannelPrefix:(NSString *)channelId {
    if (channelId.length < 34) return nil;
    if ([channelId characterAtIndex:0] != 's') return nil;
    if ([channelId characterAtIndex:33] != '_') return nil;
    NSString *hex = [channelId substringWithRange:NSMakeRange(1, 32)];
    if (![self _isHex32:hex]) return nil;
    return hex;
}

#pragma mark - 纯函数

+ (WKSpaceFilterDecision)decideWithChannelId:(nullable NSString *)channelId
                                  channelType:(uint8_t)channelType
                               currentSpaceId:(nullable NSString *)currentSpaceId
                               channelSpaceId:(nullable NSString *)channelSpaceId
                              mySourceSpaceId:(nullable NSString *)mySourceSpaceId {
    // 1. space-empty-pass
    if (currentSpaceId.length == 0) return WKSpaceFilterDecisionKeep;
    if (channelId.length == 0) return WKSpaceFilterDecisionKeep;

    // 2. space-prefix：`s{32hex}_*` 仅作为 Keep 的**快速路径**。
    //    前缀不匹配时**不**直接 Skip —— 必须继续跑 Person/Group 判定，
    //    否则外部群（owning Space 前缀与当前 Space 不同，但我以当前 Space 身份
    //    加入为外部成员）会被错杀。真正的 Skip 由 cached-mismatch 分支作出。
    NSString *prefixSpace = [self _spaceIdFromChannelPrefix:channelId];
    if (prefixSpace && [prefixSpace isEqualToString:currentSpaceId]) {
        return WKSpaceFilterDecisionKeep;
    }

    // 3. person-pass：私聊不按 channelId 过滤（另有消息级过滤）
    //    例外 1：私聊频道带 `s{otherSpace}_` 前缀（Bot/私聊 ID 由后端前缀化）
    //    时，必须 Skip——对齐 web `shouldSkipChannelForSpace`
    //    （dmwork-web/.../SpaceService.tsx:23-25）。"外部成员" 仅适用于群聊，
    //    私聊没有该语义，prefix-mismatch 直接表示该频道不属于当前 Space。
    //
    //    例外 2：channelId 无前缀（裸 UID 的 Bot/私聊），但 channelInfo 已缓存且
    //    `extra[@"space_id"]` 与当前 Space 不一致 → Skip。
    //    场景：在 Space A 添加的 Bot，channelInfo 标注 space_id=A；用户切到 B 后
    //    收到该 Bot 的延迟推送，前缀检查会落空（裸 UID），靠这条二级判定兜底。
    //    依赖 `WKChannelUtil.toChannelInfo2:` 持久化的 `extra[@"space_id"]`。
    //    info 未缓存（race）→ channelSpaceId 为 nil，Keep（向前兼容，避免误杀
    //    首次收到的合法私聊）。
    //
    //    无前缀且 channelInfo 不带 space_id 的情况（旧数据 / 单 Space 部署）→ Keep。
    if (channelType == WK_PERSON) {
        if (prefixSpace.length > 0) {
            return WKSpaceFilterDecisionSkip;
        }
        if (channelSpaceId.length > 0 && ![channelSpaceId isEqualToString:currentSpaceId]) {
            return WKSpaceFilterDecisionSkip;
        }
        return WKSpaceFilterDecisionKeep;
    }

    BOOL hasChannelSpace = (channelSpaceId.length > 0);
    BOOL hasMySource = (mySourceSpaceId.length > 0);

    // 4. cached-match / cached-external-member / cached-mismatch
    //    注意：只有在 `mySourceSpaceId` 已知（member record 已缓存）时才能作出
    //    Skip 判断；如果 member 数据尚未就绪，无法区分"非成员"和"member 未加载"，
    //    必须 fail-open 让 caller 走 whitelist / channelInfo 二次回调兜底，
    //    否则外部群在 member sync 期间会短暂消失（codex P2 回归）。
    if (hasChannelSpace) {
        if ([channelSpaceId isEqualToString:currentSpaceId]) {
            return WKSpaceFilterDecisionKeep;           // cached-match
        }
        if (hasMySource) {
            if ([mySourceSpaceId isEqualToString:currentSpaceId]) {
                return WKSpaceFilterDecisionKeep;       // cached-external-member
            }
            return WKSpaceFilterDecisionSkip;           // cached-mismatch（确知非当前 Space 成员）
        }
        // member 未缓存：不能武断 Skip，降级给 whitelist 判定
        return WKSpaceFilterDecisionFailOpen;
    }

    // 5. 仅成员缓存就绪（info 未回）但是我是当前 Space 的外部成员 → 放行
    if (hasMySource && [mySourceSpaceId isEqualToString:currentSpaceId]) {
        return WKSpaceFilterDecisionKeep;
    }

    // 6. fail-open：等 channelInfo 回调后二次检查
    return WKSpaceFilterDecisionFailOpen;
}

#pragma mark - 实例判定

- (WKSpaceFilterDecision)decideChannel:(NSString *)channelId
                           channelType:(uint8_t)channelType {
    NSString *current = [self currentSpaceId];
    NSString *channelSpace = [self.provider spaceIdForChannelId:channelId
                                                    channelType:channelType];
    NSString *mySource = [self.provider mySourceSpaceIdForChannelId:channelId
                                                        channelType:channelType];
    WKSpaceFilterDecision decision = [WKSpaceFilter decideWithChannelId:channelId
                                                            channelType:channelType
                                                         currentSpaceId:current
                                                         channelSpaceId:channelSpace
                                                        mySourceSpaceId:mySource];
    // [BotSpaceTrace] 仅 DEBUG 构建打日志，定位跨 Space Bot 是否被正确 Skip。
    // Release 不打：channelId / spaceId 是用户标识不应出现在生产日志（PR #118 review）。
#if DEBUG
    if(channelType == WK_PERSON) {
        const char *decStr = "Keep";
        if(decision == WKSpaceFilterDecisionSkip) decStr = "Skip";
        else if(decision == WKSpaceFilterDecisionFailOpen) decStr = "FailOpen";
        NSLog(@"[BotSpaceTrace] WKSpaceFilter.decideChannel channelId=%@ current=%@ channelSpaceId=%@ mySource=%@ → %s",
              channelId, current ?: @"<nil>",
              channelSpace ?: @"<nil>", mySource ?: @"<nil>", decStr);
    }
#endif
    return decision;
}

- (BOOL)shouldSkipChannelForSpace:(NSString *)channelId
                      channelType:(uint8_t)channelType {
    return [self decideChannel:channelId channelType:channelType] == WKSpaceFilterDecisionSkip;
}

#pragma mark - 消息级

- (BOOL)shouldSkipMessageForSpace:(WKMessage *)message
                      channelType:(uint8_t)channelType {
    if (channelType != WK_PERSON) return NO;
    NSString *current = [self currentSpaceId];
    if (current.length == 0) return NO;
    if (!message || !message.content) return NO;
    id value = message.content.contentDict[kChannelSpaceIdExtraKey];
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] == 0) {
        return NO; // 历史/旧消息无 space_id → 放行（向前兼容）
    }
    return ![(NSString *)value isEqualToString:current];
}

#pragma mark - 外部群身份

- (nullable NSString *)getMyMembershipSourceSpaceId:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) return nil;
    return [self.provider mySourceSpaceIdForChannelId:channel.channelId
                                          channelType:channel.channelType];
}

@end
