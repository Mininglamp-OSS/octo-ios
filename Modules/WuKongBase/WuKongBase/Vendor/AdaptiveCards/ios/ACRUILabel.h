//
//  ACRUILable.h
//  AdaptiveCards
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACOBaseCardElement.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ACRUILabel : UITextView <UITextViewDelegate>
@property ACRContainerStyle style;
@property CGFloat area;

- (void)handleInlineAction:(nullable UIGestureRecognizer *)gestureRecognizer;
- (nullable id) attribute:(NSAttributedStringKey)attrName atPoint:(CGPoint)point withEvent:(UIEvent *)event;
@end

NS_ASSUME_NONNULL_END
