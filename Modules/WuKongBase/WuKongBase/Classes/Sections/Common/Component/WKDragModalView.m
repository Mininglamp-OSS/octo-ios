//
//  WKDragModalView.m
//  WuKongBase
//
//  Created by tt on 2021/10/18.
//

#import "WKDragModalView.h"

@interface WKDragModalView ()<CAAnimationDelegate>

@property(nonatomic,assign) CGRect oldFrame;
@property(nonatomic,assign) BOOL recordOldFrame;

@property(nonatomic,strong) UIView *maskView;

@end

@implementation WKDragModalView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.minHeight = 120.0f;
        [self setup];
    }
    return self;
}

-(void) setup {
    self.maskView.frame = [UIScreen mainScreen].bounds;
//    self.delegate = self;
//    self.contentSize = CGSizeMake(self.frame.size.width, self.frame.size.height*2.0f);
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.delaysTouchesBegan = false;
    panGesture.delaysTouchesEnded = false;
    [self addGestureRecognizer:panGesture];
    
   
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
}

-(void) reset {
    self.recordOldFrame  =false;
}


-(void) handlePanGesture:(UIPanGestureRecognizer*)panGesture {
   CGPoint point = [panGesture translationInView:self.superview];


    if(!self.recordOldFrame) {
        self.oldFrame = self.frame;
        self.recordOldFrame = true;
    }
    
    CGFloat newY = self.oldFrame.origin.y + point.y;
    
    switch(panGesture.state) {
        case UIGestureRecognizerStateChanged:
        {
            self.frame = CGRectMake(self.frame.origin.x, newY, self.frame.size.width, self.frame.size.height);
        }
            break;
        case UIGestureRecognizerStateBegan:
        {
        }
            break;
        case UIGestureRecognizerStatePossible:
            break;
        case UIGestureRecognizerStateCancelled:
            break;
        case UIGestureRecognizerStateEnded:
        {
            self.oldFrame = self.frame;
            CGPoint speedPoint = [panGesture velocityInView:self.superview];
            if(fabs(speedPoint.y) >= 0 && fabs(speedPoint.y) <50.0f) {
                return;
            }
            newY = self.oldFrame.origin.y + speedPoint.y;
//            if(newY<0) {
//                newY = 0;
//            }
            if(newY> self.targetView.frame.origin.y - self.minHeight) {
                newY = self.targetView.frame.origin.y - self.minHeight;
            }
            
            if(newY < self.targetView.frame.origin.y -self.oldFrame.size.height ) {
                newY = self.targetView.frame.origin.y -self.oldFrame.size.height;
            }
            
            [[UIApplication sharedApplication].keyWindow addSubview:self.maskView];
           
//            [self startAni:newY];
            [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.frame = CGRectMake(self.frame.origin.x, newY, self.frame.size.width, self.frame.size.height);
            } completion:^(BOOL finished) {
                self.oldFrame = self.frame;
                [self.maskView removeFromSuperview];
            }];
           
        }
            break;
        default:
            break;
            
    }
}

- (UIView *)maskView {
    if(!_maskView) {
        _maskView = [[UIView alloc] init];
        [_maskView setBackgroundColor:[UIColor clearColor]];
        _maskView.userInteractionEnabled = YES;
        UILongPressGestureRecognizer *longGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onMaskPressed)];
        longGesture.minimumPressDuration = 0.2f;
        [_maskView addGestureRecognizer:longGesture];
    }
    return _maskView;
}

-(void) onMaskPressed {
    CGFloat realOriginY = self.layer.presentationLayer.frame.origin.y;
    [self.layer removeAllAnimations];
    self.frame = CGRectMake(self.frame.origin.x, realOriginY, self.frame.size.width, self.frame.size.height);
//    [self stopScrollingAnimation];
}

@end
