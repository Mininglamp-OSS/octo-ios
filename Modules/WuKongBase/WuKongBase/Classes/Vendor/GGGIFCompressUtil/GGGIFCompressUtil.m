//
//  YJGIFCompressUtil.m
//
//
//  Created by PoloChen on 2019/3/25.
//  Copyright © 2019 Polo. All rights reserved.
//

#import "GGGIFCompressUtil.h"
#import <CoreServices/CoreServices.h>
#import <ImageIO/ImageIO.h>

@interface GGGIFCompressUtil () {
    CGSize _targetSize;
    CGSize _actualSize;
    NSUInteger _targetByte;
}

@property (strong, nonatomic) NSData *currentImageData;

@end

@implementation GGGIFCompressUtil

- (instancetype)initWithImageData:(NSData *)imageData targetSize:(CGSize)targetSize targetByte:(NSUInteger)targetByte {
    if (self = [super init]) {
        _currentImageData = imageData;
        _targetSize = targetSize;
        _targetByte = targetByte;
        _actualSize = CGSizeMake(0, 0);
    }
    return self;
}

- (void)compressAsynchronouslyWithCompletionHandler:(void (^)(NSData * _Nullable compressedData, CGSize gifImageSize, NSError * _Nullable error))handler {
    dispatch_queue_t gifCompressQueue = dispatch_queue_create("gifCompressQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(gifCompressQueue, ^{
        NSLog(@"🌁 ======>>>>> 🌁 开始压缩GIF图片：由%lu -> %lu",(unsigned long)self.currentImageData.length,(unsigned long)self->_targetByte);
        NSData *resultData;
        NSData *compressedDataFromExtractFrame = [self extractFrameFromGIFData:self.currentImageData];
        resultData = compressedDataFromExtractFrame;
        
        CGFloat maxSideLength = MAX(self->_targetSize.width, self->_targetSize.height);
        CGFloat actualWidth = self->_targetSize.width;
        CGFloat actualHeight = self->_targetSize.height;
        self->_actualSize = CGSizeMake(actualWidth, actualHeight);
        
        while (resultData.length > self->_targetByte) {
            CGFloat ratio = self->_targetByte / (CGFloat)resultData.length;
            NSLog(@"🌁 ======>>>>> GIF图片未到指定大小，按照比例：%f 压缩分辨率",ratio);
            maxSideLength *= ratio;
            self->_actualSize = CGSizeMake(actualWidth *= ratio, actualHeight *= ratio);
            NSLog(@"🌁 ======>>>>> GIF图片未到指定大小 按照像素 %.0f x %.0f 压缩",self->_actualSize.width,self->_actualSize.height);
            NSData *compressDataFromCompressResolution = [self compressResolutionWithSourceData:resultData maxSideLength:maxSideLength];
            resultData = compressDataFromCompressResolution;
        }
        if (!resultData) {
            NSError *unCompressError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"⚠️⚠️⚠️ 这个gif压缩失败啦 !!!"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(nil, self->_actualSize,unCompressError);
            });
            return;
        }
        if (resultData.length > self.currentImageData.length) {
            NSError *unCompressError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"⚠️⚠️⚠️ 这个gif压缩越来越大了 它有毒 !!!"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(nil, self->_actualSize,unCompressError);
            });
            return;
        }
        if (resultData.length > self->_targetByte) {
            NSError *unCompressError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"⚠️⚠️⚠️ 这个gif没压缩到指定大小 !!!"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(nil, self->_actualSize,unCompressError);
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(resultData, self->_actualSize,nil);
        });
    });
}

/**
 对gif进行抽帧
 @param sourceData gif图原始二进制数据
 @return 抽帧后的数据
 */
- (NSData *)extractFrameFromGIFData:(NSData *)sourceData {
    if (!sourceData) {
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)sourceData, NULL);
    //获取帧数
    size_t count = CGImageSourceGetCount(source);
    NSLog(@"🌁 ======>>>>> GIF图片的帧数为:%zu",count);
    //抽帧率 ：每sampleCount帧使用1帧
    NSInteger sampleCount = 2;
    if (count <= 30) {
        sampleCount = 1;
    }
//    if (count > 40) {
//        sampleCount = 5;
//    }else if (count > 31 && count <= 40) {
//        sampleCount = 4;
//    }else if (count > 21 && count <= 30) {
//        sampleCount = 3;
//    }else if (count > 9 && count <= 20) {
//        sampleCount = 2;
//    }else  {
//        sampleCount = 1;
//    }
    NSLog(@"🌁 ======>>>>> GIF图片的抽帧率为:%lu",sampleCount);
    //图片写入地址
    NSString *gifFilePath = [NSTemporaryDirectory() stringByAppendingString:@"/compressGIF/compress.gif"];
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:gifFilePath]) {
        [manager removeItemAtPath:gifFilePath error:nil];
    }else {
        NSString *gifFileDirectoryPath = [NSTemporaryDirectory() stringByAppendingString:@"compressGIF"];
        [manager createDirectoryAtPath:gifFileDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *gifFileUrl = [NSURL fileURLWithPath:gifFilePath];
    
    NSDictionary *fileProperties = [self fileProperties];
    
    //计算抽帧后的帧数
    NSInteger coutExtractFrame = count;
    for (int j = 0; j < count; j ++) {
        if (j % sampleCount != 0) {
            --coutExtractFrame;
        }
    }
    NSLog(@"🌁 ======>>>>> 抽帧后的GIF图片的帧数为:%lu",coutExtractFrame);
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifFileUrl, kUTTypeGIF , coutExtractFrame, NULL);
    //    CFDictionaryRef gifProperties = CGImageSourceCopyProperties(source, NULL);
    CGImageDestinationSetProperties(destination, (CFDictionaryRef)fileProperties);
    
    NSTimeInterval duration = 0.0f;
    for (size_t i = 0; i < count; i+=sampleCount) {
        @autoreleasepool {
            NSTimeInterval durationExtractFrame = 0.0f;
            //获取每帧持续时间
            for (NSInteger index = 0; index < sampleCount; index ++) {
                NSInteger frameIndex = index + i;
                if (frameIndex >= count) {
                    break;
                }
                NSTimeInterval delayTime = [self frameDurationAtIndex:frameIndex source:source];
                durationExtractFrame += delayTime;
            }
            //持续时间最大200ms
            durationExtractFrame = MIN(durationExtractFrame, 0.15);
            duration += durationExtractFrame;
            
            // 创建每帧写入地址(测试用 把每帧都写入文件)
//            NSString *preFrameFilePath = [NSTemporaryDirectory() stringByAppendingString:[NSString stringWithFormat:@"/preFrameOfCompressGIF/frame_%ld.jpg",i]];
//            NSFileManager *manager = [NSFileManager defaultManager];
//            if ([manager fileExistsAtPath:preFrameFilePath]) {
//                [manager removeItemAtPath:preFrameFilePath error:nil];
//            }else {
//                NSString *preFrameFileDirectoryPath = [NSTemporaryDirectory() stringByAppendingString:@"preFrameOfCompressGIF"];
//                [manager createDirectoryAtPath:preFrameFileDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
//            }
//            NSURL *preFrameFileUrl = [NSURL fileURLWithPath:preFrameFilePath];
//            CGImageDestinationRef preFrameDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)preFrameFileUrl, kUTTypeJPEG , 1, NULL);
            
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);

            // 设置 gif 每针画面属性
            NSDictionary *frameProperties = [self framePropertiesWithDelayTime:durationExtractFrame];
            
            //把每一帧图片写入GIF
            CGImageDestinationAddImage(destination, imageRef, (CFDictionaryRef)frameProperties);
            //        CGImageDestinationAddImage(destination, scallImage.CGImage, nil);
            //把每一帧图片写入文件夹
//            CGImageDestinationAddImage(preFrameDestination, imageRef, NULL);
//            CGImageDestinationFinalize(preFrameDestination);
            CGImageRelease(imageRef);
//            CFRelease(preFrameDestination);
        }
    }
    // Finalize the GIF
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to finalize GIF destination");
        if (destination != nil) {
            CFRelease(destination);
        }
        CFRelease(source);
        return nil;
    }
    CFRelease(destination);
    CFRelease(source);
    NSData *newData = [NSData dataWithContentsOfFile:gifFilePath];
    NSLog(@"🌁 ======>>>>> 🍍 抽帧压缩gif大小完成：由 %lu -> %lu",(unsigned long)self.currentImageData.length,(unsigned long)newData.length);
    return newData;
}


/**
 压缩GIF的b分辨率
 @param sourceData 源GIF图 data
 @param maxSideLength 最长边长度
 @return 压缩后GIF图 data
 */
- (NSData *)compressResolutionWithSourceData:(NSData *)sourceData maxSideLength:(CGFloat)maxSideLength {
    if (!sourceData || maxSideLength == 0) {
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)sourceData, NULL);
    //获取帧数
    size_t count = CGImageSourceGetCount(source);
    //图片写入地址
    NSString *gifFilePath = [NSTemporaryDirectory() stringByAppendingString:@"/compressResolutionGIF/compressResolution.gif"];
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:gifFilePath]) {
        [manager removeItemAtPath:gifFilePath error:nil];
    }else {
        NSString *gifFileDirectoryPath = [NSTemporaryDirectory() stringByAppendingString:@"compressResolutionGIF"];
        [manager createDirectoryAtPath:gifFileDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSURL *gifFileUrl = [NSURL fileURLWithPath:gifFilePath];
    
    NSDictionary *fileProperties = [self fileProperties];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifFileUrl, kUTTypeGIF , count, NULL);
    CGImageDestinationSetProperties(destination, (CFDictionaryRef)fileProperties);
    
    NSTimeInterval duration = 0.0f;
    for (size_t i = 0; i < count; i++) {
        @autoreleasepool {

            //获取每帧持续时间
            NSTimeInterval delayTime = [self frameDurationAtIndex:i source:source];

            duration += delayTime;
            
            //创建每帧写入地址(测试用 把每帧都写入文件)
//            NSString *preFrameFilePath = [NSTemporaryDirectory() stringByAppendingString:[NSString stringWithFormat:@"/preFrameOfCompressResolutionGIF/frame_%ld.jpg",i]];
//            NSFileManager *manager = [NSFileManager defaultManager];
//            if ([manager fileExistsAtPath:preFrameFilePath]) {
//                [manager removeItemAtPath:preFrameFilePath error:nil];
//            }else {
//                NSString *preFrameFileDirectoryPath = [NSTemporaryDirectory() stringByAppendingString:@"preFrameOfCompressResolutionGIF"];
//                [manager createDirectoryAtPath:preFrameFileDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
//            }
//            NSURL *preFrameFileUrl = [NSURL fileURLWithPath:preFrameFilePath];
//            CGImageDestinationRef preFrameDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)preFrameFileUrl, kUTTypeJPEG , 1, NULL);
            // Create thumbnail options
            
            NSDictionary *options = @{(NSString *)kCGImageSourceShouldCacheImmediately: @(NO),
                                     (NSString *)kCGImageSourceShouldCache: @(NO),
                                     (NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @(YES),
                                     (NSString *)kCGImageSourceThumbnailMaxPixelSize: @(maxSideLength)
                                     };
            
            CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, i, (CFDictionaryRef)options);
            
            // 设置 gif 每针画面属性
            NSDictionary *frameProperties = [self framePropertiesWithDelayTime:delayTime];
            
            //把每一帧图片写入GIF
            CGImageDestinationAddImage(destination, imageRef, (CFDictionaryRef)frameProperties);
            //把每一帧图片写入文件夹
//            CGImageDestinationAddImage(preFrameDestination, imageRef, NULL);
//            CGImageDestinationFinalize(preFrameDestination);
            CGImageRelease(imageRef);
//            CFRelease(preFrameDestination);
        }
    }
    // Finalize the GIF
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to finalize GIF destination");
        if (destination != nil) {
            CFRelease(destination);
        }
        CFRelease(source);
        return nil;
    }
    CFRelease(destination);
    CFRelease(source);
    NSData *newData = [NSData dataWithContentsOfFile:gifFilePath];
    NSLog(@"🌁 ======>>>>> 🍍 分辨率压缩gif大小完成：由 %lu -> %lu",(unsigned long)self.currentImageData.length,(unsigned long)newData.length);
    return newData;
}

- (float)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    float frameDuration = 0.1f;
    //获取这一帧图片的属性字典
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil);
    NSDictionary *frameProperties = (__bridge NSDictionary *)cfFrameProperties;
    //获取gif属性字典
    NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];
    //获取这一帧持续的时间
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (delayTimeUnclampedProp) {
        frameDuration = [delayTimeUnclampedProp floatValue];
    }
    else {
        NSNumber *delayTimeProp = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
        if (delayTimeProp) {
            frameDuration = [delayTimeProp floatValue];
        }
    }
    //如果帧数小于0.1,则指定为0.1
    if (frameDuration < 0.011f) {
        frameDuration = 0.100f;
    }
    CFRelease(cfFrameProperties);
    return frameDuration;
}

- (NSDictionary *)fileProperties{
    return @{(NSString *)kCGImagePropertyGIFDictionary:
                 @{(NSString *)kCGImagePropertyGIFLoopCount: @(0),
//                   (NSString *)kCGImagePropertyGIFHasGlobalColorMap : @(YES),
//                   (NSString *)kCGImagePropertyGIFImageColorMap:(NSString *)kCGImagePropertyColorModelRGB,
//                   (NSString *)kCGImagePropertyDepth : @(6)
                   }
             };
}

- (NSDictionary *)framePropertiesWithDelayTime:(NSTimeInterval)delayTime {
    return @{(NSString *)kCGImagePropertyGIFDictionary:
                 @{(NSString *)kCGImagePropertyGIFDelayTime : @(delayTime)}
             };
}

@end
