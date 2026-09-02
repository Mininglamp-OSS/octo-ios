//
//  OctoSummaryGroupNotifyHelper.h
//  OctoContext
//
//  对齐 octo-web packages/dmworksummary/src/utils/groupSummaryNotify.ts:
//  只有"总结创建者"自己的客户端, 在观察到任务变为已完成时, 才会往来源群发一条
//  WK_TIP(2000) 系统提示消息, 告知群内"某人总结了群聊内容"。跟 web 一样, 这不是
//  后端推送的消息, 是发起者客户端的本地副作用; 客户端没有停留在总结列表/详情页时
//  不保证一定会发出 (与 web 的已知行为局限保持一致)。
//

#import <Foundation/Foundation.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryGroupNotifyHelper : NSObject

/// 检查 detail 是否满足"该由当前客户端发送完成提示"的条件 (创建者本人 + 已完成 +
/// 尚未发送过), 满足则往来源群逐个发送 WK_TIP 提示消息并落地去重标记。
/// 可以在总结列表轮询回调、详情页轮询回调里对同一个 detail 反复调用, 内部去重保证
/// 只会真正发送一次。
+ (void)notifyIfNeeded:(OctoSummaryDetail *)detail;

@end

NS_ASSUME_NONNULL_END
