// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKContentContainerNode.h — replaces TelegramUtils ContextExtractedContentContainingNode (GPL v2)
//
//  Provides the content-bearing inner node previously implemented as
//  ContextExtractedContentContainingNode in Telegram's display system.

#import <AsyncDisplayKit/AsyncDisplayKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Drop-in ASDisplayNode replacement for ContextExtractedContentContainingNode.
/// Wraps an inner `contentNode` whose view hosts the actual bubble UI.
@interface WKContentContainerNode : ASDisplayNode

/// Inner node whose `.view` is the actual container for bubble subviews.
@property (nonatomic, strong, readonly) ASDisplayNode *contentNode;

/// The logical content rect within this node (used for layout hints).
@property (nonatomic, assign) CGRect contentRect;

/// Called when layout changes; triggers setNeedsLayout on contentNode.
- (void)layoutUpdatedForOCWithSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
