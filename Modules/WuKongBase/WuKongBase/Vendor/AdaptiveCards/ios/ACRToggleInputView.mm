//
//  ACRToggleInputView.m
//  AdaptiveCards
//
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "ACRToggleInputView.h"
#import "ACOBundle.h"
#import <Foundation/Foundation.h>

@implementation ACRToggleInputView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }

    return self;
}

- (void)commonInit
{
    // Initialize contentView
    UIStackView *contentview = [[UIStackView alloc] init];
    contentview.axis = UILayoutConstraintAxisHorizontal;
    contentview.alignment = UIStackViewAlignmentCenter;
    contentview.translatesAutoresizingMaskIntoConstraints = NO;

    // Initialize title label
    UILabel *title = [[UILabel alloc] init];
    title.numberOfLines = 0;
    title.lineBreakMode = NSLineBreakByWordWrapping;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [title setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [contentview addArrangedSubview:title];

    // Initialize toggle switch
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    [toggle setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [toggle setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [contentview addArrangedSubview:toggle];

    toggle.tintColor = self.switchOffStateColor;
    toggle.backgroundColor = self.switchOffStateColor;
    toggle.layer.cornerRadius = 16.0f;

    // Set properties
    _contentview = contentview;
    _title = title;
    _toggle = toggle;

    // Add contentview to the view
    [self addSubview:contentview];

    // Set constraints for contentView
    [NSLayoutConstraint activateConstraints:@[
        [contentview.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor],
        [contentview.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor],
        [contentview.centerYAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.centerYAnchor],
        [contentview.heightAnchor constraintEqualToAnchor:self.heightAnchor],
    ]];
}

- (CGSize)intrinsicContentSize
{
    CGSize labelIntrinsicContentSize = [_title intrinsicContentSize];
    CGSize switchIntrinsicContentSize = [_toggle intrinsicContentSize];
    return CGSizeMake(labelIntrinsicContentSize.width + _contentview.spacing + switchIntrinsicContentSize.width, MAX(labelIntrinsicContentSize.height, switchIntrinsicContentSize.height));
}

@end
