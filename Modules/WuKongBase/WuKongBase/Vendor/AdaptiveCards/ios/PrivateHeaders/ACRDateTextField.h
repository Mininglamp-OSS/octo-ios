//
//  ACRDateTextField
//  ACRDateTextField.h
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "ACOHostConfig.h"
#import "ACRIBaseInputHandler.h"
#import "ACRTextField.h"
#import "BaseInputElement.h"
#import "SharedAdaptiveCard.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/ACOHostConfig.h>
#import <AdaptiveCards/ACRIBaseInputHandler.h>
#import <AdaptiveCards/ACRTextField.h>
#import <AdaptiveCards/BaseInputElement.h>
#import <AdaptiveCards/SharedAdaptiveCard.h>
#endif
#import <UIKit/UIKit.h>

@interface ACRDateTextField : ACRTextField <ACRIBaseInputHandler>
@property NSDate *min;
@property NSDate *max;
@property NSRegularExpression *regularExpression;

- (instancetype)initWithTimeDateInput:(std::shared_ptr<AdaptiveCards::BaseInputElement> const &)elem
                            dateStyle:(NSDateFormatterStyle)dateStyle
                           hostConfig:(ACOHostConfig *)hostConfig;
- (IBAction)update:(UIDatePicker *)picker;
- (IBAction)dismiss;
@end
