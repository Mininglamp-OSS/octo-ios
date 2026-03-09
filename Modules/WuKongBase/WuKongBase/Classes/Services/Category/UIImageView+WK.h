//
//  UIImageView+WK.h
//  WuKongBase
//
//  Created by tt on 2021/10/14.
//

#import <UIKit/UIKit.h>
#import <SDWebImage/SDWebImage.h>
NS_ASSUME_NONNULL_BEGIN

@interface UIImageView (WK)


- (void)lim_setImageWithURL:(NSURL *)url;

-(void) lim_setImageWithURL:(NSURL*)url placeholderImage:(nullable UIImage*)placeholderImage;

- (void)lim_setImageWithURL:(NSURL *)url completed:(nullable SDExternalCompletionBlock)completed;

- (void)lim_setImageWithURL:(NSURL *)url context:(nullable SDWebImageContext*)context;

- (void)lim_setImageWithURL:(NSURL *)url context:(nullable SDWebImageContext*)context completed:(nullable SDExternalCompletionBlock)completed;

- (void)lim_setImageWithURL:(NSURL *)url options:(SDWebImageOptions)options context:(nullable SDWebImageContext*)context completed:(nullable SDExternalCompletionBlock)completed;

- (void)lim_setImageWithURL:(NSURL *)url placeholderImage:(nullable UIImage*)placeholderImage options:(SDWebImageOptions)options context:(nullable SDWebImageContext*)context;

@end

NS_ASSUME_NONNULL_END
