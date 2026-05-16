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

- (void)targetNodeForActivationProgressContentRectForOCWithRect:(CGRect)rect {
    // no-op: Telegram used this to animate the highlight rect; not needed with UIKit menu.
}

@end
