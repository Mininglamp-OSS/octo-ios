//
//  OctoSummaryGroupNotifyHelper.h
//  OctoContext
//
//  群总结完成后, 往来源群发一条 WK_TIP(2000) 系统提示 ("某人总结了群聊内容")。
//  这条消息不是后端推的, 是**发起方客户端**的本地副作用。
//
//  与安卓 SummaryNotifyCoordinator 对齐, 只有两个触发点:
//    1) 原生总结详情页自身的轮询 —— 观测到 Pending/WaitingConfirm/Processing →
//       Completed 的状态跃变时发 (OctoSummaryDetailVC.loadDetail);
//    2) 通知助手卡片 / 消息里的"查看详情"链接 —— 打开 WebView 之前先识别 URL,
//       异步拉一次详情做判定 (handleSummaryDeepLink:)。WebView 里的 web 端没有
//       独立的 WKSDK 连接、也没有本机 eligible 标记, 自己发不出来, 所以必须由
//       native 侧在这里补一刀。
//
//  列表页**不参与发送** (它的轮询只刷 UI), 详情页关闭后也不做后台续跟。这样"用户
//  自己还没看过总结, 群里就先冒出提示"以及"冷启动进列表把历史自建任务批量追溯广播"
//  两个问题一起消掉。
//
//  判定闸门 (全部满足才发):
//    status == Completed
//    && creator_id == 本机登录 uid
//    && (观测到状态跃变 || 消费掉本机 eligible 标记)
//    && 该 (taskId, channelId) 没发过
//    && 目标群解析非空 && 显示名非空
//  方向是"宁可漏发不重发"。
//

#import <Foundation/Foundation.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OctoSummaryLookupKind) {
    OctoSummaryLookupKindById = 1,   // URL 里带的是数字 task_id
    OctoSummaryLookupKindByNo = 2,   // URL 里带的是字符串 task_no (形如 STxxx)
};

/// 从 URL 里解析出来的总结定位信息, 对应安卓 SummaryLookup sealed class。
@interface OctoSummaryLookup : NSObject
@property(nonatomic, assign) OctoSummaryLookupKind kind;
@property(nonatomic, assign) int64_t taskId;                    // kind == ById 时有效
@property(nonatomic, copy, nullable) NSString *taskNo;          // kind == ByNo 时有效
@end

@interface OctoSummaryGroupNotifyHelper : NSObject

#pragma mark - 本机发起标记

/// 创建 / 重新生成成功后调用。只有本机发起过的 task 才可能触发提示 (creator_id
/// 校验是第二道保险)。10 分钟 TTL + 一次性消费, 见 OctoSummaryNotifyStore。
+ (void)markEligibleTaskId:(int64_t)taskId;

/// 消费本机发起标记。详情页首屏拿到的就是 Completed (没有跃变可观测) 时用它开闸。
+ (BOOL)consumeEligibleTaskId:(int64_t)taskId;

#pragma mark - 核心判定

/// 详情已经拿到、且调用方已经确认"可以发"(观测到跃变 或 消费了 eligible 标记) 时调用。
/// 内部仍会做 status == Completed / creator / 去重 的完整校验, 重复调用安全。
+ (void)notifyIfNeededWithDetail:(nullable OctoSummaryDetail *)detail;

#pragma mark - 深链入口 (通知助手)

/// 从 URL 里解析总结定位信息; 不是总结深链返回 nil。
/// 识别: path `/s/<seg>` (单段, 可带尾斜杠; `/s/share/xxx` 不算);
///      query `task_id` / `taskId` / `task_no` / `taskNo`。
+ (nullable OctoSummaryLookup *)lookupFromURLString:(nullable NSString *)urlString;

/// WuKongBase 侧 (卡片按钮 / 文本链接) 的统一入口: 解析 + 分派, 不是总结深链就什么都不做。
/// 跨 module 通过 WKPOINT_SUMMARY_DEEPLINK endpoint 调用, 不产生编译期依赖。
+ (void)handleSummaryDeepLink:(nullable NSString *)urlString;

/// 按数字 task_id 拉详情做一次判定 (要求本机 eligible 标记存在)。
+ (void)notifyByTaskIdIfEligible:(int64_t)taskId;

/// 按字符串 task_no 拉详情做一次判定 (要求本机 eligible 标记存在)。
+ (void)notifyByTaskNoIfEligible:(nullable NSString *)taskNo;

@end

NS_ASSUME_NONNULL_END
