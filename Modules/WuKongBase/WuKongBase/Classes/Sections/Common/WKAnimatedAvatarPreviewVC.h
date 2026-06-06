//
//  WKAnimatedAvatarPreviewVC.h
//  WuKongBase
//
//  动图头像预览确认页：圆形 SDAnimatedImageView 预览 + 重选/确认按钮。
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKAnimatedAvatarPreviewVC : WKBaseVC

- (instancetype)initWithGIFData:(NSData *)gifData
                      onConfirm:(void (^)(NSData *gifData))onConfirm
                      onRetake:(void (^)(void))onRetake;

@end

NS_ASSUME_NONNULL_END
