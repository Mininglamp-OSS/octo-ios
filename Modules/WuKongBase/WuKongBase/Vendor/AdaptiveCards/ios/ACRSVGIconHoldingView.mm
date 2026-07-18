//
//  ACRSVGIconHoldingView.m
//  AdaptiveCards
//
//  Created by Abhishek on 29/04/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACRSVGIconHoldingView.h"


@implementation ACRSVGIconHoldingView
{
    NSString *_svgPayloadURL;
    CGSize _size;
    ACRRtl _rtl;
    UIImageView *_imageView;
}

- (instancetype)init:(UIImageView *)imageView size:(CGSize)size 
{
    self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    if(self)
    {
        _size = size;
        _imageView = imageView;
        [self setUpView];
    }
    return self;
}

- (void)setUpView
{
    [self addSubview:_imageView];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:_imageView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1
                                  constant:_size.width];
    
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:_imageView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1
                                  constant:_size.height];
    [_imageView addConstraints:@[heightConstraint, widthConstraint]];
    
    [self.topAnchor constraintEqualToAnchor:_imageView.topAnchor].active = YES;
    [self.bottomAnchor constraintEqualToAnchor:_imageView.bottomAnchor].active = YES;
    
    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:_imageView
                                 attribute:NSLayoutAttributeTrailing
                                 relatedBy:NSLayoutRelationLessThanOrEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeTrailing
                                multiplier:1
                                  constant:0];
    NSLayoutConstraint *leading = [NSLayoutConstraint constraintWithItem:_imageView
                                 attribute:NSLayoutAttributeLeading
                                 relatedBy:NSLayoutRelationGreaterThanOrEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeLeading
                                multiplier:1
                                  constant:0];

    [self addConstraints:@[trailing, leading]];
    
    [self setContentHuggingPriority:249 forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:251 forAxis:UILayoutConstraintAxisHorizontal];
}

@end
