//
//  OctoSummaryConfirmVC.h
//  OctoContext
//
//  WAITING_CONFIRM 状态下,被邀请的参与者点 "查看确认状态" 进入此页:
//  显示参与者列表 + 来源选择 + 确认/拒绝。
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryConfirmVC : WKBaseVC

@property(nonatomic, strong) OctoSummaryDetail *detail;

@end

NS_ASSUME_NONNULL_END
