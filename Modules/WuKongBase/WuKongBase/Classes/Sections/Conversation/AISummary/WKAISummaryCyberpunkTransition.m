//
//  WKAISummaryCyberpunkTransition.m
//  WuKongBase
//
//  「Portal Open」切场 —— 表达"AI 智能开启新视野"。
//
//  视觉骨架：
//    - 当前页截图先轻微放大充能（0-30%）
//    - 然后被前向 zoom 吞没，alpha 渐隐到 0（30-65%）
//    - 同时屏幕中心绽放青色径向光晕 + 16 颗星轨向四面爆射
//    - 光晕扩张到屏幕外 + overlay 透明度 0 → 露出 Bot DM（65-100%）
//
//  pushBlock 在 T=300ms 静默触发；nav 转场被 overlay 完全盖住，用户只见星门。
//

#import "WKAISummaryCyberpunkTransition.h"

static const NSTimeInterval kTotalDuration = 0.65;
static const NSTimeInterval kPushAt        = 0.10;  // T=100ms 提前 push（animated:NO，落到底部等被 reveal）
static const NSInteger kStarCount          = 16;

@implementation WKAISummaryCyberpunkTransition

+ (void)performFromView:(UIView *)sourceView pushBlock:(void (^)(void))pushBlock {
    UIWindow *win = sourceView.window;
    if (!win || UIAccessibilityIsReduceMotionEnabled()) {
        if (pushBlock) pushBlock();
        return;
    }

    UIView *snap = [win snapshotViewAfterScreenUpdates:NO];
    if (!snap) {
        if (pushBlock) pushBlock();
        return;
    }

    // 1. Overlay container —— 透明底，让下层 push 完成后的 Bot DM 直接随 snapshot 淡出而显现
    UIView *overlay = [[UIView alloc] initWithFrame:win.bounds];
    overlay.userInteractionEnabled = NO;
    overlay.clipsToBounds = YES;
    overlay.backgroundColor = UIColor.clearColor;
    [win addSubview:overlay];

    snap.frame = win.bounds;
    [overlay addSubview:snap];

    // 2. 中心放射光（径向青→透明）—— Phase B 时绽放
    UIImageView *centerGlow = [[UIImageView alloc] initWithImage:[self centerGlowImageForSize:win.bounds.size]];
    centerGlow.frame = win.bounds;
    centerGlow.alpha = 0;
    centerGlow.layer.compositingFilter = @"plusL";
    [overlay addSubview:centerGlow];

    // 3. 中心亮核（"星门核"，一颗白光）
    UIView *spark = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 14)];
    spark.center = CGPointMake(win.bounds.size.width  / 2.0,
                               win.bounds.size.height / 2.0);
    spark.backgroundColor = UIColor.whiteColor;
    spark.layer.cornerRadius = 7;
    spark.layer.shadowColor = UIColor.whiteColor.CGColor;
    spark.layer.shadowRadius = 24;
    spark.layer.shadowOpacity = 1.0;
    spark.layer.shadowOffset = CGSizeZero;
    spark.alpha = 0;
    spark.transform = CGAffineTransformMakeScale(0.4, 0.4);
    [overlay addSubview:spark];

    // 4. 星轨：16 颗小白点从中心向四面爆射
    NSMutableArray<UIView *> *stars = [NSMutableArray array];
    for (NSInteger i = 0; i < kStarCount; i++) {
        UIView *star = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, 3)];
        star.center = spark.center;
        star.backgroundColor = UIColor.whiteColor;
        star.layer.cornerRadius = 1.5;
        star.layer.shadowColor = UIColor.whiteColor.CGColor;
        star.layer.shadowRadius = 4;
        star.layer.shadowOpacity = 0.9;
        star.layer.shadowOffset = CGSizeZero;
        star.alpha = 0;
        [overlay addSubview:star];
        [stars addObject:star];
    }

    // 5. T=300ms 静默 push（nav 转场被 overlay 挡死，用户看不到）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPushAt * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (pushBlock) pushBlock();
    });

    // 6. 主关键帧动画
    [UIView animateKeyframesWithDuration:kTotalDuration
                                   delay:0
                                 options:UIViewKeyframeAnimationOptionCalculationModeCubic
                              animations:^{
        // Phase A (0-30%)：充能 —— 当前页轻微放大 + 中央亮核渐显
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.30 animations:^{
            snap.transform = CGAffineTransformMakeScale(1.04, 1.04);
            centerGlow.alpha = 0.30;
            spark.alpha = 1.0;
            spark.transform = CGAffineTransformMakeScale(1.0, 1.0);
        }];
        // Phase B (30-65%)：星门绽放 —— 当前页前向冲淡 + 光晕扩张吞没
        [UIView addKeyframeWithRelativeStartTime:0.30 relativeDuration:0.35 animations:^{
            snap.transform = CGAffineTransformMakeScale(1.6, 1.6);
            snap.alpha = 0;
            centerGlow.alpha = 1.0;
            centerGlow.transform = CGAffineTransformMakeScale(1.5, 1.5);
            spark.transform = CGAffineTransformMakeScale(4.0, 4.0);
            spark.alpha = 0;
        }];
        // Phase C (65-100%)：光晕继续放大穿越镜头 + 整体淡出露 Bot DM
        [UIView addKeyframeWithRelativeStartTime:0.65 relativeDuration:0.35 animations:^{
            centerGlow.transform = CGAffineTransformMakeScale(3.0, 3.0);
            centerGlow.alpha = 0.0;
            overlay.alpha = 0.0;
        }];
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];

    // 7. 星轨：每颗在 Phase B 内随机延迟启动，向四面爆射
    [self animateStars:stars from:spark.center inSize:win.bounds.size];
}

#pragma mark - Stars

+ (void)animateStars:(NSArray<UIView *> *)stars from:(CGPoint)origin inSize:(CGSize)size {
    CGFloat radius = MAX(size.width, size.height) * 0.65;
    NSInteger n = stars.count;
    for (NSInteger i = 0; i < n; i++) {
        UIView *star = stars[i];
        CGFloat baseAngle = (i / (CGFloat)n) * 2 * (CGFloat)M_PI;
        CGFloat jitter    = (arc4random_uniform(40) - 20) * 0.01;
        CGFloat angle     = baseAngle + jitter;
        CGFloat dist      = radius * (0.7 + arc4random_uniform(30) / 100.0);
        CGPoint endPt     = CGPointMake(origin.x + dist * cos(angle),
                                        origin.y + dist * sin(angle));
        NSTimeInterval delay = 0.18 + arc4random_uniform(120) / 1000.0; // 180-300ms 随机
        NSTimeInterval life  = 0.28 + arc4random_uniform(120) / 1000.0; // 280-400ms

        [UIView animateKeyframesWithDuration:life
                                       delay:delay
                                     options:UIViewKeyframeAnimationOptionCalculationModeCubic
                                  animations:^{
            [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.20 animations:^{
                star.alpha = 1.0;
            }];
            [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:1.0 animations:^{
                star.center = endPt;
            }];
            [UIView addKeyframeWithRelativeStartTime:0.65 relativeDuration:0.35 animations:^{
                star.alpha = 0.0;
            }];
        } completion:nil];
    }
}

#pragma mark - 中心放射光（一次性渲染）

+ (UIImage *)centerGlowImageForSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    // 白核 → 青 → 透明
    CGFloat colors[] = {
        1.00, 1.00, 1.00, 1.00,   // 中心白
        0.18, 0.92, 1.00, 0.55,   // 中段青
        0.08, 0.10, 0.30, 0.00,   // 边缘透明
    };
    CGFloat locations[] = { 0.0, 0.35, 1.0 };
    CGGradientRef grad = CGGradientCreateWithColorComponents(space, colors, locations, 3);
    CGFloat r = MIN(size.width, size.height) * 0.55;
    CGPoint c = CGPointMake(size.width / 2.0, size.height / 2.0);
    CGContextDrawRadialGradient(ctx, grad, c, 0, c, r, 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(space);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
