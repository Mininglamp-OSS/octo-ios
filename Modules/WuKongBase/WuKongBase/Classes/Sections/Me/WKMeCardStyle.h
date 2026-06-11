//
//  WKMeCardStyle.h
//  WuKongBase
//
//  Me 模块设置类页面（我的 / 个人资料 / 通用 / 外观 / 新消息通知）
//  统一卡片样式 helper：白底圆角 16、行间 1px #F5F5FA 分隔线 inset 17/17、
//  UISwitch onTintColor #1C1C23（限本模块，避免污染全局）。
//
//  用法：在 tableView:willDisplayCell:forRowAtIndexPath: 末尾调用一次即可。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITableViewCell (WKMeCardStyle)

/// 应用 Me 模块统一卡片样式：根据 row 在 section 中的位置决定上/下圆角，
/// 强制 UISwitch tint 为黑色，调整 cell 的 bottomLineView 颜色为 #F5F5FA。
- (void)wk_applyMeCardStyleAtIndexPath:(NSIndexPath *)indexPath inTableView:(UITableView *)tableView;

@end

NS_ASSUME_NONNULL_END
