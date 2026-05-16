// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKContentContainerNode.m

#import "WKContentContainerNode.h"

@implementation WKContentContainerNode

- (instancetype)init {
    self = [super init];
    if (self) {
        _contentNode = [[ASDisplayNode alloc] init];
        _contentNode.automaticallyManagesSubnodes = NO;
        [self addSubnode:_contentNode];
    }
    return self;
}

- (void)layout {
    [super layout];
    _contentNode.frame = self.bounds;
}

- (void)layoutUpdatedForOCWithSize:(CGSize)size {
    [_contentNode setNeedsLayout];
}

@end
