//
//  ACRViewTextAttachment.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ACRTextAttachedViewProvider.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Custom text attachment object containing a view. ACRViewAttachingTextViewBehavior tracks attachments
 of this class and automatically manages adding and removing subviews in its text view.
 */
@interface ACRViewTextAttachment : NSTextAttachment

@property (nonatomic, strong, readonly) id<ACRTextAttachedViewProvider> viewProvider;

/**
 Initialize the attachment with a view provider.
 */
- (instancetype)initWithViewProvider:(id<ACRTextAttachedViewProvider>)viewProvider;

/**
 Initialize the attachment with a view and an explicit size.
 Warning: If an attributed string that includes the returned attachment is used in more than one text view
 at a time, the behavior is not defined.
 */
- (instancetype)initWithView:(UIView *)view size:(CGSize)size;

/**
 Initialize the attachment with a view and use its current fitting size as the attachment size.
 If the view does not define a fitting size, its current bounds size is used.
 Warning: If an attributed string that includes the returned attachment is used in more than one text view
 at a time, the behavior is not defined.
 */
- (instancetype)initWithView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END