#import "WKContactsSVGIcons.h"

@implementation WKContactsSVGIcons

+ (UIImage *)iconNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color {
    return [self iconNamed:name size:size color:color strokeWidth:1.8f];
}

+ (UIImage *)iconNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color strokeWidth:(CGFloat)strokeWidth {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat s = size / 24.0f;
        CGContextRef c = ctx.CGContext;
        CGContextSetLineWidth(c, strokeWidth * s);
        CGContextSetLineCap(c, kCGLineCapRound);
        CGContextSetLineJoin(c, kCGLineJoinRound);
        [color setStroke];

        if ([name isEqualToString:@"person-plus"]) {
            [self drawPersonPlus:c scale:s color:color];
        } else if ([name isEqualToString:@"users"]) {
            [self drawUsers:c scale:s color:color];
        } else if ([name isEqualToString:@"bot"]) {
            [self drawBot:c scale:s color:color];
        } else if ([name isEqualToString:@"search"]) {
            [self drawSearch:c scale:s];
        } else if ([name isEqualToString:@"chevron-right"]) {
            [self drawChevronRight:c scale:s];
        }
    }];
}

// person-plus: <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="8.5" cy="7" r="4"/>
// <line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/>
+ (void)drawPersonPlus:(CGContextRef)c scale:(CGFloat)s color:(UIColor *)color {
    // Body arc: from (16,21) up through a 4-radius curve down to (5,15), then another curve to (1,21)
    UIBezierPath *body = [UIBezierPath bezierPath];
    [body moveToPoint:CGPointMake(16*s, 21*s)];
    [body addLineToPoint:CGPointMake(16*s, 19*s)];
    [body addCurveToPoint:CGPointMake(12*s, 15*s) controlPoint1:CGPointMake(16*s, 16.79*s) controlPoint2:CGPointMake(14.21*s, 15*s)];
    [body addLineToPoint:CGPointMake(5*s, 15*s)];
    [body addCurveToPoint:CGPointMake(1*s, 19*s) controlPoint1:CGPointMake(2.79*s, 15*s) controlPoint2:CGPointMake(1*s, 16.79*s)];
    [body addLineToPoint:CGPointMake(1*s, 21*s)];
    [color setStroke];
    [body stroke];

    // Head circle at (8.5, 7) r=4
    UIBezierPath *head = [UIBezierPath bezierPathWithArcCenter:CGPointMake(8.5*s, 7*s) radius:4*s startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [head stroke];

    // Plus: vertical line (20,8)→(20,14)
    UIBezierPath *plusV = [UIBezierPath bezierPath];
    [plusV moveToPoint:CGPointMake(20*s, 8*s)];
    [plusV addLineToPoint:CGPointMake(20*s, 14*s)];
    [plusV stroke];

    // Plus: horizontal line (23,11)→(17,11)
    UIBezierPath *plusH = [UIBezierPath bezierPath];
    [plusH moveToPoint:CGPointMake(23*s, 11*s)];
    [plusH addLineToPoint:CGPointMake(17*s, 11*s)];
    [plusH stroke];
}

// users: <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/>
// <path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/>
+ (void)drawUsers:(CGContextRef)c scale:(CGFloat)s color:(UIColor *)color {
    // Front body
    UIBezierPath *body = [UIBezierPath bezierPath];
    [body moveToPoint:CGPointMake(17*s, 21*s)];
    [body addLineToPoint:CGPointMake(17*s, 19*s)];
    [body addCurveToPoint:CGPointMake(13*s, 15*s) controlPoint1:CGPointMake(17*s, 16.79*s) controlPoint2:CGPointMake(15.21*s, 15*s)];
    [body addLineToPoint:CGPointMake(5*s, 15*s)];
    [body addCurveToPoint:CGPointMake(1*s, 19*s) controlPoint1:CGPointMake(2.79*s, 15*s) controlPoint2:CGPointMake(1*s, 16.79*s)];
    [body addLineToPoint:CGPointMake(1*s, 21*s)];
    [color setStroke];
    [body stroke];

    // Front head
    UIBezierPath *head = [UIBezierPath bezierPathWithArcCenter:CGPointMake(9*s, 7*s) radius:4*s startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [head stroke];

    // Back body: path from (23,21) up through curve
    UIBezierPath *backBody = [UIBezierPath bezierPath];
    [backBody moveToPoint:CGPointMake(23*s, 21*s)];
    [backBody addLineToPoint:CGPointMake(23*s, 19*s)];
    [backBody addCurveToPoint:CGPointMake(20*s, 15.13*s) controlPoint1:CGPointMake(23*s, 16.98*s) controlPoint2:CGPointMake(21.73*s, 15.36*s)];
    [backBody stroke];

    // Back head arc: approximate "a4 4 0 010 7.75" at (16, 3.13)
    UIBezierPath *backHead = [UIBezierPath bezierPath];
    [backHead addArcWithCenter:CGPointMake(12*s, 7*s) radius:4*s startAngle:-M_PI*0.48 endAngle:M_PI*0.48 clockwise:YES];
    CGAffineTransform t = CGAffineTransformMakeTranslation(4*s, -0.0*s);
    [backHead applyTransform:t];
    [backHead stroke];
}

// bot: <rect x="3" y="7" width="18" height="14" rx="3"/><circle cx="8.5" cy="14" r="1.5" fill/>
// <circle cx="15.5" cy="14" r="1.5" fill/><path d="M12 3v4M9 7h6"/>
+ (void)drawBot:(CGContextRef)c scale:(CGFloat)s color:(UIColor *)color {
    // Body rect
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3*s, 7*s, 18*s, 14*s) cornerRadius:3*s];
    [color setStroke];
    [body stroke];

    // Left eye (filled)
    UIBezierPath *leftEye = [UIBezierPath bezierPathWithArcCenter:CGPointMake(8.5*s, 14*s) radius:1.5*s startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [color setFill];
    [leftEye fill];

    // Right eye (filled)
    UIBezierPath *rightEye = [UIBezierPath bezierPathWithArcCenter:CGPointMake(15.5*s, 14*s) radius:1.5*s startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [rightEye fill];

    // Antenna vertical: (12,3)→(12,7)
    UIBezierPath *antenna = [UIBezierPath bezierPath];
    [antenna moveToPoint:CGPointMake(12*s, 3*s)];
    [antenna addLineToPoint:CGPointMake(12*s, 7*s)];
    [antenna stroke];

    // Antenna horizontal: (9,7)→(15,7)
    UIBezierPath *antennaH = [UIBezierPath bezierPath];
    [antennaH moveToPoint:CGPointMake(9*s, 7*s)];
    [antennaH addLineToPoint:CGPointMake(15*s, 7*s)];
    [antennaH stroke];
}

// search: <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.35-4.35"/>
+ (void)drawSearch:(CGContextRef)c scale:(CGFloat)s {
    UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(11*s, 11*s) radius:7*s startAngle:0 endAngle:M_PI*2 clockwise:YES];
    [circle stroke];

    UIBezierPath *handle = [UIBezierPath bezierPath];
    [handle moveToPoint:CGPointMake(21*s, 21*s)];
    [handle addLineToPoint:CGPointMake(16.65*s, 16.65*s)];
    [handle stroke];
}

// chevron-right: <path d="M9 18l6-6-6-6"/>
+ (void)drawChevronRight:(CGContextRef)c scale:(CGFloat)s {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(9*s, 18*s)];
    [path addLineToPoint:CGPointMake(15*s, 12*s)];
    [path addLineToPoint:CGPointMake(9*s, 6*s)];
    [path stroke];
}

@end
