//
//  ACRViewTextAttachment.mm
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 24/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRViewTextAttachment.h"

@interface ACRDirectTextAttachedViewProvider : NSObject <ACRTextAttachedViewProvider>
@property (nonatomic, strong) UIView *view;
- (instancetype)initWithView:(UIView *)view;
@end

@implementation ACRDirectTextAttachedViewProvider

- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    if (self) {
        _view = view;
    }
    return self;
}

- (UIView *)instantiateViewForAttachment:(ACRViewTextAttachment *)attachment 
                              inBehavior:(ACRViewAttachingTextViewBehavior *)behavior {
    return self.view;
}

- (CGRect)boundsForAttachment:(ACRViewTextAttachment *)attachment
                textContainer:(NSTextContainer *)textContainer
        proposedLineFragment:(CGRect)lineFrag
               glyphPosition:(CGPoint)position {
    return attachment.bounds;
}

@end

@interface UIView (ACRTextAttachmentFittingSize)
- (CGSize)acr_textAttachmentFittingSize;
@end

@implementation UIView (ACRTextAttachmentFittingSize)

- (CGSize)acr_textAttachmentFittingSize {
    CGSize fittingSize = [self systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    if (fittingSize.width > 1e-3 && fittingSize.height > 1e-3) {
        return fittingSize;
    } else {
        return self.bounds.size;
    }
}

@end

@implementation ACRViewTextAttachment

- (instancetype)initWithViewProvider:(id<ACRTextAttachedViewProvider>)viewProvider {
    self = [super initWithData:nil ofType:nil];
    if (self) {
        _viewProvider = viewProvider;
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view size:(CGSize)size {
    ACRDirectTextAttachedViewProvider *provider = [[ACRDirectTextAttachedViewProvider alloc] initWithView:view];
    self = [self initWithViewProvider:provider];
    if (self) {
        self.bounds = CGRectMake(0, 0, size.width, size.height);
    }
    return self;
}

- (instancetype)initWithView:(UIView *)view {
    return [self initWithView:view size:[view acr_textAttachmentFittingSize]];
}

#pragma mark - NSTextAttachmentContainer

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
    return [self.viewProvider boundsForAttachment:self
                                    textContainer:textContainer
                            proposedLineFragment:lineFrag
                                   glyphPosition:position];
}

- (nullable UIImage *)imageForBounds:(CGRect)imageBounds
                       textContainer:(nullable NSTextContainer *)textContainer
                      characterIndex:(NSUInteger)charIndex {
    return nil;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
    [NSException raise:NSInternalInconsistencyException
                format:@"ACRViewTextAttachment cannot be decoded."];
    return nil;
}

@end