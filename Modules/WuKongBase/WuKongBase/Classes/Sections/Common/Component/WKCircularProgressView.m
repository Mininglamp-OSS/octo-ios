//
//  WKCircularProgressView.m
//  WuKongBase
//
//  Created by tt on 2021/4/10.
//

#import "WKCircularProgressView.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat PWProgressShapeInsetRatio          = 0.03f;


@interface WKCircularProgressView ()

@property (nonatomic, strong) CAShapeLayer *progressShape;

@property(nonatomic,strong) CAShapeLayer *tickShape;

@property(nonatomic,strong) UIColor *circularFillColorInner;
@property(nonatomic,strong) UIColor *circularBorderColorInner;
@end

@implementation WKCircularProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.progressShape = [CAShapeLayer layer];

        self.progressShape.fillColor    = [UIColor clearColor].CGColor;
       
        [self.layer addSublayer:self.progressShape];
        
        self.tickShape =  [CAShapeLayer layer];
        [self.layer addSublayer:self.tickShape];
        
    }
    
    return self;
}

- (UIColor *)circularFillColor {
    if(!_circularFillColorInner) {
        _circularFillColorInner  = [UIColor blueColor];
    }
    return _circularFillColorInner;
}

- (UIColor *)circularBorderColor {
    if(!_circularBorderColorInner) {
        _circularBorderColorInner = [self circularFillColor];
    }
    return _circularBorderColorInner;
}

- (void)setCircularBorderColor:(UIColor *)circularBorderColor {
    _circularBorderColorInner= circularBorderColor;
    [self setNeedsLayout];
}
- (void)setCircularFillColor:(UIColor *)circularFillColor {
    _circularFillColorInner = circularFillColor;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self drawProgress];
    [self drawTick];
}

-(void) drawProgress {
    CGFloat minSide = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = minSide/2.0f;
    self.layer.borderWidth = 2.0f;
    self.layer.borderColor = [self circularBorderColor].CGColor;
    
   
    
    CGFloat centerHoleInset     = 0.0f;
    CGFloat progressShapeInset  = PWProgressShapeInsetRatio * minSide;
    CGFloat diameter = minSide - (2.0f * centerHoleInset) - (2 * progressShapeInset);
    CGFloat radius = (diameter / 2.0f)-2.0f;
    self.progressShape.strokeColor  = [self circularFillColor].CGColor;
    self.progressShape.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake((CGRectGetWidth(self.bounds) / 2.0f) - (radius / 2.0f),
                                                                                 (CGRectGetHeight(self.bounds) / 2.0f) - (radius / 2.0f),
                                                                                 radius,
                                                                                 radius)
                                                         cornerRadius:radius].CGPath;
    self.progressShape.lineWidth = radius;
}


-(void) drawTick {
    //画出一个圆（起始为0，画360°，半径为40）
    UIBezierPath* path = [UIBezierPath bezierPath];
    path.lineWidth = 1.0;
    path.lineCapStyle = kCGLineCapRound; //线条拐角
    path.lineJoinStyle = kCGLineJoinRound; //终点处理
    CGPoint controlPoint = CGPointMake(self.frame.size.width/2.0f, self.frame.size.height/2.0f + 2.0f);
    [path moveToPoint:CGPointMake(controlPoint.x - 3.0f, controlPoint.y - 3.0f)];//起点
    [path addLineToPoint:controlPoint];
    [path addLineToPoint:CGPointMake(controlPoint.x + 3.0f, controlPoint.y - 5.0f)];
   
       
        //图层中线条的颜色
    self.tickShape.strokeColor = [[self circularFillColor] CGColor];
    self.tickShape.path = path.CGPath;
    //图层未画图部分填充色，默认是黑色
    self.tickShape.fillColor = [UIColor clearColor].CGColor;
    //图层中线条宽度
    self.tickShape.lineWidth = 1.5f;
    
        
}


- (void)setProgress:(float)progress
{
    if ([self pinnedProgress:progress] != _progress) {
        self.progressShape.strokeEnd = progress;

        _progress = [self pinnedProgress:progress];
        if (_progress == 1.0f) {
            self.progressShape.hidden = YES;
            self.tickShape.hidden = NO;
            
//            //添加动画，图层上的线条呈现画的效果
//            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:NSStringFromSelector(@selector(strokeStart))];
//            animation.fromValue = @0;
//            animation.toValue = @1;
//            animation.duration = 0.5;
//            [self.tickShape addAnimation:animation forKey:NSStringFromSelector(@selector(strokeStart))];
        }else{
            self.progressShape.hidden = NO;
            self.tickShape.hidden = YES;
//            [self.tickShape removeAllAnimations];
        }
    }
}

- (float)pinnedProgress:(float)progress
{
    float pinnedProgress = MAX(0.0f, progress);
    pinnedProgress = MIN(1.0f, pinnedProgress);
    
    return pinnedProgress;
}

@end
