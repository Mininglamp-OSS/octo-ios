//
//  WKZXingWrapper.h
//  WuKongBase
//
//  Created by tt on 2022/4/8.
//

#import <Foundation/Foundation.h>
#import <LBXScan/ZXingWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKZXingWrapper : NSObject

/*!
 *  识别各种码图片
 *
 *  @param image 图像
 *  @param block 返回识别结果
 */
+ (void)recognizeImage:(UIImage*)image block:(void(^)(ZXBarcodeFormat barcodeFormat,NSString *str))block;


@end

NS_ASSUME_NONNULL_END
