//
//  ACRTextView
//  ACRTextView.h
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACOBaseCardElement.h"
#import "ACRIBaseInputHandler.h"
#import <UIKit/UIKit.h>

@interface ACRTextView : UITextView <ACRIBaseInputHandler, UITextViewDelegate>
@property (nonatomic, copy) NSString *placeholderText;
@property (nonatomic, assign) NSUInteger maxLength;
@property (nonatomic, strong) IBInspectable UIColor *borderColor;
@property (nonatomic, strong) IBInspectable UIColor *placeholderColor;
@property (nonatomic, strong) NSPredicate *regexPredicate;
@property BOOL isShowingPlaceholder;

- (instancetype)initWithFrame:(CGRect)frame element:(ACOBaseCardElement *)element;
- (void)configWithSharedModel:(ACOBaseCardElement *)element;

@end
