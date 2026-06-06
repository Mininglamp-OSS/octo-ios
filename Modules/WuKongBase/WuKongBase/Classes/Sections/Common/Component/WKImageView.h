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
// 静态图行为完全不变；当 .image 是 SDAnimatedImage 时自动循环播放，
// 让所有头像位 / 聊天气泡 / 列表都能正确显示动图。
@interface WKImageView : SDAnimatedImageView
/**
 加载图片

 @param url 图片地址
 @param placeholderImage 占位图
 */
-(void) loadImage:(NSURL*)url placeholderImage:(UIImage* _Nullable)placeholderImage;
-(void) loadImage:(NSURL*)url;


@end

NS_ASSUME_NONNULL_END
