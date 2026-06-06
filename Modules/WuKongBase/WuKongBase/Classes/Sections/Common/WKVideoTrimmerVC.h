//
//  WKVideoTrimmerVC.h
//  WuKongBase
//
//  视频起点选择页：上方 AVPlayer 预览 + 下方缩略图带 + 固定宽度可拖动窗口。
//  仅在 asset.duration > windowDuration 时使用。
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKVideoTrimmerVC : WKBaseVC

- (instancetype)initWithVideoURL:(NSURL *)url
                  windowDuration:(NSTimeInterval)windowDuration
                       onConfirm:(void (^)(CMTime startTime))onConfirm
                        onCancel:(void (^)(void))onCancel;

@end

NS_ASSUME_NONNULL_END
