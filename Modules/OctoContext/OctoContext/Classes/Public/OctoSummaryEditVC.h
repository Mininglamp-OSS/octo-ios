//
//  OctoSummaryEditVC.h
//  OctoContext
//
//  编辑总结结果。改完后 PUT /summaries/:id/edit, 409 → 提示有冲突让用户刷新。
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryEditVC : WKBaseVC

@property(nonatomic, strong) OctoSummaryDetail *detail;
@property(nonatomic, copy, nullable) void (^onSaved)(void);

@end

NS_ASSUME_NONNULL_END
