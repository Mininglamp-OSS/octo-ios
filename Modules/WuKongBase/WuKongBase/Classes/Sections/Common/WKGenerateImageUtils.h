//
//  WKGenerateImageUtils.h
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGenerateImageUtils : NSObject

+ (UIImage * _Nullable)generateTintedImgWithImage:(UIImage * _Nullable)image color:(UIColor * _Nonnull)color backgroundColor:(UIColor * _Nullable)backgroundColor;

@end

NS_ASSUME_NONNULL_END
