//
//  OctoSummaryMembersView.h
//  OctoContext
//
//  BY_PERSON 模式下详情页的成员状态视图: 列出每个成员的提交状态。
//

#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryMembersView : UIView

- (void)updateMembers:(NSArray<OctoMemberStatus *> *)members;

- (CGFloat)intrinsicHeightForWidth:(CGFloat)width;

@end

NS_ASSUME_NONNULL_END
