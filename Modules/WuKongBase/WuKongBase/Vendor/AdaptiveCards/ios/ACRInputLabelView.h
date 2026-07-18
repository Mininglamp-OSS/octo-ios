//
//  ACRInputLabelView
//  ACRInputLabelView.h
//
//  Copyright © 2020 Microsoft. All rights reserved.
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "ACOEnums.h"
#import "ACRIBaseInputHandler.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/ACOEnums.h>
#import <AdaptiveCards/ACRIBaseInputHandler.h>
#endif
#import <UIKit/UIKit.h>

@interface ACRInputLabelView : UIView <ACRIBaseInputHandler>
@property (weak, nonatomic) UILabel *errorMessage;
@property (weak, nonatomic) UILabel *label;
@property NSString *labelText;
@property (weak, nonatomic) UIView *inputAccessibilityItem;
@property (strong, nonatomic) UIStackView *stack;
@property (weak, nonatomic) UIView *inputView;
@property (strong, nonatomic) NSObject<ACRIBaseInputHandler> *dataSource;
@property BOOL isRequired;
@property BOOL hasErrorMessage;
@property UIColor *validationFailBorderColor;
@property CGFloat validationFailBorderRadius;
@property CGFloat validationFailBorderWidth;

@property CGColorRef validationSuccessBorderColor;
@property CGFloat validationSuccessBorderRadius;
@property CGFloat validationSuccessBorderWidth;

+ (void)commonSetFocus:(BOOL)shouldBecomeFirstResponder view:(UIView *)view;
+ (BOOL)commonTextUIValidate:(BOOL)isRequired hasText:(BOOL)hasText predicate:(NSPredicate *)predicate text:(NSString *)text error:(NSError *__autoreleasing *)error;
- (NSObject<ACRIBaseInputHandler> *)getInputHandler;
- (void)addAccessibleItems:(NSArray *)items;

@end
