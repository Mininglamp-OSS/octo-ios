//
//  TSDirectionalPanGestureRecognizer.m
//  TeamSpaceApp
//
//  Copyright © Microsoft Corporation. All rights reserved.
//

#import "ACRDirectionalPanGestureRecognizer.h"

static CGFloat const ACRkPanThreshold = 5.0;
static CGFloat const ACRkEdgeIgnoreSpacing = 30.0;
static NSTimeInterval const ACRkPanCancelSeconds = 0.2;

@interface ACRDirectionalPanGestureRecognizer ()

@property (nonatomic, assign) CGPoint beginPoint;
@property (nonatomic, strong) NSTimer *timeoutTimer;

@end

@implementation ACRDirectionalPanGestureRecognizer

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action direction:(ACRDirectionalPan)direction
{
    self = [super initWithTarget:target action:action];
    if (self)
    {
        self.direction = direction;
    }
    return self;
}

- (void)stopTimeoutTimer
{
    if ([self.timeoutTimer isValid])
    {
        [self.timeoutTimer invalidate];
        self.timeoutTimer = nil;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    self.beginPoint = [self locationInView:self.view];
    
    [self stopTimeoutTimer];
    
    // Ignore the edges of the screen to avoid being triggered by navigation gestures
    if (self.beginPoint.x < ACRkEdgeIgnoreSpacing || self.beginPoint.x > self.view.bounds.size.width - ACRkEdgeIgnoreSpacing)
    {
        self.state = UIGestureRecognizerStateCancelled;
        return;
    }

    // Need to cancel this gesture so long-press gesture can trigger, cancel if haven't moved the touch after a time delay
    __weak typeof(self) weakSelf = self;
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:ACRkPanCancelSeconds repeats:NO block:^(__unused NSTimer * _Nonnull timer) {
        weakSelf.state = UIGestureRecognizerStateCancelled;
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];

    CGPoint point = [self locationInView:self.view];
    
    if (fabs(point.x - self.beginPoint.x) > ACRkPanThreshold ||
        fabs(point.y - self.beginPoint.y) > ACRkPanThreshold)
    {
        [self stopTimeoutTimer];
    }

    if (self.state == UIGestureRecognizerStateBegan)
    {
        if (self.direction == ACRDirectionalPanLeft)
        {
            if (point.x > self.beginPoint.x || fabs(point.x - self.beginPoint.x) < fabs(point.y - self.beginPoint.y))
            {
                self.state = UIGestureRecognizerStateCancelled;
            }
        }
        else if (self.direction == ACRDirectionalPanRight)
        {
            if (point.x < self.beginPoint.x || fabs(point.x - self.beginPoint.x) < fabs(point.y - self.beginPoint.y))
            {
                self.state = UIGestureRecognizerStateCancelled;
            }
        }
    }
}

@end

