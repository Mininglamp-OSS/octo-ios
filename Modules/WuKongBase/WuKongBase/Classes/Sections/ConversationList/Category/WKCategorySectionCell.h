//
//  WKCategorySectionCell.h
//  WuKongBase
//
//  分组 section header cell（折叠箭头 + 分组名称）
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCategorySectionCell : UITableViewCell

@property (nonatomic, copy) NSString *sectionId;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) BOOL collapsed;
@property (nonatomic, assign) BOOL isDefault;       // 默认分组：不可长按管理
@property (nonatomic, assign) BOOL showTopDivider;   // 是否显示顶部分隔线

@property (nonatomic, copy, nullable) void(^onToggle)(NSString *sectionId, BOOL collapsed);
@property (nonatomic, copy, nullable) void(^onLongPress)(NSString *sectionId, NSString *title, CGPoint pointInWindow);

@end

NS_ASSUME_NONNULL_END
