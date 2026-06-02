//
//  WKDisplayLinkCalibration.m
//  WuKongBase
//

#import "WKDisplayLinkCalibration.h"
#import <QuartzCore/QuartzCore.h>

@implementation WKDisplayLinkCalibration

+ (double)playbackRateCompensation {
    static double sRate = 1.0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 探针：拿一个真的 CADisplayLink，读它的 frameInterval 初值。
        // 不需要让它跑（不加进 runloop），创建即可读 property。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CADisplayLink *probe =
            [CADisplayLink displayLinkWithTarget:[self class]
                                        selector:@selector(wkProbeTick:)];
        NSInteger fi = probe.frameInterval;
        [probe invalidate];
#pragma clang diagnostic pop

        sRate = (fi > 1) ? (1.0 / (double)fi) : 1.0;
    });
    return sRate;
}

+ (void)wkProbeTick:(CADisplayLink *)link {
    // 探针不会被加进 runloop，所以这个 selector 实际不会被调用，仅用于 CADisplayLink 构造。
}

@end
