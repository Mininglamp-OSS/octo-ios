//
//  ACRTextAttachedViewProvider.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@class ACRViewTextAttachment;
@class ACRViewAttachingTextViewBehavior;

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol that provides views inserted as subviews into text views that render an ACRViewTextAttachment,
 and customizes their layout.
 */
@protocol ACRTextAttachedViewProvider <NSObject>

/**
 Returns a view that corresponds to the specified attachment.
 Each ACRViewAttachingTextViewBehavior caches instantiated views until the attachment leaves the text container.
 */
- (UIView *)instantiateViewForAttachment:(ACRViewTextAttachment *)attachment 
                              inBehavior:(ACRViewAttachingTextViewBehavior *)behavior;

/**
 Returns the layout bounds of the view that corresponds to the specified attachment.
 Return attachment.bounds for default behavior.
 */
- (CGRect)boundsForAttachment:(ACRViewTextAttachment *)attachment
                textContainer:(nullable NSTextContainer *)textContainer
        proposedLineFragment:(CGRect)lineFrag
               glyphPosition:(CGPoint)position;

@end

NS_ASSUME_NONNULL_END
