//
//  ACRViewAttachingTextViewBehavior.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ACRTextAttachedViewProvider.h"

@class ACRViewTextAttachment;

NS_ASSUME_NONNULL_BEGIN

/**
 Component class managing a text view behavior that tracks all text attachments of ACRViewTextAttachment class,
 automatically inserts/removes their views as text view subviews, and updates their layout according to the
 text view's layout manager.
 */
@interface ACRViewAttachingTextViewBehavior : NSObject <NSLayoutManagerDelegate, NSTextStorageDelegate>

@property (nonatomic, weak, nullable) UITextView *textView;

/**
 Adds attached views as subviews and removes subviews that are no longer attached.
 This method is called automatically when text view's text attributes change.
 Calling this method does not automatically perform a layout of attached subviews.
 */
- (void)updateAttachedSubviews;

/**
 Lays out all attached subviews according to the layout manager.
 This method is called automatically when layout manager finishes updating its layout.
 */
- (void)layoutAttachedSubviews;

@end

NS_ASSUME_NONNULL_END