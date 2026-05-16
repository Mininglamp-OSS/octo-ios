//
//  WKPhotoService.h
//  Pods
//
//  Created by tt on 2020/7/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^getPhotoCompleteBlock)(UIImage*image);

typedef void(^getMulPhotoCompleteBlock)(NSArray<UIImage*>*images);

@interface WKPhotoService : NSObject
+ (WKPhotoService *)shared;

/// 从相机里获取图片
/// @param complete <#complete description#>
-(void) getPhotoFromCamera:(getPhotoCompleteBlock)complete;


/// 从相册里获取图片（一张）
/// @param complete <#complete description#>
-(void) getPhotoOneFromLibrary:(getPhotoCompleteBlock)complete;



/// 图片质量压缩到某一范围内，如果后面用到多，可以抽成分类或者工具类,这里压缩递减比二分的运行时间长，二分可以限制下限
/// @param image 原图
/// @param maxLength 最大字节大小
- (NSData *)compressImageSize:(UIImage *)image toByte:(NSUInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
