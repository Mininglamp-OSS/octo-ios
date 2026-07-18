//
//  ACRQuickReplyView
//  ACRQuickReplyView.mm
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRQuickReplyView.h"
#import "ACOBundle.h"


@implementation ACRQuickReplyView


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
    // Create and configure the stack view.
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];

    // Create and configure the button.
    ACRButton *button = [ACRButton buttonWithType:UIButtonTypeRoundedRect];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // Configure the button's title color for various states.
    [button setTitleColor:[UIColor colorWithWhite:0.3333333333 alpha:1.0] forState:UIControlStateNormal];

    [button setTitleColor:[UIColor colorWithWhite:0.6666666667 alpha:1.0] forState:UIControlStateSelected];
    [button setTitleShadowColor:[UIColor colorWithRed:0.9372549020 green:0.9372549020 blue:0.9568627451 alpha:1.0] forState:UIControlStateSelected];

    UIColor *highlightedColor = [UIColor colorWithRed:0.2441866206 green:0.6352941176 blue:0.2228610195 alpha:1.0];
    [button setTitleColor:highlightedColor forState:UIControlStateHighlighted];
    [button setTitleShadowColor:highlightedColor forState:UIControlStateHighlighted];

    // Add the button as an arranged subview.
    [stack addArrangedSubview:button];

    self.stack = stack;
    self.button = button;

    [self addSubview:self.stack];
    self.layoutMargins = UIEdgeInsetsMake(0, 0, 0, 0);
    self.translatesAutoresizingMaskIntoConstraints = NO;

    // Constrain the stack view to fill the view.
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.layoutMarginsGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.layoutMarginsGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.layoutMarginsGuide.bottomAnchor]
    ]];
}

- (void)addTextField:(ACRTextField *)textField
{
    [self.stack insertArrangedSubview:textField atIndex:0];
    [textField setContentHuggingPriority:249 forAxis:UILayoutConstraintAxisHorizontal];
    [textField setContentCompressionResistancePriority:749 forAxis:UILayoutConstraintAxisHorizontal];
    self.textField = textField;
}

- (BOOL)becomeFirstResponder
{
    if (self.textField) {
        [self.textField becomeFirstResponder];
    }
    return YES;
}

- (BOOL)resignFirstResponder
{
    if (self) {
        [self.textField resignFirstResponder];
    }
    return YES;
}

- (void)dismissNumPad
{
    [self resignFirstResponder];
}

- (ACRButton *)getButton
{
    return _button;
}
@end
