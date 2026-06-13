//
//  OctoSummaryDetailVC.h
//  OctoContext
//
//  详情页 (summary-generating / summary-complete / failed / cancelled 四态)。
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryDetailVC : WKBaseVC

@property(nonatomic, copy, nullable) NSNumber *taskId;     // setValue:forKey 用 NSNumber
@property(nonatomic, strong, nullable) OctoSummaryListItem *listItem;

@end

NS_ASSUME_NONNULL_END
