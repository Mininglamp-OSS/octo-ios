//
//  ACRUILabel.m
//  AdaptiveCards
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRUILabel.h"
#import "ACRAggregateTarget.h"
#import "ACRContentHoldingUIView.h"

@implementation ACRUILabel

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.tag = eACRUILabelTag;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    // [octo perf] 显式以 TextKit1 栈初始化。
    // iOS16+ UITextView 默认走 TextKit2，而 ACR 必然访问 .layoutManager（本类子类
    // ACRViewAttachingTextView.commonInit 在 init 里就设 layoutManager.delegate；各
    // renderer 还会设 layoutManager.usesFontLeading）→ 每个文本视图触发一次昂贵的
    // TextKit2→1 运行时转换（快滑时成片出现的 "switching to TextKit 1 compatibility mode"
    // 警告即此，计入 card.build 的 ~7ms）。直接给定 NSTextContainer 走 TextKit1 designated
    // init 可跳过该转换；这些视图本就恒为 TextKit1，最终渲染态与原来完全一致。
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    [layoutManager addTextContainer:textContainer];
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        self.tag = eACRUILabelTag;
    }
    return self;
}


- (CGSize)intrinsicContentSize
{
    self.scrollEnabled = NO;

    return [super intrinsicContentSize];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize size = self.frame.size;
    CGFloat area = size.width * size.height;
    if (self.tag == eACRUIFactSetTag) {
        if (area != _area) {
            [self invalidateIntrinsicContentSize];
        }
    }
    _area = area;
    [self updateAccessibility];
}
- (nullable id) attribute:(NSAttributedStringKey)attributeName atPoint:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint location = point;
    location.x -= self.textContainerInset.left;
    location.y -= self.textContainerInset.top;
    CGFloat fraction = 0.0f;
    NSUInteger characterIndex = [self.layoutManager characterIndexForPoint:location
                                                           inTextContainer:self.textContainer
                                  fractionOfDistanceBetweenInsertionPoints:&fraction];
    // TextView will handle the touch event if the touch was landed within the range over
    // that link or custom attribute, SelectAction was defined
    if (!(fraction == 0.0 || fraction == 1.0) && characterIndex < self.textStorage.length) {
        return [self.textStorage attribute:attributeName atIndex:characterIndex effectiveRange:NULL];
    }
    return nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([self attribute:NSLinkAttributeName atPoint:point withEvent:event] != nil) {
        return self;
    }
    return nil;
}

// translate point where touch landed into character index in text container,
// since an exception, which is expensive and hard to handle in obj-c is thrown,
// we check the range for the index, and try to retrieve an attribute at the index
- (void)handleInlineAction:(UIGestureRecognizer *)gestureRecognizer
{
    ACRUILabel *view = (ACRUILabel *)gestureRecognizer.view;
    if (view) {
        id target = [view retrieveTarget:gestureRecognizer];
        if (target) {
            if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                [target showToolTip:(UILongPressGestureRecognizer *)gestureRecognizer];
            } else if ([target respondsToSelector:@selector(doSelectAction)]) {
                [target doSelectAction];
            }
        }
    }
}

- (void)updateAccessibility
{
    if ([self.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length == 0) {
        return;
    }
    self.isAccessibilityElement = YES;
    if (self.accessibilityTraits == UIAccessibilityTraitLink)
    {
        self.accessibilityHint = self.text;
    }
}

- (ACRBaseTarget *)retrieveTarget:(UIGestureRecognizer *)gestureRecognizer
{
    ACRUILabel *view = (ACRUILabel *)gestureRecognizer.view;
    CGPoint pt = [gestureRecognizer locationInView:view];
    pt.x -= view.textContainerInset.left;
    pt.y -= view.textContainerInset.top;

    NSUInteger indexAtChar = [[view layoutManager] characterIndexForPoint:pt inTextContainer:view.textContainer fractionOfDistanceBetweenInsertionPoints:NULL];
    if (indexAtChar < view.textStorage.length) {
        return [view.attributedText attribute:NSLinkAttributeName atIndex:indexAtChar effectiveRange:nil];
    }

    return nil;
}

// Due to Apple's VO bug, UITextView's isEditable field has to be set YES, to prevent
// editing, implemented the delegate below.
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    return NO;
}

@end
