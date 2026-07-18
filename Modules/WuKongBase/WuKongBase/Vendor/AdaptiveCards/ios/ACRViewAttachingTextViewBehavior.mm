//
//  ACRViewAttachingTextViewBehavior.mm
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRViewAttachingTextViewBehavior.h"
#import "ACRViewTextAttachment.h"
#import <CoreGraphics/CoreGraphics.h>

@interface NSAttributedString (ACRViewAttachments)
- (NSArray<NSDictionary *> *)acr_subviewAttachmentRanges;
@end

@interface UITextView (ACRCoordinateConversion)
- (CGPoint)acr_convertPointToTextContainer:(CGPoint)point;
- (CGPoint)acr_convertPointFromTextContainer:(CGPoint)point;
- (CGRect)acr_convertRectToTextContainer:(CGRect)rect;
- (CGRect)acr_convertRectFromTextContainer:(CGRect)rect;
@end

// Utility function to convert CGPoint to integral coordinates
static CGPoint ACRIntegralPointWithScaleFactor(CGPoint point, CGFloat scaleFactor) {
    if (scaleFactor <= 0.0) {
        scaleFactor = 1.0;
    }
    
    return CGPointMake(round(point.x * scaleFactor) / scaleFactor,
                       round(point.y * scaleFactor) / scaleFactor);
}

@implementation ACRViewAttachingTextViewBehavior {
    NSMapTable<id<ACRTextAttachedViewProvider>, UIView *> *_attachedViews;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _attachedViews = [NSMapTable weakToWeakObjectsMapTable];
    }
    return self;
}

#pragma mark - Properties

- (void)setTextView:(UITextView *)textView {
    if (_textView == textView) {
        return;
    }
    
    // Remove all managed subviews from the text view being disconnected
    [self removeAttachedSubviews];
    
    _textView = textView;
    
    // Synchronize managed subviews to the new text view
    [self updateAttachedSubviews];
    [self layoutAttachedSubviews];
}

#pragma mark - Subview tracking

- (NSArray<id<ACRTextAttachedViewProvider>> *)attachedProviders {
    NSMutableArray<id<ACRTextAttachedViewProvider>> *providers = [NSMutableArray array];
    NSEnumerator *keyEnumerator = [_attachedViews keyEnumerator];
    id<ACRTextAttachedViewProvider> provider;
    while ((provider = [keyEnumerator nextObject])) {
        [providers addObject:provider];
    }
    return [providers copy];
}

- (void)updateAttachedSubviews {
    if (!self.textView) {
        return;
    }
    
    // Collect all ACRViewTextAttachment attachments
    NSArray<NSDictionary *> *attachmentRanges = [self.textView.textStorage acr_subviewAttachmentRanges];
    NSMutableArray<ACRViewTextAttachment *> *subviewAttachments = [NSMutableArray array];
    
    for (NSDictionary *rangeDict in attachmentRanges) {
        ACRViewTextAttachment *attachment = rangeDict[@"attachment"];
        [subviewAttachments addObject:attachment];
    }
    
    // Remove views whose providers are no longer attached
    NSArray<id<ACRTextAttachedViewProvider>> *currentProviders = [self attachedProviders];
    for (id<ACRTextAttachedViewProvider> provider in currentProviders) {
        BOOL stillAttached = NO;
        for (ACRViewTextAttachment *attachment in subviewAttachments) {
            if (attachment.viewProvider == provider) {
                stillAttached = YES;
                break;
            }
        }
        if (!stillAttached) {
            UIView *view = [_attachedViews objectForKey:provider];
            [view removeFromSuperview];
            [_attachedViews removeObjectForKey:provider];
        }
    }
    
    // Insert views that became attached
    for (ACRViewTextAttachment *attachment in subviewAttachments) {
        id<ACRTextAttachedViewProvider> provider = attachment.viewProvider;
        if (![_attachedViews objectForKey:provider]) {
            UIView *view = [provider instantiateViewForAttachment:attachment inBehavior:self];
            if (view) {
                [self.textView addSubview:view];
                [_attachedViews setObject:view forKey:provider];
            }
        }
    }
}

- (void)removeAttachedSubviews {
    NSArray<id<ACRTextAttachedViewProvider>> *providers = [self attachedProviders];
    for (id<ACRTextAttachedViewProvider> provider in providers) {
        UIView *view = [_attachedViews objectForKey:provider];
        [view removeFromSuperview];
    }
    [_attachedViews removeAllObjects];
}

#pragma mark - Layout

- (void)layoutAttachedSubviews {
    if (!self.textView) {
        return;
    }
    
    NSLayoutManager *layoutManager = self.textView.layoutManager;
    CGFloat scaleFactor;
    #if !TARGET_OS_VISION
        scaleFactor = self.textView.window.screen.scale ?: [UIScreen mainScreen].scale;
    #else
        scaleFactor = 1.0;
    #endif
    // For each attached subview, find its associated attachment and position it according to its text layout
    NSArray<NSDictionary *> *attachmentRanges = [self.textView.textStorage acr_subviewAttachmentRanges];
    
    for (NSDictionary *rangeDict in attachmentRanges) {
        ACRViewTextAttachment *attachment = rangeDict[@"attachment"];
        NSRange range = [rangeDict[@"range"] rangeValue];
        UIView *view = [_attachedViews objectForKey:attachment.viewProvider];
        
        if (view) {
            CGRect attachmentRect = [self boundingRectForAttachmentCharacterAtIndex:range.location
                                                                      layoutManager:layoutManager];
            
            // Convert to text view coordinates and apply scale factor for pixel alignment
            CGRect viewRect = [self.textView acr_convertRectFromTextContainer:attachmentRect];
            viewRect.origin = ACRIntegralPointWithScaleFactor(viewRect.origin, scaleFactor);
            
            view.frame = viewRect;
        }
    }
}

- (CGRect)boundingRectForAttachmentCharacterAtIndex:(NSUInteger)characterIndex
                                      layoutManager:(NSLayoutManager *)layoutManager {
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:NSMakeRange(characterIndex, 1)
                                                   actualCharacterRange:NULL];
    return [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
}

#pragma mark - NSLayoutManagerDelegate

- (void)layoutManager:(NSLayoutManager *)layoutManager
didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer
                atEnd:(BOOL)layoutFinishedFlag {
    if (layoutFinishedFlag) {
        [self layoutAttachedSubviews];
    }
}

#pragma mark - NSTextStorageDelegate

- (void)textStorage:(NSTextStorage *)textStorage
didProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta {
    if (editedMask & NSTextStorageEditedAttributes) {
        [self updateAttachedSubviews];
    }
    if (editedMask & NSTextStorageEditedCharacters) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self layoutAttachedSubviews];
        });
    }
}

@end

#pragma mark - Category Implementations

@implementation NSAttributedString (ACRViewAttachments)

- (NSArray<NSDictionary *> *)acr_subviewAttachmentRanges {
    NSMutableArray<NSDictionary *> *attachmentRanges = [NSMutableArray array];
    
    [self enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, self.length)
                     options:0
                  usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
        if ([attachment isKindOfClass:[ACRViewTextAttachment class]]) {
            NSDictionary *rangeDict = @{
                @"attachment": attachment,
                @"range": [NSValue valueWithRange:range]
            };
            [attachmentRanges addObject:rangeDict];
        }
    }];
    
    return [attachmentRanges copy];
}

@end

@implementation UITextView (ACRCoordinateConversion)

- (CGPoint)acr_convertPointToTextContainer:(CGPoint)point {
    return CGPointMake(point.x - self.textContainerInset.left,
                       point.y - self.textContainerInset.top);
}

- (CGPoint)acr_convertPointFromTextContainer:(CGPoint)point {
    return CGPointMake(point.x + self.textContainerInset.left,
                       point.y + self.textContainerInset.top);
}

- (CGRect)acr_convertRectToTextContainer:(CGRect)rect {
    return CGRectMake(rect.origin.x - self.textContainerInset.left,
                      rect.origin.y - self.textContainerInset.top,
                      rect.size.width, rect.size.height);
}

- (CGRect)acr_convertRectFromTextContainer:(CGRect)rect {
    return CGRectMake(rect.origin.x + self.textContainerInset.left,
                      rect.origin.y + self.textContainerInset.top,
                      rect.size.width, rect.size.height);
}

@end
