//
//  WKConversationRouter.h
//  WuKongBase
//
//  会话页统一跳转入口。抽自 WKLocalNotificationManager 的 navigateToChannel:
//  channelType:messageSeq:retryCount:,让通知点击、Citation 引用跳原消息、外部分享
//  打开聊天等场景共用一条路径,避免每个调用方都重写一遍"等导航栈就绪 + 已在该 channel
//  时只定位不重 push + 否则 push 新 VC"。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationRouter : NSObject

/// 打开指定 channel 的聊天窗口。
/// - 若导航栈未就绪(冷启动 / 未登录),最多重试 20 次 / 共 10s,期间放弃则静默 no-op。
/// - 若栈顶就是同 channel 的 WKConversationVC,只 locate 不再 push。
/// - 否则 push 一个新 WKConversationVC,并用 messageSeq 设置 locationAtOrderSeq 让首屏滚到位置。
/// @param messageSeq 0 表示不定位,>0 时进入页面后会滚到该消息并播一次"提醒高亮"动画。
+(void) openChannelId:(NSString *)channelId
          channelType:(NSInteger)channelType
           messageSeq:(uint32_t)messageSeq;

@end

NS_ASSUME_NONNULL_END
