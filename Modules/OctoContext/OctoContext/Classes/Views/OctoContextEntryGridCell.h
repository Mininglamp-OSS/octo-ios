//
//  OctoContextEntryGridCell.h
//  OctoContext
//
//  上下文 tab 主页的 app-grid item: 42×42 紫色圆角图标 + 10pt 文案。
//  对应 octo-ui/index.html 的 .app-item.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OctoContextEntryGridCell : UICollectionViewCell

- (void)bindIcon:(UIView *)iconView title:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
