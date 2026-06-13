//
//  OctoSummaryActionSheet.h
//  OctoContext
//
//  详情页右上 ⋯ 弹出的菜单。Matters 转发暂不实现,菜单项不含。
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OctoSummaryActionType) {
    OctoSummaryActionEdit,             // 编辑结果(completed)
    OctoSummaryActionEditTopic,        // 编辑主题(cancelled/failed) → 弹文本框 + regenerate
    OctoSummaryActionRegenerate,
    OctoSummaryActionRetry,            // 失败重试 = regenerate, 仅文案不同
    OctoSummaryActionCancel,
    OctoSummaryActionDelete,
    OctoSummaryActionForwardToChat,
    OctoSummaryActionSubmitMine,       // BY_PERSON 模式: 提交我的
};

@interface OctoSummaryActionSheet : NSObject

+ (void)presentInVC:(UIViewController *)vc
             detail:(OctoSummaryDetail *)detail
           onAction:(void (^)(OctoSummaryActionType action))onAction;

@end

NS_ASSUME_NONNULL_END
