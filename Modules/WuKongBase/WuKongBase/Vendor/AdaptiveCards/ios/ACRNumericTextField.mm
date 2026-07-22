//
//  ACRNumericTextFiled
//  ACRNumericTextFiled.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRNumericTextField.h"


@implementation ACRNumericTextField {
    NSCharacterSet *_notDigits;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonInitialization];
        NSMutableCharacterSet *characterSets = [NSMutableCharacterSet characterSetWithCharactersInString:@"-."];
        [characterSets formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
        _notDigits = [characterSets invertedSet];
    }
    return self;
}

- (void)commonInitialization {
    // Configure appearance as per xib settings.
    self.borderStyle = UITextBorderStyleRoundedRect;
    self.placeholder = @" ";
    self.textAlignment = NSTextAlignmentNatural;
    self.clearsOnBeginEditing = YES;
    self.minimumFontSize = 17;
    self.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.font = [UIFont systemFontOfSize:14];
    
    // Configure text input traits.
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.enablesReturnKeyAutomatically = YES;
    
    // Set placeholder text color using KVC (mimicking the userDefinedRuntimeAttributes).
    UIColor *placeholderColor = [UIColor colorWithRed:0.50588235294117645
                                                green:0.50588235294117645
                                                 blue:0.54509803921568623
                                                alpha:1.0];
    @try {
        [self setValue:placeholderColor forKeyPath:@"placeholderLabel.textColor"];
    } @catch (NSException *exception) {
        NSLog(@"Unable to set placeholder text color: %@", exception);
    }
}

@end
