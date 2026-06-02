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

/// 选取头像素材的回调。三种互斥结果：
///   - videoURL  != nil → 用户选了视频，需走 trimmer + 视频转 GIF 流程
///   - 否则 imageData != nil：
///       - isAnimated == YES → 直接走预览确认 + 原字节上传
///       - isAnimated == NO  → 走 TOCropViewController 静态裁剪流程
///   - 三个值都为 nil → 用户取消
typedef void(^getAvatarMediaBlock)(NSData * _Nullable imageData,
                                   NSURL * _Nullable videoURL,
                                   BOOL isAnimated);

@interface WKPhotoService : NSObject
+ (WKPhotoService *)shared;

/// 从相机里获取图片
/// @param complete <#complete description#>
-(void) getPhotoFromCamera:(getPhotoCompleteBlock)complete;


/// 从相册里获取图片（一张）
/// @param complete <#complete description#>
-(void) getPhotoOneFromLibrary:(getPhotoCompleteBlock)complete;


/// 从相册里获取一个头像素材（图片或视频），保留原始字节用于动图判定。
/// 仅 iOS 14+ 使用 PHPickerViewController，过滤为图片 + 视频。
-(void) getAvatarMediaFromLibrary:(getAvatarMediaBlock)complete API_AVAILABLE(ios(14));



/// 图片质量压缩到某一范围内，如果后面用到多，可以抽成分类或者工具类,这里压缩递减比二分的运行时间长，二分可以限制下限
/// @param image 原图
/// @param maxLength 最大字节大小
- (NSData *)compressImageSize:(UIImage *)image toByte:(NSUInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
