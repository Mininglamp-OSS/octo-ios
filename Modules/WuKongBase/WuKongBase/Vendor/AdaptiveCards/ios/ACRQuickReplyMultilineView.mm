//
//  ACRQuickReplyMultilineView
//  ACRQuickReplyMultilineView.mm
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRQuickReplyMultilineView.h"
#import "ACOBundle.h"

@implementation ACRQuickReplyMultilineView


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.backgroundColor = [UIColor whiteColor];
    
    // Create the content view (strong).
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView = contentView;
    
    // Create the text view.
    ACRTextView *textView = [[ACRTextView alloc] init];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.layer.borderWidth = 0.5;
    textView.layer.borderColor = [[UIColor colorWithWhite:0.6666666667 alpha:1.0] CGColor];
    textView.layer.cornerRadius = 5;
    textView.scrollEnabled = NO;
    textView.allowsEditingTextAttributes = YES;
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    // Set the placeholderColor (using the system color defined in the XIB).
    if ([textView respondsToSelector:@selector(setPlaceholderColor:)]) {
        textView.placeholderColor = [UIColor colorWithRed:0.235 green:0.235 blue:0.263 alpha:0.3];
    }
    [contentView addSubview:textView];
    self.textView = textView;
    
    // Create the spacing view.
    UIView *spacing = [[UIView alloc] init];
    spacing.translatesAutoresizingMaskIntoConstraints = NO;
    spacing.backgroundColor = [UIColor whiteColor];
    [contentView addSubview:spacing];
    self.spacing = spacing;
    
    // Create the button.
    ACRButton *button = [ACRButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    // Configure normal state title color.
    [button setTitleColor:[UIColor colorWithWhite:0.3333333333 alpha:1.0] forState:UIControlStateNormal];
    [contentView addSubview:button];
    self.button = button;
    
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:contentView];
    [NSLayoutConstraint activateConstraints:@[
        // Content view fills the safe area.
        [contentView.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor],
        
        // Text view constraints (top and bottom with an 8-point padding).
        [textView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:8],
        [textView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-8],
        
        // Spacing view: fixed width of 8, full height of the text view.
        [spacing.leadingAnchor constraintEqualToAnchor:textView.trailingAnchor],
        [spacing.topAnchor constraintEqualToAnchor:textView.topAnchor],
        [spacing.bottomAnchor constraintEqualToAnchor:textView.bottomAnchor],
        [spacing.widthAnchor constraintEqualToConstant:8],
        
        // Button: leading to spacing's trailing, trailing to contentView, bottom aligned with text view,
        // fixed dimensions 30x30.
        [button.leadingAnchor constraintEqualToAnchor:spacing.trailingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [button.bottomAnchor constraintEqualToAnchor:textView.bottomAnchor],
    ]];
}

- (ACRButton *)getButton
{
    return _button;
}

@end
