//
//  OctoContextSparkleIconView.h
//  OctoContext
//
//  紫色圆角方形 + 渐变色 sparkle 图标。复刻 octo-ui/index.html 的应用入口图标。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 设计稿尺寸: 42×42 圆角 12, 内含 24×24 sparkle, 渐变 #F1D6FF → #FFF。
/// 当前实现用 SF Symbol "sparkles" 做形状, CAGradientLayer + mask 实现渐变。
/// 若 PR8 视觉走查认为差异过大, 替换为 Assets 内的 PDF 矢量图即可, 接口不变。
@interface OctoContextSparkleIconView : UIView

@end

NS_ASSUME_NONNULL_END
