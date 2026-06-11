//
//  WKChatAnimatedImage.m
//  WuKongBase
//

#import "WKChatAnimatedImage.h"
#import <SDWebImage/SDWebImage.h>

@implementation WKChatAnimatedImage

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    UIImage *raw = [super animatedImageFrameAtIndex:index];
    if (!raw) {
        return nil;
    }
    CGImageRef cg = raw.CGImage;
    if (!cg) {
        return raw;
    }
    CGImageRef decoded = [SDImageCoderHelper CGImageCreateDecoded:cg];
    if (!decoded) {
        // 降级: 重画失败仍返回原 IIO 帧, 不让 player 拿空
        return raw;
    }
    UIImage *bitmap = [UIImage imageWithCGImage:decoded scale:raw.scale orientation:raw.imageOrientation];
    CGImageRelease(decoded);
    bitmap.sd_isDecoded = YES;
    bitmap.sd_imageFormat = raw.sd_imageFormat;
    return bitmap;
}

@end
