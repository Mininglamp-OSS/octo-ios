//
//  WKAISummaryEntryController.h
//  WuKongBase
//
//  AI 一键总结按钮在 WKConversationVC 上的入口控制器。
//
//  职责：
//    1. 候选 Bot 集合：群成员 ∩ 当前 Space 已添加 Bot ∩ 在线
//    2. 显隐：候选空 → 隐藏；非空 → 显示
//    3. 监听 4 路（成员变更 / Space 切换 / Registry 加载 / 在线状态）
//       并做 200ms 合并防抖
//    4. 短按：默认 prompt（未读优先：未读 > 0 → "总结未读 N 条"；否则"最近 1 天"），推 Bot DM 并自动发送
//    5. 长按：弹时间范围选择（6h / 1d / 3d / 7d；如有未读，置顶"未读 N 条"为默认）
//       多 Bot 时菜单顶部加 Bot picker
//    6. 同时持有 WKAITextIngestor 让群里可见消息片段持续涌入按钮
//

#import <Foundation/Foundation.h>

@class WKMessageListView;
@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

@interface WKAISummaryEntryController : NSObject

+ (void)attachToMessageListView:(WKMessageListView *)mlv channel:(WKChannel *)channel;

+ (void)detachFromMessageListView:(WKMessageListView *)mlv;

@end

NS_ASSUME_NONNULL_END
