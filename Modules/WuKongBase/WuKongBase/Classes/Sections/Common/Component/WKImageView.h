//
//  WKImageView.h
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^GetImageComplete)(UIImage *image,NSData *imageData);

@interface WKImageView : UIImageView
/**
 加载图片
 
 @param url 图片地址
 @param placeholderImage 占位图
 */
-(void) loadImage:(NSURL*)url placeholderImage:(UIImage* _Nullable)placeholderImage;
-(void) loadImage:(NSURL*)url;


@end

NS_ASSUME_NONNULL_END
