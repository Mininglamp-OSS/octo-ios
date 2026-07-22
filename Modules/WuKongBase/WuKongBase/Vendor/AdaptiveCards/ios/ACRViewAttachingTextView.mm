//
//  ACRViewAttachingTextView.mm
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRViewAttachingTextView.h"
#import "ACRViewAttachingTextViewBehavior.h"
#import "ACRViewAttachingTextViewBehavior.h"
#import "ACRViewTextAttachment.h"

@interface ACRViewAttachingTextView ()
@property (nonatomic, strong) ACRViewAttachingTextViewBehavior *attachmentBehavior;
@end

@implementation ACRViewAttachingTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    id attribute = [self attribute:NSAttachmentAttributeName atPoint:point withEvent:event];
    if (attribute && [attribute isKindOfClass:ACRViewTextAttachment.class]) {
        ACRViewTextAttachment *attachmentAttr = (ACRViewTextAttachment *)attribute;
        return [attachmentAttr.viewProvider instantiateViewForAttachment:attachmentAttr inBehavior:self.attachmentBehavior];
    }
    if ([self attribute:NSLinkAttributeName atPoint:point withEvent:event] != nil) {
        return self;
    }
    return nil;
}

- (void)commonInit {
    // Connect the attachment behavior
    self.attachmentBehavior = [[ACRViewAttachingTextViewBehavior alloc] init];
    self.attachmentBehavior.textView = self;
    self.layoutManager.delegate = self.attachmentBehavior;
    self.textStorage.delegate = self.attachmentBehavior;
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    [super setTextContainerInset:textContainerInset];
    
    // Text container insets are used to convert coordinates between the text container and text view,
    // so a change to these insets must trigger a layout update
    [self.attachmentBehavior layoutAttachedSubviews];
}

@end
