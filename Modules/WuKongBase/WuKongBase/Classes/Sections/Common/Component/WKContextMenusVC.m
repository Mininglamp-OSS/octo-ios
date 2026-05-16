//
//  WKContextMenusVC.m
//  WuKongBase
//
//  Created by tt on 2022/6/11.
//

#import "WKContextMenusVC.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "UIKitUtils.h"

@implementation WKMessageReactionModel

-(instancetype) initWithReactionName:(NSString*) reactionName reactionURL:(NSString*)reactionURL {
    self = [super init];
    if(self) {
        self.reactionName = reactionName;
        self.reactionURL = reactionURL;
    }
    return self;
}


@end
@interface WKContextMenusVC ()

@property(nonatomic,strong) UIVisualEffectView *effectView;

@property(nonatomic,strong) UIView *view;

@property(nonatomic,strong) NSArray<WKMessageLongMenusItem*>* toolbarMenus;
@property(nonatomic,weak) id<WKConversationContext> conversationContext;

@property(nonatomic,strong) UIScrollView *scrollView;

@property(nonatomic,assign) CGRect originalProjectedContentViewFrame;

@property(nonatomic,strong) UIView *focusedViewParentView;

//@property(nonatomic,strong) UIView *focusedContainerView;

@end

@implementation WKContextMenusVC

- (instancetype)initWithFocusedView:(UIView*)focusedView toolbarMenus:(NSArray<WKMessageLongMenusItem*>*)toolbarMenus conversationContext:(id<WKConversationContext>)conversationContext originalProjectedContentViewFrame:(CGRect)originalProjectedContentViewFrame{
    self = [super init];
    if (self) {
        self.conversationContext = conversationContext;
        self.focusedView = focusedView;
        self.toolbarMenus = toolbarMenus;
        self.originalProjectedContentViewFrame = originalProjectedContentViewFrame;
       
        [self setupUI];
    }
    return self;
    
}

-(void) setupUI {
    [self.view addSubview:self.effectView];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapBackdrop:)];
    [self.view addGestureRecognizer:tapGesture];
    
    [self.view addSubview: self.effectView];
    [self.view addSubview:self.scrollView];
    
//    [self.focusedContainerView addSubview:self.focusedView];
    
//    CGPoint convertedPoint = [self.scrollView convertPoint:self.focusedView.frame.origin fromView:self.focusedView.superview];
//
//    self.focusedContainerView.frame = self.focusedView.bounds;
//    self.focusedContainerView.lim_top = convertedPoint.y;
//    self.focusedContainerView.lim_left = convertedPoint.x;
}

-(void) presentOnWindow:(UIWindow*)window {
    if(self.view.superview!=nil) {
        return;
    }
    UIImpactFeedbackGenerator *feedBackGenertor = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedBackGenertor impactOccurred];
    
    [window addSubview:self.view];
    
    [window layoutIfNeeded];
    
    self.effectView.effect = makeCustomZoomBlurEffectImpl(true);
    [self.effectView.layer animateAlphaFrom:0.0f to:1.0f duration:0.2f delay:0.0f timingFunction:@"easeInEaseOut" mediaTimingFunction:nil removeOnCompletion:true completion:nil];
    
    
    
    self.focusedViewParentView = self.focusedView.superview;
    
    CGRect contentContainerRect = [self.scrollView convertRect:self.focusedView.frame fromView:self.focusedViewParentView];
    
    [self.scrollView addSubview:self.focusedView];
    
//    [self.focusedView.layer animateAlphaFrom:0.0f to:1.0f duration:0.2f delay:0.0f timingFunction:@"easeInEaseOut" mediaTimingFunction:nil removeOnCompletion:true completion:nil];
//
//
    CGFloat springDuration = 0.52f;
    CGFloat springDamping = 110.0f;
    
    CGPoint fromPoint = CGPointMake(contentContainerRect.origin.x+ contentContainerRect.size.width/2.0f, contentContainerRect.origin.y + contentContainerRect.size.height/2.0f);
    
    NSValue *fromValue =  [NSValue valueWithCGPoint:fromPoint];
    NSValue *toValue = [NSValue valueWithCGPoint:CGPointMake(fromPoint.x, fromPoint.y - 00.0f)];
            
//    self.focusedView.lim_top = 100.0f;
//    self.focusedView.lim_left = 40.0f;
//
    [self.focusedView.layer animateSpringFrom:fromValue to:toValue keyPath:@"position" duration:springDuration delay:0.0f initialVelocity:0.0f damping:springDamping removeOnCompletion:false additive:false completion:nil];
}

-(void) updateFocusedView:(UIView*)focusedView {
    if([self.focusedView.superview isEqual:self.scrollView]) {
        [self.focusedView removeFromSuperview];
        [self.scrollView addSubview:focusedView];
        self.focusedView = focusedView;
    }
}
-(void) updateLayout {
    
}


-(void) dismiss {
    
    
    [self.effectView.layer animateAlphaFrom:1.0f to:0.0f duration:0.2f delay:0.0f timingFunction:@"easeInEaseOut" mediaTimingFunction:nil removeOnCompletion:false completion:^(BOOL v) {
        [self.view removeFromSuperview];
       
        if(self.disMissAction) {
            self.disMissAction();
        }
    }];
    
    [self.focusedView removeFromSuperview];
    [self.focusedViewParentView addSubview:self.focusedView];
    [self.focusedViewParentView layoutSubviews];
    CGPoint orgPoint = CGPointMake(self.originalProjectedContentViewFrame.origin.x + self.originalProjectedContentViewFrame.size.width/2.0f, self.originalProjectedContentViewFrame.origin.y + self.originalProjectedContentViewFrame.size.height/2.0f);
    NSValue *fromValue =  [NSValue valueWithCGPoint:orgPoint];
    NSValue *toValue = [NSValue valueWithCGPoint: orgPoint];
    [self.focusedView.layer animateSpringFrom:fromValue to:toValue keyPath:@"position" duration:0.2f delay:0.0f initialVelocity:0.0f damping:110.0f removeOnCompletion:false additive:false completion:nil];
   
}


-(void) didTapBackdrop:(UIGestureRecognizer*)sender {
    [self dismiss];
}


-(CGRect) convertFrame:(CGRect)frame from:(UIView*)fromView to:(UIView*)toView {
    CGRect sourceWindowFrame =   [fromView convertRect:frame toView:nil];
    CGRect targetWindowFrame = [toView convertRect:sourceWindowFrame fromView:nil];
    UIWindow *fromWindow = fromView.window;
    UIWindow *toWindow = toView.window;
    targetWindowFrame.origin.x += toWindow.bounds.size.width - fromWindow.bounds.size.width;
    return targetWindowFrame;
}

- (UIView *)view {
    if(!_view) {
        _view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
        _view.userInteractionEnabled = YES;
    }
    return _view;
}

- (UIVisualEffectView *)effectView {
    if(!_effectView) {
        _effectView = [[UIVisualEffectView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
        _effectView.userInteractionEnabled = NO;
        if([WKApp shared].config.style == WKSystemStyleDark) {
            _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        }else {
            _effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        }
        _effectView.alpha = 1.0f;
    }
    return _effectView;
}

- (UIScrollView *)scrollView {
    if(!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKScreenHeight)];
        _scrollView.backgroundColor = [UIColor clearColor];
    }
    return _scrollView;
}


@end
