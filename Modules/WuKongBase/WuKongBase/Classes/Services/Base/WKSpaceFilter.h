//
//  WKSpaceFilter.h
//  WuKongBase
//
//  Space 隔离过滤工具（对齐 web PR #1036 #1037 #1039 #1043）
//  - shouldSkipChannelForSpace: 双路径（space_prefix / channelInfo cache）+ source_space_id 兜底
//  - shouldSkipMessageForSpace: 私聊 content.space_id 过滤
//  - getMyMembershipSourceSpaceId: 外部群成员身份查询
//  - currentSpaceId: APIClient X-Space-Id header 动态注入源
//
//  Created by Titan on 2026-04-29.
//

#import <Foundation/Foundation.h>

@class WKChannel;
@class WKMessage;

NS_ASSUME_NONNULL_BEGIN

/// 频道 Space 归属判定三值
typedef NS_ENUM(NSInteger, WKSpaceFilterDecision) {
    /// 不跳过：匹配当前 Space / Person / 空 Space 上下文 / 外部成员身份命中
    WKSpaceFilterDecisionKeep     = 0,
    /// 跳过：明确归属其他 Space 且我也不是外部成员
    WKSpaceFilterDecisionSkip     = 1,
    /// fail-open：channelInfo 尚未缓存，无法判定（调用方可走兼容路径）
    WKSpaceFilterDecisionFailOpen = 2,
};

/// 数据提供者协议（便于单元测试注入桩，不依赖 WKSDK runtime）
@protocol WKSpaceFilterDataProvider <NSObject>
/// 读群聊 space_id（来自 channelInfo.extra[@"space_id"]）；未缓存返回 nil
- (nullable NSString *)spaceIdForChannelId:(NSString *)channelId
                               channelType:(uint8_t)channelType;

/// 读自己在该群的 subscriber.source_space_id；未缓存返回 nil
- (nullable NSString *)mySourceSpaceIdForChannelId:(NSString *)channelId
                                       channelType:(uint8_t)channelType;
@end

@interface WKSpaceFilter : NSObject

+ (instancetype)shared;

#pragma mark - Space ID 源

/// 当前 Space ID（NSUserDefaults `currentSpaceId`），空字符串/nil 统一返回 nil
- (nullable NSString *)currentSpaceId;

#pragma mark - L1 判定

/// 纯函数：核心 7 分支判定（space_empty / space_prefix / person-pass /
///                            cached-match / cached-external-member / cached-mismatch / fail-open）
/// 供单元测试直接调用（不依赖 WKSDK / NSUserDefaults）
+ (WKSpaceFilterDecision)decideWithChannelId:(nullable NSString *)channelId
                                  channelType:(uint8_t)channelType
                               currentSpaceId:(nullable NSString *)currentSpaceId
                               channelSpaceId:(nullable NSString *)channelSpaceId
                              mySourceSpaceId:(nullable NSString *)mySourceSpaceId;

/// 三值判定（内部使用 shared provider + currentSpaceId）
- (WKSpaceFilterDecision)decideChannel:(NSString *)channelId
                           channelType:(uint8_t)channelType;

/// 便捷二值：YES = 跳过；NO = 不跳过（含 fail-open）
- (BOOL)shouldSkipChannelForSpace:(NSString *)channelId
                      channelType:(uint8_t)channelType;

#pragma mark - 消息级过滤（私聊）

/// 私聊消息级 space_id 过滤
/// - 非 Person 频道: 直接 NO（不跳过）
/// - 无 currentSpaceId: NO
/// - content.space_id 为空（历史消息）: NO（向前兼容，全空间可见）
/// - content.space_id != currentSpaceId: YES
- (BOOL)shouldSkipMessageForSpace:(WKMessage *)message
                      channelType:(uint8_t)channelType;

#pragma mark - 外部群成员身份

/// 查自己在该群的 subscriber.source_space_id；非群聊/未缓存返回 nil
- (nullable NSString *)getMyMembershipSourceSpaceId:(WKChannel *)channel;

#pragma mark - 测试注入

/// 数据提供者，默认为读 WKSDK 的真实实现。单元测试可替换为桩实现。
@property (nonatomic, strong) id<WKSpaceFilterDataProvider> provider;

@end

NS_ASSUME_NONNULL_END
