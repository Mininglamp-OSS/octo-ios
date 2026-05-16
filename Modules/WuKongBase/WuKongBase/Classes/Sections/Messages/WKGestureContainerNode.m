// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKGestureContainerNode.m

#import "WKGestureContainerNode.h"

@interface WKGestureContainerNode () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UILongPressGestureRecognizer *longPress;
@end

@implementation WKGestureContainerNode

- (instancetype)init {
    self = [super init];
    if (self) {
        _isGestureEnabled = YES;
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (void)didLoad {
    [super didLoad];
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPress.minimumPressDuration = 0.4;
    _longPress.delegate = self;
    // 不消费触摸事件，让 UINavigationController.interactivePopGestureRecognizer
    // 右滑返回手势能正常收到触摸（修复 P5 重写引入的回归）
    _longPress.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:_longPress];
}

- (void)setIsGestureEnabled:(BOOL)isGestureEnabled {
    _isGestureEnabled = isGestureEnabled;
    _longPress.enabled = isGestureEnabled;
}

- (void)setShouldBeginBlock:(BOOL (^)(CGPoint))shouldBeginBlock {
    _shouldBeginBlock = [shouldBeginBlock copy];
}

- (void)setActivatedBlock:(void (^)(UIGestureRecognizer * _Nullable, CGPoint))activatedBlock {
    _activatedBlock = [activatedBlock copy];
}

// Compatibility setters matching the original ObjC block-based API
- (void)setShouldBegin:(BOOL(^)(CGPoint))block { self.shouldBeginBlock = block; }
- (void)setActivated:(void(^)(id, CGPoint))block { self.activatedBlock = block; }

- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gr locationInView:self.view];
        if (_activatedBlock) {
            _activatedBlock(gr, point);
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (!_isGestureEnabled) return NO;
    CGPoint point = [gestureRecognizer locationInView:self.view];
    if (_shouldBeginBlock) {
        return _shouldBeginBlock(point);
    }
    return YES;
}

/// 让 pan 类手势（含导航控制器右滑返回、列表滚动）优先生效。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]];
}

/// 允许与其它 cell 内部手势同时识别（不抢占）。
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)targetNodeForActivationProgressContentRectForOCWithRect:(CGRect)rect {
    // no-op: Telegram used this to animate the highlight rect; not needed with UIKit menu.
}

@end
