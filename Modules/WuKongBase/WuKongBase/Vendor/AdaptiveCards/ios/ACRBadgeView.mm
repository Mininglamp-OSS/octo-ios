//
//  ACRBadgeView.m
//  AdaptiveCards
//
//  Created by reenulnu on 09/10/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRBadgeView.h"
#import "ACOBundle.h"
#import "ACOHostConfigPrivate.h"
#include "IconInfo.h"
#import "Icon.h"
#import "ACRSVGImageView.h"
#import "ACRSVGIconHoldingView.h"
#import "ACRBaseTarget.h"
#if defined(ADAPTIVECARDS_USE_FLUENT_TOOLTIPS)
#import <FluentUI/FluentUI-Swift.h>
#endif

@implementation ACRBadgeView
{
    NSString *_text;
    NSString *_toolTip;
    NSString *_iconUrl;
    BOOL _isFilled;
    ACRBadgeAppearance _appearance;
    ACRIconPosition _iconPosition;
    ACRBadgeSize _size;
    ACRShape _shape;
    ACRBadgeStyle _style;
    ACOHostConfig *_hostConfig;
    UIView *_iconImageView;
    UILabel *_textLabel;
    ACRView *_rootView;
}


- (instancetype)initWithRootView:(ACRView *)rootView
                            text:(NSString*)text
                         toolTip:(NSString*)toolTip
                         iconUrl:(NSString*)iconUrl
                        isFilled:(BOOL)isFilled
                      appearance:(ACRBadgeAppearance)appearance
                    iconPosition:(ACRIconPosition)iconPosition
                            size:(ACRBadgeSize)size
                           shape:(ACRShape)shape
                           style:(ACRBadgeStyle)style
                      hostConfig:(ACOHostConfig *)hostConfig
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        _text = text;
        _toolTip = toolTip;
        _iconUrl = iconUrl;
        _isFilled = isFilled;
        _rootView = rootView;
        _appearance = appearance;
        _iconPosition = iconPosition;
        _size = size;
        _shape = shape;
        _style = style;
        _hostConfig = hostConfig;
        [self setupBadgeView];
    }
    return self;
}

- (void)setupBadgeView {
    
    BadgeAppearanceDefinition definition = [self getBadgeAppearanceDefinition];
    self.backgroundColor = [ACOHostConfig convertHexColorCodeToUIColor: definition.backgroundColor.c_str()];
    self.layer.borderColor  =  [ACOHostConfig convertHexColorCodeToUIColor: definition.strokeColor.c_str()].CGColor;
    self.layer.borderWidth = 1;
    if(_iconUrl != nil)
    {
        [self addIconView:definition];
    }
    _textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _textLabel.text = _text;
    _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _textLabel.textColor = [ACOHostConfig convertHexColorCodeToUIColor: definition.textColor.c_str()];
    _textLabel.font = [UIFont systemFontOfSize:[self getTextLabelFontSize] weight:UIFontWeightRegular];
    _textLabel.numberOfLines = 0;
    _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview:_textLabel];
    self.layer.cornerRadius = [self getCornerRadius];
    [self addGestureRecognizer:self toolTipText:_toolTip];
    [self setupConstraints];
    
}

- (void)addGestureRecognizer:(UIView *)view toolTipText:(NSString *)toolTipText
{
    if (view && toolTipText && toolTipText.length) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showToolTip:)];
        [view addGestureRecognizer:longPress];
    }
}

- (void)showToolTip:(UILongPressGestureRecognizer *)recognizer
{
#if defined(ADAPTIVECARDS_USE_FLUENT_TOOLTIPS)
    if (recognizer.state == UIGestureRecognizerStateBegan && _toolTip && recognizer.view) {
        [MSFTooltip.shared showWith:_toolTip for:recognizer.view preferredArrowDirection:MSFTooltipArrowDirectionUp offset:CGPointZero screenMargins:MSFTooltip.defaultScreenMargins dismissOn:MSFTooltipDismissModeTapAnywhere onTap:nil];
    }
#endif
}

-(CGFloat)getTextLabelFontSize
{
    switch (_size) {
        case ACRMediumSize:
            return 13;
        case ACRLargeSize:
            return 15;
        case ACRExtraLargeSize:
            return 15;
        default:
            return 13;
    }
}

-(CGFloat)getCornerRadius
{
    switch (_shape) {
        case ACRSquare:
            return 0;
        case ACRRounded:
            return 4;
        case ACRCircular:
            return 15;
        default:
            return 15;
    }
}

-(void)addIconView:(BadgeAppearanceDefinition) definition
{
    CGSize size = CGSizeMake(12,12);
    if(_size == ACRExtraLargeSize)
    {
        size = CGSizeMake(16, 16);
    }
    UIColor *imageTintColor = [ACOHostConfig convertHexColorCodeToUIColor: definition.textColor.c_str()];
    ACRSVGImageView *iconView = [[ACRSVGImageView alloc] init:_iconUrl
                                                          rtl:_rootView.context.rtl
                                                     isFilled:_isFilled
                                                         size:size
                                                    tintColor:imageTintColor];
    
    ACRSVGIconHoldingView *imageView = [[ACRSVGIconHoldingView alloc] init:iconView size:size];
    _iconImageView = imageView;
    _iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_iconImageView.widthAnchor constraintEqualToConstant:size.width],
        [_iconImageView.heightAnchor constraintEqualToConstant:size.height]
    ]];
    [self addSubview:_iconImageView];
}

- (void)setupConstraints
{
    if(_iconImageView == nil)
    {
        [NSLayoutConstraint activateConstraints:@[
            [_textLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_textLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [_textLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]
        ]];
    }
    else if([_textLabel.text isEqualToString:@"" ])
    {
        [NSLayoutConstraint activateConstraints:@[
            [_iconImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [_iconImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_iconImageView.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
            [_iconImageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10]
        ]];
    }
    else if(_iconPosition == ACRBeforePosition)
    {
        [NSLayoutConstraint activateConstraints:@[
            [_iconImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [_textLabel.leadingAnchor constraintEqualToAnchor:_iconImageView.trailingAnchor constant:10],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_iconImageView.centerYAnchor constraintEqualToAnchor:_textLabel.centerYAnchor],
            [_textLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [_textLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]
        ]];
    } else
    {
        [NSLayoutConstraint activateConstraints:@[
            [_textLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [_iconImageView.leadingAnchor constraintEqualToAnchor:_textLabel.trailingAnchor constant:10],
            [_iconImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_iconImageView.centerYAnchor constraintEqualToAnchor:_textLabel.centerYAnchor],
            [_textLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:6],
            [_textLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]
        ]];
    }
}

- (BadgeAppearanceDefinition )getBadgeAppearanceDefinition
{
    BadgeStylesDefinition badgeStyles = [_hostConfig getHostConfig]->GetBadgeStyles();
    BadgeStyleDefinition badgeStyle;
    BadgeAppearanceDefinition definition;
    
    switch (_style) {
        case ACRBadgeDefaultStyle:
            badgeStyle =  badgeStyles.defaultPalette;
            break;
        case ACRBadgeAccentStyle:
            badgeStyle =  badgeStyles.accentPalette;
            break;
        case ACRBadgeAttentionStyle:
            badgeStyle =  badgeStyles.attentionPalette;
            break;
        case ACRBadgeGoodStyle:
            badgeStyle =  badgeStyles.goodPalette;
            break;
        case ACRBadgeInformativeStyle:
            badgeStyle =  badgeStyles.informativePalette;
            break;
        case ACRBadgeSubtleStyle:
            badgeStyle =  badgeStyles.subtlePalette;
            break;
        case ACRBadgeWarningStyle:
            badgeStyle = badgeStyles.warningPalette;
            break;
        default:
            badgeStyle =  badgeStyles.defaultPalette;
    }
    switch (_appearance) {
        case ACRFilled:
            definition = badgeStyle.filledStyle;
            break;
        case ACRTint:
            definition = badgeStyle.tintStyle;
            break;
        default:
            definition = badgeStyle.filledStyle;;
    }
    return definition;
}

@end
