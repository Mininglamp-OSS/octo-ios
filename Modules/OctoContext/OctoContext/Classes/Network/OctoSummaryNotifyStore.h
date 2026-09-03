//
//  OctoSummaryNotifyStore.h
//  OctoContext
//
//  群总结完成提示的两张本地账本, 与安卓 SummaryNotifyStore 一一对应:
//
//    SENT     —— 已经发过提示的 (taskId, channelId) 对。claim-before-send:
//                发之前先落账, 发失败再回滚, 保证"同一 task 同一群"只发一次。
//    ELIGIBLE —— "本机发起过"的 taskId + 时间戳。只在创建 / 重新生成成功那一刻写,
//                10 分钟 TTL, 一次性消费。用来覆盖"创建后极快完成、详情页首屏
//                拿到的就是 Completed、没有状态跃变可观测"这条边界。
//
//  两张表都落 NSUserDefaults —— 这条提示是发起方客户端的本地副作用, 服务端不参与,
//  所以去重只能靠本机账本。换设备 / 重装后既不重发也不补发, 方向是"宁可漏发不重发"
//  (与 web localStorage / 安卓 SharedPreferences 的已知局限一致)。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryNotifyStore : NSObject

#pragma mark - SENT (taskId -> [channelId])

/// 该 task 是否已经往这个群发过提示。
/// 兼容读取历史扁平表 (旧实现按 taskId 整体去重, 没有 channel 维度): 命中旧表即视为
/// 全部群都发过, 避免升级后给同一条总结重复发。
+ (BOOL)hasSentTaskId:(int64_t)taskId channelId:(NSString *)channelId;

/// 落账 (发送前 claim)。
+ (void)markSentTaskId:(int64_t)taskId channelId:(NSString *)channelId;

/// 回滚落账 (发送失败时)。不会去动历史扁平表。
+ (void)unmarkSentTaskId:(int64_t)taskId channelId:(NSString *)channelId;

#pragma mark - ELIGIBLE (本机发起标记, 10min TTL, 一次性)

/// 创建 / 重新生成成功后调用。只有本机发起过的 task 才拿得到这个标记。
+ (void)markEligibleTaskId:(int64_t)taskId;

/// 只看不消费 —— 用于在发网络请求之前先挡掉没资格的 task。
+ (BOOL)isEligibleTaskId:(int64_t)taskId;

/// 表里是否还有任何未过期的标记。task_no 深链拿不到数字 id、没法精确预判, 用这个
/// 兜一道: 一个标记都没有就不可能发得出提示, 直接免掉那次拉详情的请求。
+ (BOOL)hasAnyEligibleTask;

/// 消费标记: 存在且未过期返回 YES 并同时移除; 否则返回 NO。
+ (BOOL)consumeEligibleTaskId:(int64_t)taskId;

@end

NS_ASSUME_NONNULL_END
