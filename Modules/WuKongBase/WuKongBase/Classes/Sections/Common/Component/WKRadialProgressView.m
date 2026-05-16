// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRadialProgressView.m — replaces TelegramUtils RadialStatusNode (GPL v2)
//

#import "WKRadialProgressView.h"

@interface WKRadialProgressView ()
@property (nonatomic, strong) CAShapeLayer *trackLayer;
@property (nonatomic, strong) CAShapeLayer *progressLayer;
@property (nonatomic, strong) UIImageView  *iconView;
@property (nonatomic, strong) NSTimer      *countdownTimer;
@property (nonatomic, copy)   void (^finishedBlock)(void);
@property (nonatomic, assign) CFTimeInterval endTime;
@property (nonatomic, assign) CGFloat        totalTimeout;
@property (nonatomic, assign) BOOL           sparks;
@end

@implementation WKRadialProgressView

- (instancetype)initWithBackgroundNodeColor:(UIColor *)color enableBlur:(BOOL)enableBlur {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = color;
        self.layer.cornerRadius = 0; // caller sets size; cornerRadius handled in layoutSubviews
        self.clipsToBounds = YES;
        [self setupLayers];
    }
    return self;
}

- (void)setupLayers {
    _trackLayer    = [CAShapeLayer layer];
    _trackLayer.fillColor   = [UIColor clearColor].CGColor;
    _trackLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    _trackLayer.lineWidth   = 1.5;
    [self.layer addSublayer:_trackLayer];

    _progressLayer = [CAShapeLayer layer];
    _progressLayer.fillColor   = [UIColor clearColor].CGColor;
    _progressLayer.strokeColor = [UIColor whiteColor].CGColor;
    _progressLayer.lineWidth   = 1.5;
    _progressLayer.lineCap     = kCALineCapRound;
    _progressLayer.strokeStart = 0;
    _progressLayer.strokeEnd   = 1;
    [self.layer addSublayer:_progressLayer];

    _iconView = [[UIImageView alloc] init];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_iconView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat r     = MIN(self.bounds.size.width, self.bounds.size.height) * 0.5;
    self.layer.cornerRadius = r;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    UIBezierPath *circle = [UIBezierPath bezierPathWithArcCenter:center
                                                          radius:r - 2
                                                      startAngle:-M_PI_2
                                                        endAngle:-M_PI_2 + 2 * M_PI
                                                       clockwise:YES];
    _trackLayer.frame    = self.bounds;
    _progressLayer.frame = self.bounds;
    _trackLayer.path    = circle.CGPath;
    _progressLayer.path = circle.CGPath;

    CGFloat iconSz = r * 0.7;
    _iconView.frame = CGRectMake(center.x - iconSz/2, center.y - iconSz/2, iconSz, iconSz);
}

#pragma mark - RadialStatusNode compatibility

- (WKRadialProgressView *)view { return self; }

- (void)transitionToStateWithIcon:(nullable UIImage *)icon
                        beginTime:(CFTimeInterval)beginTime
                          timeout:(CGFloat)timeout
                         animated:(BOOL)animated
                      synchronous:(BOOL)synchronous
                           sparks:(BOOL)sparks
                         finished:(nullable void (^)(void))finished {
    [self stopTimer];
    _finishedBlock = [finished copy];
    _sparks        = sparks;
    _totalTimeout  = timeout;

    _iconView.image = icon;

    // beginTime is wall clock (CFAbsoluteTimeGetCurrent + NSTimeIntervalSince1970)
    CFTimeInterval now       = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970;
    CFTimeInterval elapsed   = now - beginTime;
    CGFloat        remaining = timeout - (CGFloat)elapsed;

    if (remaining <= 0) {
        _progressLayer.strokeEnd = 0;
        [self onFinished];
        return;
    }

    _endTime = now + remaining;

    // Animate strokeEnd from current fraction → 0 over `remaining` seconds
    CGFloat startFraction = remaining / timeout;
    _progressLayer.strokeEnd = startFraction;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    anim.fromValue   = @(startFraction);
    anim.toValue     = @(0.0);
    anim.duration    = remaining;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    anim.fillMode    = kCAFillModeForwards;
    anim.removedOnCompletion = NO;
    [_progressLayer addAnimation:anim forKey:@"countdown"];

    // Completion timer
    __weak typeof(self) weak = self;
    _countdownTimer = [NSTimer scheduledTimerWithTimeInterval:remaining
                                                      target:weak
                                                    selector:@selector(onCountdownComplete)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)animatePaused {
    [self stopTimer];
    [_progressLayer removeAllAnimations];
    // Freeze the current strokeEnd at the paused fraction
    CFTimeInterval now     = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970;
    CGFloat remaining      = (CGFloat)(_endTime - now);
    CGFloat fraction       = MAX(0, MIN(1, remaining / MAX(1, _totalTimeout)));
    _progressLayer.strokeEnd = fraction;
}

#pragma mark - Private

- (void)onCountdownComplete {
    [_progressLayer removeAllAnimations];
    _progressLayer.strokeEnd = 0;
    if (_sparks) {
        [self animateSparks];
    } else {
        [self onFinished];
    }
}

- (void)animateSparks {
    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue  = @(1.0);
    scale.toValue    = @(1.4);
    scale.duration   = 0.15;
    scale.autoreverses = YES;
    [self.layer addAnimation:scale forKey:@"sparks"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self onFinished]; });
}

- (void)onFinished {
    if (_finishedBlock) {
        void (^block)(void) = _finishedBlock;
        _finishedBlock = nil;
        block();
    }
}

- (void)stopTimer {
    [_countdownTimer invalidate];
    _countdownTimer = nil;
}

- (void)dealloc {
    [self stopTimer];
}

@end
