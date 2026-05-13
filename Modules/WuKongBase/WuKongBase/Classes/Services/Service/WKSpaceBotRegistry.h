//
//  WKSpaceBotRegistry.h
//  WuKongBase
//
//  存放每个 Space 的 Bot UID 成员集合，用于跨 Space Bot 消息过滤兜底。
//  数据来源：服务端 `/robot/my_bots?space_id=X` ∪ `/robot/space_bots?space_id=X (status=added)`。
//  与 `Modules/WuKongContacts/.../WKBotListVM.m` 用同一组接口、同一合并规则。
//
//  存在动机：服务端对 Bot DM 消息的 channel_id 不带 `s{spaceId}_` 前缀，且
//  Bot 消息 payload 不含 `space_id`（线上日志已确认），导致 channel-id / message
//  / channelInfo.extra 三层信号同时缺失。本注册表是唯一可用的"该 Bot 属于哪个
//  Space" 的客户端权威信号。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKSpaceBotMembership) {
    /// 当前 Space 的 Bot 列表尚未加载（冷启动 / 切 Space race 窗口）。
    /// 调用方应 fail-open（保留），由后续 prune 兜底清理。
    WKSpaceBotMembershipUnknown = 0,
    /// Bot 在当前 Space 的 my_bots ∪ added space_bots 集合内 → 应显示。
    WKSpaceBotMembershipMember,
    /// Bot 已加载但不在当前 Space 集合内 → 应过滤。
    WKSpaceBotMembershipNotMember,
};

/// 加载完成时通过 NSNotificationCenter 广播；userInfo[@"space_id"] 为加载完成的 Space。
/// 监听者（如 WKConversationListVC）可在此时机做 prune。
extern NSString * const WKSpaceBotRegistryDidLoadNotification;

@interface WKSpaceBotRegistry : NSObject

+ (instancetype)shared;

/// 异步拉取并缓存指定 Space 的 Bot UID 集合。
/// 同一 Space 的并发调用会聚合为单次网络请求；caller 通过 completion 拿结果。
/// 缓存策略：内存为主，每次启动 + 每次切 Space 重新拉取（与 web 一致）。
- (void)loadBotsForSpace:(NSString *)spaceId
              completion:(nullable void(^)(BOOL success))completion;

/// 三态查询：用于 conversation list 的 bot 隔离 gate。
- (WKSpaceBotMembership)membershipForBotUID:(NSString *)botUID
                                    inSpace:(NSString *)spaceId;

/// 切 Space 时调用：清掉所有缓存（旧 Space 集合不再有意义，且避免内存膨胀）。
- (void)resetAllCaches;

@end

NS_ASSUME_NONNULL_END
