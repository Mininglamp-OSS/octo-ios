// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageEffectView.m
//  WuKongBase

#import "WKMessageEffectView.h"
#import "WuKongBase.h"
#import <WuKongBase/WuKongBase-Swift.h>

@implementation WKMessageEffectView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = NO;
    }
    return self;
}

- (void)scheduleRemovalAfterDelay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self cleanupSnapshots];
            [self removeFromSuperview];
        }];
    });
}

- (void)cleanupSnapshots {
    NSArray<WKBubbleSnapshot *> *snaps = self.snapshots;
    if (!snaps) return;
    for (WKBubbleSnapshot *s in snaps) {
        s.originalCell.hidden = NO;
        [s.view removeFromSuperview];
    }
    self.snapshots = nil;
}

@end
