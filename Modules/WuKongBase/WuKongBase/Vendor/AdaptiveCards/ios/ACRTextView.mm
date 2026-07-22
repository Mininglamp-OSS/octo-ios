//
//  ACRTextView
//  ACRTextView.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRTextView.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACRInputLabelView.h"
#import "TextInput.h"
#import "UtiliOS.h"

@implementation ACRTextView {
    NSMutableArray<CompletionHandler> *_completionHandlers;
}

- (instancetype)initWithFrame:(CGRect)frame element:(ACOBaseCardElement *)element
{
    self = [super initWithFrame:frame];
    if (self) {
        _completionHandlers = [[NSMutableArray alloc] init];
        self.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _placeholderColor = [UIColor colorWithRed:0.4313 green:0.4313 blue:0.4313 alpha:1.0];
        [self configWithSharedModel:element];
    }
    return self;
}

- (void)configWithSharedModel:(ACOBaseCardElement *)element
{
    std::shared_ptr<BaseCardElement> elem = [element element];
    std::shared_ptr<TextInput> inputBlck = std::dynamic_pointer_cast<TextInput>(elem);
    _maxLength = inputBlck->GetMaxLength();
    _placeholderText = [[NSString alloc] initWithCString:inputBlck->GetPlaceholder().c_str() encoding:NSUTF8StringEncoding];
    if (inputBlck->GetValue().size()) {
        self.text = [[NSString alloc] initWithCString:inputBlck->GetValue().c_str() encoding:NSUTF8StringEncoding];
        _isShowingPlaceholder = NO;
    } else if ([_placeholderText length]) {
        self.text = _placeholderText;
        self.textColor = _placeholderColor;
        _isShowingPlaceholder = YES;
    }

    self.isRequired = inputBlck->GetIsRequired();
    self.delegate = self;
    self.id = [NSString stringWithCString:inputBlck->GetId().c_str()
                                 encoding:NSUTF8StringEncoding];
    [self registerForKeyboardNotifications];

    self.frame = [self computeBoundingRect];

#if !TARGET_OS_VISION
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, 30);
    UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:frame];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
    [toolBar setItems:@[ doneButton, flexSpace ] animated:NO];
    [toolBar sizeToFit];
    self.inputAccessoryView = toolBar;
#endif
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
    return YES;
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}
// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification *)aNotification
{
    self.scrollEnabled = YES;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification *)aNotification
{
    self.scrollEnabled = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self resignFirstResponder];
    [self notifyDelegates];
    return YES;
}

- (void)dismissKeyboard
{
    [self resignFirstResponder];
}

- (CGSize)intrinsicContentSize
{
    return [self computeBoundingRect].size;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if (!_maxLength) {
        return YES;
    }

    if (range.length + range.location > textView.text.length) {
        return NO;
    }

    NSUInteger newLength = [textView.text length] + [text length] - range.length;
    return newLength <= _maxLength;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (_isShowingPlaceholder) {
        textView.text = @"";
        textView.textColor = [UIColor labelColor];
        _isShowingPlaceholder = NO;
    }
    [textView becomeFirstResponder];
}
- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self updatePlaceholderIfNeeded: textView];
    [textView resignFirstResponder];
}

- (void)updatePlaceholderIfNeeded:(UITextView *)textView {
    if (![textView.text length]) {
        textView.text = _placeholderText;
        textView.textColor = _placeholderColor;
        _isShowingPlaceholder = YES;
    }
}

- (CGRect)computeBoundingRect
{
    BOOL bRemove = NO;

    if (![self.text length]) {
        self.text = @"placeholder text";
        bRemove = YES;
    }
    CGRect boundingrect = [self.layoutManager lineFragmentRectForGlyphAtIndex:0 effectiveRange:nil];
    boundingrect.size.height *= 4;
    self.frame = boundingrect;

    if (bRemove) {
        self.text = @"";
    }
    return boundingrect;
}

#pragma mark - ACRIBaseInputHandler

- (BOOL)validate:(NSError * __autoreleasing *)error
{
    BOOL hasText = self.hasText && !_isShowingPlaceholder;
    return [ACRInputLabelView commonTextUIValidate:self.isRequired hasText:hasText predicate:self.regexPredicate text:self.text error:error];
}

- (void)setFocus:(BOOL)shouldBecomeFirstResponder view:(UIView *_Nullable)view
{
    [ACRInputLabelView commonSetFocus:shouldBecomeFirstResponder view:view];
}

- (void)getInput:(NSMutableDictionary *)dictionary
{
    dictionary[self.id] = _isShowingPlaceholder ? @"" : self.text;
}

- (void)addObserverWithCompletion:(CompletionHandler)completion {
    [_completionHandlers addObject:completion];
}

- (void)notifyDelegates {
    for(CompletionHandler completion in _completionHandlers) {
        completion();
    }
}

- (void)resetInput {
    self.text = @"";
    [self updatePlaceholderIfNeeded:self];
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
    _placeholderColor = placeholderColor;
    if (_isShowingPlaceholder) {
        self.textColor = placeholderColor;
    }
}

@synthesize hasValidationProperties;

@synthesize id;

@synthesize isRequired;

@synthesize hasVisibilityChanged;

@end
