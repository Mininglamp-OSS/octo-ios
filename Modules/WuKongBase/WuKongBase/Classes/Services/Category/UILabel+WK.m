//
//  UILabel+WK.m
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import "UILabel+WK.h"
#import <objc/runtime.h>
#import <WuKongBase/WuKongBase-Swift.h>
static void * kClick = &kClick;
static void * kTokens = &kTokens;

@implementation UILabel (WK)

- (NSArray<id<WKMatchToken>> *)tokens {
    return objc_getAssociatedObject(self, kTokens);
}

-(void) setTokens:(NSArray<id<WKMatchToken>>*)tokens {
    return objc_setAssociatedObject(self, kTokens, tokens, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void) setClick:(void(^)(id<WKMatchToken>))click {
    objc_setAssociatedObject(self, kClick, click, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

-(void(^)(id<WKMatchToken>)) click {
    return objc_getAssociatedObject(self, kClick);
}

-(void) onClick:(void(^)(id<WKMatchToken>))click {
    self.click = click;
    
    self.userInteractionEnabled = YES;
    [self removeAllGestureRecognizers];
   
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    [self addGestureRecognizer:tap];
}

-(void) removeAllGestureRecognizers {
    NSArray *gestures = self.gestureRecognizers;
    if(gestures && gestures.count>0) {
        for (UITapGestureRecognizer *gesture in gestures) {
            [self removeGestureRecognizer:gesture];
        }
    }
}

-(void) onTap:(UITapGestureRecognizer*)gesture {
   id<WKMatchToken> token =  [self didTapAttributedTextInLabel:gesture];
    if(token) {
        if(self.click) {
            self.click(token);
        }
    }
}




-(id<WKMatchToken>) didTapAttributedTextInLabel:(UITapGestureRecognizer *)tapGesture {
    if(!self.tokens || self.tokens.count==0) {
        return false;
    }
    UILabel *label = self;
    
    
    NSParameterAssert(label != nil);
    CGSize labelSize = label.bounds.size;
    // create instances of NSLayoutManager, NSTextContainer and NSTextStorage
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:label.attributedText];

    // configure layoutManager and textStorage
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    // configure textContainer for the label
    textContainer.lineFragmentPadding = 0.0;
    textContainer.lineBreakMode = label.lineBreakMode;
    textContainer.maximumNumberOfLines = label.numberOfLines;
    textContainer.size = labelSize;

    // find the tapped character location and compare it to the specified range
    CGPoint locationOfTouchInLabel = [tapGesture locationInView:label];
    CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
    CGPoint textContainerOffset = CGPointMake((labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                                              (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
    CGPoint locationOfTouchInTextContainer = CGPointMake(locationOfTouchInLabel.x - textContainerOffset.x,
                                                         locationOfTouchInLabel.y - textContainerOffset.y);
    NSInteger indexOfCharacter = [layoutManager characterIndexForPoint:locationOfTouchInTextContainer
                                                            inTextContainer:textContainer
                                   fractionOfDistanceBetweenInsertionPoints:nil];
    for (id<WKMatchToken> token in self.tokens) {
        if (NSLocationInRange(indexOfCharacter, token.range)) {
            return token;
        }
    }
    return nil;
}

-( id<WKMatchToken>) matchDidTapAttributedTextInLabelWithPoint:(CGPoint)locationOfTouchInLabel {
    
    if(!self.tokens || self.tokens.count==0) {
        return false;
    }
    UILabel *label = self;
    
    NSParameterAssert(label != nil);

    CGSize labelSize = label.bounds.size;
    // create instances of NSLayoutManager, NSTextContainer and NSTextStorage
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:label.attributedText];

    // configure layoutManager and textStorage
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    // configure textContainer for the label
    textContainer.lineFragmentPadding = 0.0;
    textContainer.lineBreakMode = label.lineBreakMode;
    textContainer.maximumNumberOfLines = label.numberOfLines;
    textContainer.size = labelSize;

    // find the tapped character location and compare it to the specified range
    CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
    CGPoint textContainerOffset = CGPointMake((labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                                              (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
    CGPoint locationOfTouchInTextContainer = CGPointMake(locationOfTouchInLabel.x - textContainerOffset.x,
                                                         locationOfTouchInLabel.y - textContainerOffset.y);
    NSInteger indexOfCharacter = [layoutManager characterIndexForPoint:locationOfTouchInTextContainer
                                                            inTextContainer:textContainer
                                   fractionOfDistanceBetweenInsertionPoints:nil];
    for (id<WKMatchToken> token in self.tokens) {
        if (NSLocationInRange(indexOfCharacter, token.range)) {
            return token;
        }
    }
    return nil;
}

- (BOOL)didTapAttributedTextInLabel:(UITapGestureRecognizer *)tapGesture inRange:(NSRange)targetRange {
    UILabel *label = (UILabel*)tapGesture.view;
    
    NSParameterAssert(label != nil);

    CGSize labelSize = label.bounds.size;
    // create instances of NSLayoutManager, NSTextContainer and NSTextStorage
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:label.attributedText];

    // configure layoutManager and textStorage
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    // configure textContainer for the label
    textContainer.lineFragmentPadding = 0.0;
    textContainer.lineBreakMode = label.lineBreakMode;
    textContainer.maximumNumberOfLines = label.numberOfLines;
    textContainer.size = labelSize;

    // find the tapped character location and compare it to the specified range
    CGPoint locationOfTouchInLabel = [tapGesture locationInView:label];
    CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
    CGPoint textContainerOffset = CGPointMake((labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                                              (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
    CGPoint locationOfTouchInTextContainer = CGPointMake(locationOfTouchInLabel.x - textContainerOffset.x,
                                                         locationOfTouchInLabel.y - textContainerOffset.y);
    NSInteger indexOfCharacter = [layoutManager characterIndexForPoint:locationOfTouchInTextContainer
                                                            inTextContainer:textContainer
                                   fractionOfDistanceBetweenInsertionPoints:nil];
    if (NSLocationInRange(indexOfCharacter, targetRange)) {
        return YES;
    } else {
        return NO;
    }
}

@end
