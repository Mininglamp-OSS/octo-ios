//
//  WKVideoToGIFConverter.m
//  WuKongBase
//

#import "WKVideoToGIFConverter.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

NSErrorDomain const WKVideoToGIFErrorDomain = @"WKVideoToGIFErrorDomain";

#pragma mark - 档位定义

typedef struct {
    CGFloat dim;   // 输出边长（正方形）
    NSInteger fps; // 目标帧率（解码采样目标）
} WKGIFTier;

static const WKGIFTier kTiers[] = {
    { 256, 10 },
    { 224, 10 },
    { 192, 10 },
    { 192,  8 },
    { 160,  8 },
    { 128,  6 },
    {  96,  5 },
};
static const NSUInteger kTierCount = sizeof(kTiers) / sizeof(WKGIFTier);

#pragma mark - 取消句柄

@interface WKVideoToGIFTask ()
@property(nonatomic, assign) BOOL cancelled;
@end

@implementation WKVideoToGIFTask
- (void)cancel { self.cancelled = YES; }
@end

#pragma mark - 转换器

@implementation WKVideoToGIFConverter

+ (WKVideoToGIFTask *)convertVideoAtURL:(NSURL *)url
                               fromTime:(CMTime)startTime
                               duration:(CMTime)duration
                               maxBytes:(NSUInteger)maxBytes
                             completion:(void (^)(NSData *, NSError *))completion {
    WKVideoToGIFTask *task = [[WKVideoToGIFTask alloc] init];

    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.octo.wk.video2gif", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_async(queue, ^{
        void (^finish)(NSData *, NSError *) = ^(NSData *data, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(data, err);
            });
        };

        if (task.cancelled) {
            finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                            code:WKVideoToGIFErrorCancelled
                                        userInfo:nil]);
            return;
        }

        NSTimeInterval totalDuration = CMTimeGetSeconds(duration);
        if (totalDuration <= 0) {
            finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                            code:WKVideoToGIFErrorEncode
                                        userInfo:@{NSLocalizedDescriptionKey: @"无效的视频时长"}]);
            return;
        }

        // 1. 按最高档位 FPS 把源帧解出来，记录每帧相对 startTime 的 PTS
        NSMutableArray<UIImage *> *srcFrames = [NSMutableArray array];
        NSMutableArray<NSNumber *> *srcPTSs  = [NSMutableArray array]; // seconds, relative
        [self decodeFramesFromURL:url
                        startTime:startTime
                         duration:duration
                        targetFPS:kTiers[0].fps
                             task:task
                         outFrames:srcFrames
                           outPTSs:srcPTSs];

        if (task.cancelled) {
            finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                            code:WKVideoToGIFErrorCancelled
                                        userInfo:nil]);
            return;
        }
        if (srcFrames.count == 0) {
            finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                            code:WKVideoToGIFErrorEncode
                                        userInfo:@{NSLocalizedDescriptionKey: @"无法读取视频帧"}]);
            return;
        }

        // 2. 把 PTS 序列换成 per-frame delay（最后一帧补到 totalDuration）
        NSArray<NSNumber *> *srcDelays = [self delaysFromPTSs:srcPTSs
                                                totalDuration:totalDuration];

        // 3. 7 档由高到低试，第一个 ≤maxBytes 的就返回
        for (NSUInteger i = 0; i < kTierCount; i++) {
            if (task.cancelled) {
                finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                                code:WKVideoToGIFErrorCancelled
                                            userInfo:nil]);
                return;
            }
            @autoreleasepool {
                WKGIFTier tier = kTiers[i];

                NSMutableArray<UIImage *> *frames = [NSMutableArray array];
                NSMutableArray<NSNumber *> *delays = [NSMutableArray array];
                [self subsampleFrames:srcFrames
                               delays:srcDelays
                            sourceFPS:kTiers[0].fps
                            targetFPS:tier.fps
                            outFrames:frames
                            outDelays:delays];

                NSData *gif = [self encodeGIFFromFrames:frames
                                                 delays:delays
                                                    dim:tier.dim];

                if (gif.length > 0 && gif.length <= maxBytes) {
                    finish(gif, nil);
                    return;
                }
            }
        }

        finish(nil, [NSError errorWithDomain:WKVideoToGIFErrorDomain
                                        code:WKVideoToGIFErrorTooLarge
                                    userInfo:@{NSLocalizedDescriptionKey: @"视频画面变化过大，无法生成 5 MB 内的动图"}]);
    });

    return task;
}

#pragma mark - 抽帧

+ (void)decodeFramesFromURL:(NSURL *)url
                  startTime:(CMTime)startTime
                   duration:(CMTime)duration
                  targetFPS:(NSInteger)targetFPS
                       task:(WKVideoToGIFTask *)task
                  outFrames:(NSMutableArray<UIImage *> *)outFrames
                    outPTSs:(NSMutableArray<NSNumber *> *)outPTSs {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!track) return;

    NSError *err = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
    if (err) return;
    reader.timeRange = CMTimeRangeMake(startTime, duration);

    NSDictionary *outputSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
    };
    AVAssetReaderTrackOutput *output =
        [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                   outputSettings:outputSettings];
    output.alwaysCopiesSampleData = NO;
    if (![reader canAddOutput:output]) return;
    [reader addOutput:output];
    if (![reader startReading]) return;

    CGAffineTransform preferred = track.preferredTransform;

    const CMTime frameInterval = CMTimeMakeWithSeconds(1.0 / (double)targetFPS, 600);
    CMTime nextWanted = startTime;
    NSTimeInterval startSec = CMTimeGetSeconds(startTime);

    while (reader.status == AVAssetReaderStatusReading) {
        if (task.cancelled) {
            [reader cancelReading];
            break;
        }
        CMSampleBufferRef sample = [output copyNextSampleBuffer];
        if (!sample) break;

        CMTime t = CMSampleBufferGetPresentationTimeStamp(sample);
        if (CMTIME_IS_VALID(nextWanted) && CMTimeCompare(t, nextWanted) < 0) {
            CFRelease(sample);
            continue;
        }

        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
        if (pixelBuffer) {
            CIImage *ci = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            ci = [ci imageByApplyingTransform:preferred];
            static CIContext *ctx = nil;
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                ctx = [CIContext contextWithOptions:nil];
            });
            CGImageRef cg = [ctx createCGImage:ci fromRect:ci.extent];
            if (cg) {
                UIImage *img = [UIImage imageWithCGImage:cg];
                [outFrames addObject:img];
                NSTimeInterval relPTS = MAX(0.0, CMTimeGetSeconds(t) - startSec);
                [outPTSs addObject:@(relPTS)];
                CGImageRelease(cg);
            }
        }
        CFRelease(sample);

        nextWanted = CMTimeAdd(nextWanted, frameInterval);
    }

    [reader cancelReading];
}

#pragma mark - Delays

/// 把 PTS 序列转成 per-frame delay：delay[i] = pts[i+1] - pts[i]；
/// 最后一帧 delay = totalDuration - pts[last]（兜底 1/30 防止 0）。
+ (NSArray<NSNumber *> *)delaysFromPTSs:(NSArray<NSNumber *> *)ptss
                          totalDuration:(NSTimeInterval)totalDuration {
    NSMutableArray<NSNumber *> *delays = [NSMutableArray arrayWithCapacity:ptss.count];
    for (NSUInteger i = 0; i < ptss.count; i++) {
        NSTimeInterval cur = ptss[i].doubleValue;
        NSTimeInterval next = (i + 1 < ptss.count) ? ptss[i + 1].doubleValue : totalDuration;
        NSTimeInterval d = MAX(next - cur, 1.0 / 30.0);
        [delays addObject:@(d)];
    }
    return delays;
}

/// 按目标 FPS 子采样，并把跳过帧的 delay 合并到保留帧上，保证总播放时长不变。
+ (void)subsampleFrames:(NSArray<UIImage *> *)srcFrames
                 delays:(NSArray<NSNumber *> *)srcDelays
              sourceFPS:(NSInteger)srcFPS
              targetFPS:(NSInteger)dstFPS
              outFrames:(NSMutableArray<UIImage *> *)outFrames
              outDelays:(NSMutableArray<NSNumber *> *)outDelays {
    if (srcFrames.count == 0) return;
    if (dstFPS >= srcFPS) {
        [outFrames addObjectsFromArray:srcFrames];
        [outDelays addObjectsFromArray:srcDelays];
        return;
    }

    double step = (double)srcFPS / (double)dstFPS; // >1
    NSInteger srcCount = (NSInteger)srcFrames.count;
    double pos = 0;
    NSInteger lastTaken = -1;
    while ((NSInteger)pos < srcCount) {
        NSInteger curIdx = (NSInteger)pos;
        if (curIdx == lastTaken) { pos += step; continue; }
        [outFrames addObject:srcFrames[curIdx]];
        NSTimeInterval merged = 0;
        for (NSInteger k = lastTaken + 1; k <= curIdx; k++) {
            merged += srcDelays[k].doubleValue;
        }
        [outDelays addObject:@(merged)];
        lastTaken = curIdx;
        pos += step;
    }

    // 把循环结束后剩下没合并的尾部 delay 都加到最后一帧，保证总时长守恒
    if (lastTaken >= 0 && lastTaken < srcCount - 1 && outDelays.count > 0) {
        NSTimeInterval extra = 0;
        for (NSInteger k = lastTaken + 1; k < srcCount; k++) {
            extra += srcDelays[k].doubleValue;
        }
        NSTimeInterval merged = outDelays.lastObject.doubleValue + extra;
        outDelays[outDelays.count - 1] = @(merged);
    }
}

#pragma mark - GIF 编码

+ (NSData *)encodeGIFFromFrames:(NSArray<UIImage *> *)frames
                         delays:(NSArray<NSNumber *> *)delays
                            dim:(CGFloat)dim {
    if (frames.count == 0 || frames.count != delays.count) return nil;

    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest =
        CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                         (__bridge CFStringRef)@"com.compuserve.gif",
                                         frames.count,
                                         NULL);
    if (!dest) return nil;

    NSDictionary *gifProps = @{
        (__bridge id)kCGImagePropertyGIFDictionary: @{
            (__bridge id)kCGImagePropertyGIFLoopCount: @0,
        },
    };
    CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)gifProps);

    for (NSUInteger i = 0; i < frames.count; i++) {
        @autoreleasepool {
            UIImage *img = frames[i];
            NSTimeInterval delay = MAX(delays[i].doubleValue, 1.0 / 30.0);
            CGImageRef squared = [self centerCropSquare:img.CGImage toDim:dim];
            if (squared) {
                NSDictionary *frameProps = @{
                    (__bridge id)kCGImagePropertyGIFDictionary: @{
                        (__bridge id)kCGImagePropertyGIFDelayTime: @(delay),
                        (__bridge id)kCGImagePropertyGIFUnclampedDelayTime: @(delay),
                    },
                };
                CGImageDestinationAddImage(dest, squared, (__bridge CFDictionaryRef)frameProps);
                CGImageRelease(squared);
            }
        }
    }

    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return ok ? data : nil;
}

/// 中心裁正方形 → 缩放到 dim × dim。
+ (CGImageRef)centerCropSquare:(CGImageRef)cgImage toDim:(CGFloat)dim CF_RETURNS_RETAINED {
    if (!cgImage) return NULL;
    size_t w = CGImageGetWidth(cgImage);
    size_t h = CGImageGetHeight(cgImage);
    size_t side = MIN(w, h);
    CGRect cropRect = CGRectMake((w - side) * 0.5, (h - side) * 0.5, side, side);
    CGImageRef cropped = CGImageCreateWithImageInRect(cgImage, cropRect);
    if (!cropped) return NULL;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             (size_t)dim,
                                             (size_t)dim,
                                             8,
                                             0,
                                             cs,
                                             kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) {
        CGImageRelease(cropped);
        return NULL;
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, dim, dim), cropped);
    CGImageRef scaled = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGImageRelease(cropped);
    return scaled;
}

@end
