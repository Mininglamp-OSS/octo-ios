//
//  WKAnimatedImageCoders.m
//  WuKongBase
//

#import "WKAnimatedImageCoders.h"
#import <SDWebImage/SDImageIOAnimatedCoder.h>

// frameDurationAtIndex:source: 在 SDWebImage 的 Private/SDImageIOAnimatedCoderInternal.h 里，
// 外部包不可见。这里前向声明 (runtime 会动态派发到父类实现)。
@interface SDImageIOAnimatedCoder (WKAnimatedDelayPrivate)
+ (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source;
@end

// 共用矫正：把 SDWebImage 默认 frameDuration 再 clamp 一次。
// 它内部已经把 ≤ 0.011 矫正到 0.1；这里把 阈值上推到 WK_ANIMATED_DELAY_MIN (0.02)。
static inline NSTimeInterval WKClampAnimatedDelay(NSTimeInterval d) {
    return (d <= WK_ANIMATED_DELAY_MIN + 1e-6) ? 0.1 : d;
}

#pragma mark - GIF

@implementation WKImageGIFCoder

+ (instancetype)sharedCoder {
    static WKImageGIFCoder *coder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        coder = [[WKImageGIFCoder alloc] init];
    });
    return coder;
}

// SDImageIOAnimatedCoder 内部用 [self.class frameDurationAtIndex:...] 动态派发到这里，
// 解码 / 动图 / 渐进式 三条路径都会过这道矫正。
+ (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    return WKClampAnimatedDelay([super frameDurationAtIndex:index source:source]);
}

@end

#pragma mark - APNG

@implementation WKImageAPNGCoder

+ (instancetype)sharedCoder {
    static WKImageAPNGCoder *coder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        coder = [[WKImageAPNGCoder alloc] init];
    });
    return coder;
}

+ (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    return WKClampAnimatedDelay([super frameDurationAtIndex:index source:source]);
}

@end
