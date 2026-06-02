//
//  WKVideoToGIFConverter.h
//  WuKongBase
//
//  视频片段 → 循环 GIF 转换器。
//  按 7 档由高到低尝试编码（256×256 @10fps 起步），直到字节数 ≤ maxBytes，
//  全部档位都超就回调 WKVideoToGIFErrorTooLarge。
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const WKVideoToGIFErrorDomain;

typedef NS_ERROR_ENUM(WKVideoToGIFErrorDomain, WKVideoToGIFError) {
    /// 转码本身失败（AVAssetReader 起不来 / 无视频轨 / 取帧异常）。
    WKVideoToGIFErrorEncode = -1,
    /// 7 档全跑完仍 > maxBytes。
    WKVideoToGIFErrorTooLarge = -2,
    /// 调用方主动取消。
    WKVideoToGIFErrorCancelled = -3,
};

/// 取消句柄。调用 cancel 后 completion 仍会触发 (error = WKVideoToGIFErrorCancelled)。
@interface WKVideoToGIFTask : NSObject
- (void)cancel;
@end

@interface WKVideoToGIFConverter : NSObject

/**
 把视频指定区间转成正方形循环 GIF。

 @param url        视频文件 URL
 @param startTime  起始时间
 @param duration   片段时长（头像场景固定 3 秒）
 @param maxBytes   字节上限（5 MB = 5 * 1024 * 1024）
 @param completion 完成回调（main 线程）。成功时 error == nil，失败时 gifData == nil。
 @return 取消句柄。
 */
+ (WKVideoToGIFTask *)convertVideoAtURL:(NSURL *)url
                               fromTime:(CMTime)startTime
                               duration:(CMTime)duration
                               maxBytes:(NSUInteger)maxBytes
                             completion:(void (^)(NSData *_Nullable gifData,
                                                  NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
