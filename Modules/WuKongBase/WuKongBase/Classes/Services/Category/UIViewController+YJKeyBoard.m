//
//  UIViewController+YJKeyBoard.m
//  一行代码解决iOS键盘遮挡问题



#import "UIViewController+YJKeyBoard.h"
#import <objc/runtime.h>
static char YjNeedScrollView;
static char YjMoveDistance;
static char YjCurrentEditViewBottom;

@implementation UIViewController (YJKeyBoard)

- (void)yj_addKeyBoardHandle{
    [self yj_hookOriginalSelector:@selector(viewWillAppear:) swizzledSelector:@selector(yj_viewWillAppear:)];
    [self yj_hookOriginalSelector:@selector(viewWillDisappear:) swizzledSelector:@selector(yj_viewWillDisappear:)];
}

- (void)yj_hookOriginalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector {
    
    Class aClass = [self class];
    
    Method originalMethod = class_getInstanceMethod(aClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector);
    BOOL didAddMethod = class_addMethod(aClass,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(aClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)yj_viewWillAppear:(BOOL)animated{
    [self yj_viewWillAppear:animated];
    [self addKeyboardObserver];
}

- (void)yj_viewWillDisappear:(BOOL)animated{
    [self yj_viewWillDisappear:animated];
    [self removeKeyboardObserver];
}

#pragma mark

- (void)addKeyboardObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameWillChange:) name:UIKeyboardDidChangeFrameNotification object:nil];
}


- (void)removeKeyboardObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidChangeFrameNotification object:nil];
}

#pragma mark

- (void)setProperty{
    UIView *currentEditView = [self getCurrentEditView];
    self.yj_currentEditViewBottom = [self getCurrentEditViewBottom:currentEditView];
    if (!self.yj_needScrollView) {
        self.yj_needScrollView = self.view;
    }
}

- (UIView *)getCurrentEditView{
    return [self findCurrentEditView:self.view];
}

- (UIView *)findCurrentEditView:(UIView *)view{
    for (UIView *childView in view.subviews) {
        if ([childView respondsToSelector:@selector(isFirstResponder)] && [childView isFirstResponder]){
            return childView;
        }
        UIView *result = [self findCurrentEditView:childView];
        if (result) {
            return result;
        }
    }
    return nil;
}

- (CGFloat)getCurrentEditViewBottom:(UIView *)view{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    return [view convertRect:view.bounds toView:window].origin.y + view.frame.size.height;
}

#pragma mark

- (BOOL)keyboardWillShow:(NSNotification *)noti{
    [self setProperty];
    
    CGFloat animationDuration = [[[noti userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGRect keyboardBounds = [[[noti userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    //键盘是否挡住输入框，h<0则挡住了
    CGFloat h = keyboardBounds.origin.y - self.yj_currentEditViewBottom;
    if (h < 0) {
        [self handleMoveDistance:h animateWithDuration:animationDuration];
    }
    return YES;
}

- (BOOL)keyboardWillHide:(NSNotification *)noti
{
    CGFloat animationDuration = [[[noti userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    [self handleMoveDistance:(-self.yj_moveDistance) animateWithDuration:animationDuration];
    
    return YES;
}

- (BOOL)keyboardFrameWillChange:(NSNotification*)noti
{
    if (self.yj_moveDistance == 0) {
        return NO;
    }
    
    CGFloat animationDuration = [[[noti userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGRect keyboardBounds = [[[noti userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    //键盘是否挡住输入框，h<0则挡住了
    CGFloat h = keyboardBounds.origin.y - (self.yj_currentEditViewBottom + self.yj_moveDistance);
    if (h < 0) {
        [self handleMoveDistance:h animateWithDuration:animationDuration];
    }
    
    return YES;
}

#pragma mark

- (void)handleMoveDistance:(CGFloat)distance animateWithDuration:(NSTimeInterval)duration
{
    [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self moveNeedScrollViewDistance:distance];
        self.yj_moveDistance += distance;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)moveNeedScrollViewDistance:(CGFloat)distance{
    if ([self.yj_needScrollView isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scV = (UIScrollView *)self.yj_needScrollView;
        scV.contentOffset = CGPointMake(scV.contentOffset.x, scV.contentOffset.y - distance);
        scV.contentSize = CGSizeMake(scV.contentSize.width, scV.contentSize.height - distance);
    } else {
        self.yj_needScrollView.frame = CGRectMake(0, self.yj_needScrollView.frame.origin.y + distance, self.yj_needScrollView.frame.size.width, self.yj_needScrollView.frame.size.height);
    }
}

#pragma mark

- (void)setYj_moveDistance:(CGFloat)yj_moveDistance{
    objc_setAssociatedObject(self, &YjMoveDistance, @(yj_moveDistance), OBJC_ASSOCIATION_RETAIN);
}

- (CGFloat)yj_moveDistance{
    return [objc_getAssociatedObject(self, &YjMoveDistance) floatValue];
}

- (void)setYj_currentEditViewBottom:(CGFloat)yj_currentEditViewBottom{
    objc_setAssociatedObject(self, &YjCurrentEditViewBottom, @(yj_currentEditViewBottom), OBJC_ASSOCIATION_RETAIN);
}

- (CGFloat)yj_currentEditViewBottom{
    return [objc_getAssociatedObject(self, &YjCurrentEditViewBottom) floatValue];
}

- (void)setYj_needScrollView:(UIView *)yj_needScrollView{
    objc_setAssociatedObject(self, &YjNeedScrollView, yj_needScrollView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)yj_needScrollView{
    return objc_getAssociatedObject(self, &YjNeedScrollView);
}

@end
