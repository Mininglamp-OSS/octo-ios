//
//  ACRRatingInputView.m
//  AdaptiveCards
//
//  Created by Abhishek on 17/05/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRRatingView.h"
#import "ACOBundle.h"
#import <Foundation/Foundation.h>
#import "ACOHostConfigPrivate.h"

@implementation ACRRatingView
{
    ACRRatingSize _ratingSize;
    ACRRatingColor _ratingColor;
    ACRRatingStyle _style;
    ACOHostConfig *_hostConfig;
    NSMutableArray<UIImageView *> *_starImageViews;
    NSMutableArray<UIImageView *> *_accessibleChildren;
    UILabel *_ratingLabel;
    NSInteger _max;
    double _value;
    BOOL _readOnly;
    NSInteger _count;
    
}

- (instancetype)initWithEditableValue:(double)value
                                  max:(NSInteger)max
                                 size:(ACRRatingSize)size
                          ratingColor:(ACRRatingColor)ratingColor
                           hostConfig:(ACOHostConfig *)hostConfig

{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        _max = max;
        _value = value;
        _ratingColor = ratingColor;
        _ratingSize = size;
        _readOnly = NO;
        _count = 0;
        _style = ACRDefaultStyle;
        _hostConfig = hostConfig;
        _accessibleChildren = [NSMutableArray array];
        [self setupViewForInput];
    }
    return self;
}

- (instancetype)initWithReadonlyValue:(double)value
                                  max:(NSInteger)max
                                 size:(ACRRatingSize)size
                          ratingColor:(ACRRatingColor)ratingColor
                                style:(ACRRatingStyle)style
                                count:(NSInteger)count
                           hostConfig:(ACOHostConfig *)hostConfig
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        _max = max;
        _value = value;
        _ratingColor = ratingColor;
        _ratingSize = size;
        _readOnly = YES;
        _count = count;
        _style = style;
        _hostConfig = hostConfig;
        [self setupReadOnlyView];
    }
    return self;
}

- (NSArray *)accessibleChildren
{
    return [_accessibleChildren copy];
}

- (void)setupViewForInput
{
    _starImageViews = [NSMutableArray array];
    
    for (NSInteger i = 0; i < _max; i++)
    {
        UIImageView *starImageView = [[UIImageView alloc] initWithImage:[self emptyStarImage]];
        starImageView.translatesAutoresizingMaskIntoConstraints = NO;
        starImageView.contentMode = UIViewContentModeCenter;
        [self addSubview:starImageView];
        [_starImageViews addObject:starImageView];
        starImageView.userInteractionEnabled = YES;
        starImageView.isAccessibilityElement = YES;
        starImageView.accessibilityLabel = [NSString stringWithFormat:@"Rate %d Star", (int)i+1];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleStarTap:)];
        [starImageView addGestureRecognizer:tapGesture];
        [_accessibleChildren addObject:starImageView];
    }
    
    [self setupConstraints];
    [self updateStarImages];
}

- (void)setupReadOnlyView
{
    _starImageViews = [NSMutableArray array];
    if(_style == ACRCompactStyle)
    {
        UIImageView *starImageView = [[UIImageView alloc] initWithImage:[self emptyStarImage]];
        starImageView.translatesAutoresizingMaskIntoConstraints = NO;
        starImageView.contentMode = UIViewContentModeCenter;
        [self addSubview:starImageView];
        [_starImageViews addObject:starImageView];
    }
    else
    {
        for (NSInteger i = 0; i < _max; i++)
        {
            UIImageView *starImageView = [[UIImageView alloc] initWithImage:[self emptyStarImage]];
            starImageView.translatesAutoresizingMaskIntoConstraints = NO;
            starImageView.contentMode = UIViewContentModeCenter;
            [self addSubview:starImageView];
            [_starImageViews addObject:starImageView];
        }
    }
    
    _ratingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _ratingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _ratingLabel.attributedText = [self atrributedStringForLabel];
    if (_count > 0)
    {
        _ratingLabel.accessibilityLabel = [[NSString alloc] initWithFormat:@"Rating %.1f,", (float)_value];
    }
    else
    {
        _ratingLabel.accessibilityLabel = [[NSString alloc] initWithFormat:@"Rating %.1f, Count %d", (float)_value, (int)_count];
    }
    
    [self addSubview:_ratingLabel];
    
    [self setupConstraints];
    [self updateStarImages];
}

- (void)setupConstraints
{
    CGFloat gap = _readOnly ? 2 : 0;
    for (NSUInteger i = 0; i < _starImageViews.count; i++)
    {
        UIImageView *starImageView = _starImageViews[i];
        
        // top and bottom
        [NSLayoutConstraint activateConstraints:@[
            [starImageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [starImageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
        ]];

        if (i == 0)
        {
            // Leading constraint for the first star
            [NSLayoutConstraint activateConstraints:@[
                [starImageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            ]];
        }
        else
        {
            // Horizontal spacing between stars
            UIImageView *previousStarImageView = _starImageViews[i - 1];
            [NSLayoutConstraint activateConstraints:@[
                [starImageView.leadingAnchor constraintEqualToAnchor:previousStarImageView.trailingAnchor constant:gap]
            ]];
        }
        CGFloat padding = _readOnly ? 0 : (_ratingSize == ACRMedium) ? 8 : 6;
        // Width and height constraints for each star
        [NSLayoutConstraint activateConstraints:@[
            [starImageView.widthAnchor constraintEqualToConstant:[self sizeOfStar].width + (padding * 2)],
            [starImageView.heightAnchor constraintEqualToConstant:[self sizeOfStar].height + (padding * 2)]
        ]];
        
        if (i == _starImageViews.count - 1)
        {
            // Trailing constraint for the last star
            if(_ratingLabel != nil)
            {
                [NSLayoutConstraint activateConstraints:@[
                    [_ratingLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
                ]];
                [NSLayoutConstraint activateConstraints:@[
                    [_ratingLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
                ]];
                [NSLayoutConstraint activateConstraints:@[
                    [starImageView.trailingAnchor constraintEqualToAnchor:_ratingLabel.leadingAnchor constant:-(_readOnly ? 4: gap)]
                ]];
            }
            else
            {
                [NSLayoutConstraint activateConstraints:@[
                    [starImageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
                ]];
            }
        }
    }
}

- (NSInteger)getValue
{
    return _value;
}

- (void)setValue:(NSInteger)value
{
    _value = value;
    [self updateStarImages];
}

- (UIImage *)emptyStarImage
{
    NSString *emptyStarFormat = _readOnly ? @"ic_fluent_star_%ld_filled" : @"ic_fluent_star_%ld_regular";
    NSString *nameOfStar = [[NSString alloc] initWithFormat:emptyStarFormat, (long)([self sizeOfStar].width)];
    UIImage *emptyStarImage = [UIImage imageNamed:nameOfStar inBundle:[[ACOBundle getInstance] getBundle] compatibleWithTraitCollection:nil];
    return emptyStarImage;
}

- (UIImage *)filledStarImage
{
    NSString *nameOfStar = [[NSString alloc] initWithFormat:@"ic_fluent_star_%ld_filled", (long)([self sizeOfStar].width)];
    UIImage *filledStarImage = [UIImage imageNamed:nameOfStar inBundle:[[ACOBundle getInstance] getBundle] compatibleWithTraitCollection:nil];
    return filledStarImage;
}

- (void)handleStarTap:(UITapGestureRecognizer *)gesture
{
    UIImageView *tappedStar = (UIImageView *)gesture.view;
    NSInteger index = [_starImageViews indexOfObject:tappedStar];
    _value = index + 1;
    [self updateStarImages];
    [_ratingValueChangeDelegate didChangeValueTo:_value];
}

- (void)updateStarImages
{
    NSUInteger totalFilledStars = (NSUInteger)_value;
    for (NSUInteger i = 0; i < _starImageViews.count; i++)
    {
        UIImageView *starImageView = _starImageViews[i];
        if (i < totalFilledStars)
        {
            starImageView.image = [self filledStarImage];
            starImageView.tintColor = [self colorForFilledStars];
        }
        else
        {
            starImageView.image = [self emptyStarImage];
            starImageView.tintColor = [self colorForEmptyStars];
        }
    }
}

- (UIColor *)colorForFilledStars
{
    RatingElementConfig ratingElementConfig = [self ratingElementConfig];
    
    switch (_ratingColor)
    {
        case ACRMarigold:
            return [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.filledStar.marigoldColor.c_str()];
            
        case ACRNeutral:
            return [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.filledStar.neutralColor.c_str()];
            
        default:
            return [ACOHostConfig convertHexColorCodeToUIColor:ratingElementConfig.filledStar.marigoldColor.c_str()];
    }
}

- (UIColor *)colorForEmptyStars
{
    RatingElementConfig ratingElementConfig = [self ratingElementConfig];
    
    switch (_ratingColor)
    {
        case ACRMarigold:
            return [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.emptyStar.marigoldColor.c_str()];
            
        case ACRNeutral:
            return [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.emptyStar.neutralColor.c_str()];
            
        default:
            return [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.emptyStar.marigoldColor.c_str()];
    }
}

- (CGSize)sizeOfStar
{
    switch (_ratingSize)
    {
        case ACRMedium:
            return _readOnly ? CGSizeMake(16, 16) : CGSizeMake(28, 28);
            
        case ACRLarge:
        default:
            return _readOnly ? CGSizeMake(20, 20): CGSizeMake(32, 32);
    }
}

- (NSAttributedString *)atrributedStringForLabel
{
    RatingElementConfig ratingElementConfig = [self ratingElementConfig];
    CGFloat fontSize = _ratingSize == ACRMedium ? 15 : 17;
    NSString *ratingValue = [[NSString alloc] initWithFormat:@"%.1f", _value];
    NSMutableAttributedString *ratingAttributedStr = [[NSMutableAttributedString alloc] initWithString:ratingValue];
    UIFont *boldFont = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
    [ratingAttributedStr addAttribute:NSFontAttributeName
                            value:boldFont
                            range:NSMakeRange(0, ratingAttributedStr.length)];
    
    
    UIColor *ratingTextColor = [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.ratingTextColor.c_str()];
     [ratingAttributedStr addAttribute:NSForegroundColorAttributeName
                            value:ratingTextColor
                            range:NSMakeRange(0, ratingAttributedStr.length)];
    
    if(_count != 0)
    {
        UIColor *countTextColor = [ACOHostConfig convertHexColorCodeToUIColor: ratingElementConfig.ratingTextColor.c_str()];
        NSMutableAttributedString *ratingCountStr = [[NSMutableAttributedString alloc] initWithString:[[NSString alloc] initWithFormat:@"%ld", (long)_count]];
        UIFont *ratingFont = [UIFont systemFontOfSize:fontSize weight:UIFontWeightRegular];
        NSDictionary *dotAttributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: countTextColor,
            NSBaselineOffsetAttributeName: @2
        };
        [ratingCountStr addAttribute:NSFontAttributeName
                                value:ratingFont
                                range:NSMakeRange(0, ratingCountStr.length)];
        
        [ratingCountStr addAttribute:NSForegroundColorAttributeName
                                value:countTextColor
                                range:NSMakeRange(0, ratingCountStr.length)];
        NSMutableAttributedString *dotStr = [[NSMutableAttributedString alloc] initWithString:@" • " attributes:dotAttributes];
        
        [ratingAttributedStr appendAttributedString:dotStr];
        [ratingAttributedStr appendAttributedString:ratingCountStr];
    }
    
    return ratingAttributedStr;
}

- (RatingElementConfig) ratingElementConfig
{
    RatingElementConfig ratingElementConfig = _readOnly ?  [_hostConfig getHostConfig]->GetRatingLabelConfig() : [_hostConfig getHostConfig]->GetRatingInputConfig();
    return ratingElementConfig;
}

@end

