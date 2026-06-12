//
//  OctoSummaryCardCell.h
//  OctoContext
//
//  smart-summary.html 的 summary-card,三态:
//   - 普通 (completed/failed/cancelled): 标题 + 摘要预览 + 时间
//   - processing: 紫渐变底 + spinner + "AI 正在分析…"
//   - waiting (WAITING_CONFIRM): 头像堆叠 + 等待文案 + 紫色 badge
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryCardCell : UITableViewCell

/// 用户从菜单选了某个动作的回调。所有 status → action 映射表见 .m 的 buildMenuForItem:。
@property(nonatomic, copy, nullable) void (^onAction)(NSInteger actionType, OctoSummaryListItem *item);

/// 当前登录用户的显示名,用于把 "creator_name == 我" 的卡片改成 "你发起"。
/// VC 在 cellForRowAtIndexPath: 里设置;为 nil 或空字符串时仅在 creator_name
/// 缺失/空时退化为 "你发起"。
@property(nonatomic, copy, nullable) NSString *currentUserName;

- (void)bindItem:(OctoSummaryListItem *)item;

+ (CGFloat)heightForItem:(OctoSummaryListItem *)item width:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
