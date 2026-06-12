//
//  OctoSummaryFilterTabsView.h
//  OctoContext
//
//  smart-summary.html 顶部 6 个筛选 tab,active 紫色 indicator。
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OctoSummaryFilterIndex) {
    OctoSummaryFilterAll = 0,            // 全部
    OctoSummaryFilterPending,            // 等待中
    OctoSummaryFilterWaitingConfirm,     // 等待参与者
    OctoSummaryFilterProcessing,         // 生成中
    OctoSummaryFilterCompleted,          // 已完成
    OctoSummaryFilterFailed,             // 失败
    OctoSummaryFilterCount
};

@interface OctoSummaryFilterTabsView : UIView

@property(nonatomic, assign) OctoSummaryFilterIndex selectedIndex;
@property(nonatomic, copy, nullable) void (^onSelect)(OctoSummaryFilterIndex idx);

/// 把 UI 选中态映射为 API 的 status 字段值。OctoSummaryFilterAll → -1 表示不传。
+ (NSInteger)taskStatusForFilter:(OctoSummaryFilterIndex)idx;

@end

NS_ASSUME_NONNULL_END
