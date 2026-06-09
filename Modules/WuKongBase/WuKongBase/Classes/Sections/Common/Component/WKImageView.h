//
//  WKImageView.h
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>
#import <SDWebImage/SDAnimatedImageView.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^GetImageComplete)(UIImage *image,NSData *imageData);

// 继承 SDAnimatedImageView（仍是 UIImageView 子类）。
// 静态图行为完全不变；当 .image 是 SDAnimatedImage 时，**不再自动播放**——
// 改成由 cell 通过 wk_setDisplayed: 显式标记"当前在可见区"才播放。
// 原因：SDAnimatedImageView 默认 autoPlayAnimatedImage=YES 在 setImage 时立刻启动
// CADisplayLink，不管 view 在哪。UITableView 的 cell 滚出 visible 不立刻销毁，
// 累积大量 off-screen 动图 CADisplayLink 持续薅主线程 → HANG。
// 改成 autoPlay=NO + 显式标 displayed 后，只有真的可见的 cell 才动画。
@interface WKImageView : SDAnimatedImageView
/**
 加载图片

 @param url 图片地址
 @param placeholderImage 占位图
 */
-(void) loadImage:(NSURL*)url placeholderImage:(UIImage* _Nullable)placeholderImage;
-(void) loadImage:(NSURL*)url;

/// cell.onWillDisplay 调 wk_setDisplayed:YES，onEndDisplay 调 :NO。
/// 内部维护 wk_displayed 状态：
///   YES 且 image 已是动图 → 立刻 startAnimating
///   NO → stopAnimating
/// 即使 image 还在 SDWebImage 异步加载中，后续 setImage 到达时也会查 wk_displayed
/// 决定是否启动，避免"image 晚于 onWillDisplay 到达 → 永远不动" 的 bug。
- (void)wk_setDisplayed:(BOOL)displayed;

@end

NS_ASSUME_NONNULL_END
