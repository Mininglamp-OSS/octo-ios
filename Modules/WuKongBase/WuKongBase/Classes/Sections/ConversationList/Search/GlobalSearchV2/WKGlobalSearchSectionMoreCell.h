//
//  WKGlobalSearchSectionMoreCell.h
//  WuKongBase
//
//  全局搜索「全部」tab 聚合视图里，单个分类分组末尾的「查看全部 N 条」跳转行。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchSectionMoreCell : UITableViewCell

+ (NSString *)reuseIdentifier;
+ (CGFloat)cellHeight;

/// 通用文案入口：「查看全部 N 条」「加载失败，点击重试」等都复用本行样式，只是文案不同。
- (void)applyTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
