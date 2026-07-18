//
//  ACRButton
//  ACRButton.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRButton.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOBundle.h"
#import "ACOHostConfigPrivate.h"
#import "ACRSVGImageView.h"
#import "ACRUIImageView.h"
#import "ACRViewPrivate.h"
#import "UtiliOS.h"
#import "TSExpressionObjCBridge.h"
#import <Foundation/Foundation.h>

@implementation ACRButton

NSString * const DYNAMIC_TITLE_PROP = @"title.dynamic";
NSString * const DYNAMIC_ENABLE_PROP = @"isEnabled.dynamic";
NSString * const DYNAMIC_VISIBLE_PROP = @"isVisible.dynamic";

- (instancetype)initWithExpandable:(BOOL)expandable
{
    self = [super init];
    if (self) {
        if (expandable) {
            [self setupExpandableConfig];
        } else {
            [self setupDefaultConfig];
        }
    }
    return self;
}

- (void)setupExpandableConfig
{
    self.backgroundColor = UIColor.systemBlueColor;
    self.tintColor = UIColor.systemBackgroundColor;
    
    // Configure autoresizing mask
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;
    
    // Set content insets (10 on all sides)
    self.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    
    // Set the title font (system font with a point size of 15)
    self.titleLabel.font = [UIFont systemFontOfSize:15];
    
    // Set images for various button states using SF Symbols (iOS 13+)
    if (@available(iOS 13.0, *)) {
        UIImage *chevronUp = [UIImage systemImageNamed:@"chevron.up"];
        UIImage *chevronDown = [UIImage systemImageNamed:@"chevron.down"];
        
        [self setImage:chevronUp forState:UIControlStateNormal];
        [self setImage:chevronUp forState:UIControlStateDisabled];
        [self setImage:chevronDown forState:UIControlStateSelected];
        [self setImage:chevronUp forState:UIControlStateHighlighted];
    }
    
    // Set title color for normal state to white
    [self setTitleColor:[UIColor colorWithWhite:1 alpha:1] forState:UIControlStateNormal];
    
    // Set corner radius
    self.layer.cornerRadius = 10;
    
    // Custom runtime attributes translated as properties
    self.positiveForegroundColor = [UIColor colorWithWhite:0.6666666667 alpha:1.0];
    self.positiveBackgroundColor = [UIColor colorWithWhite:0.3333333333 alpha:1.0];
    self.destructiveForegroundColor = [UIColor colorWithWhite:1 alpha:1];
    self.destructiveBackgroundColor = [UIColor colorWithWhite:0.3333333333 alpha:1.0];
    self.positiveUseDefault = YES;
    self.destructiveUseDefault = NO;
}

- (void)setupDefaultConfig
{
    self.backgroundColor = UIColor.systemBlueColor;
    self.tintColor = UIColor.systemBlueColor;
    
    // Configure autoresizing mask
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;
    
    // Content insets of 10 on all sides.
    self.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    
    // Set title color for normal state to white.
    [self setTitleColor:[UIColor colorWithWhite:1 alpha:1] forState:UIControlStateNormal];
    
    // Set corner radius.
    self.layer.cornerRadius = 10;
    
    // Custom runtime attributes translated as properties on ACRButton:
    self.positiveForegroundColor = [UIColor colorWithWhite:0.6666666667 alpha:1.0];
    self.positiveBackgroundColor = [UIColor colorWithWhite:0.3333333333 alpha:1.0];
    self.destructiveForegroundColor = [UIColor colorWithWhite:1 alpha:1.0];
    self.destructiveBackgroundColor = [UIColor colorWithWhite:0.3333333333 alpha:1.0];
    self.positiveUseDefault = YES;
    self.destructiveUseDefault = NO;
}

- (void)setImageView:(UIImage *)image
          withConfig:(ACOHostConfig *)config
{
    [self setImageView:image withConfig:config aspectRatio:0.0f];
}

- (void)setImageView:(UIImage *)image
          withConfig:(ACOHostConfig *)config
         aspectRatio:(float)aspectRatio
{
    CGFloat imageHeight = 0.0f;
    CGSize contentSize = [self.titleLabel intrinsicContentSize];
    
    // apply explicit image size when the below condition is met
    if (_iconPlacement == ACRAboveTitle) {
        imageHeight = [config getHostConfig]->GetActions().iconSize;
    } else { // format the image so it fits in the button
        imageHeight = contentSize.height;
    }
    
    if (image && image.size.height > 0) {
        aspectRatio = image.size.width / image.size.height;
    }
    
    CGSize calculatedImageSize = CGSizeMake(imageHeight * aspectRatio, imageHeight);
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // scale the image using UIImageView
    [NSLayoutConstraint constraintWithItem:_iconView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1.0
                                  constant:calculatedImageSize.width]
        .active = YES;
    
    [NSLayoutConstraint constraintWithItem:_iconView
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1.0
                                  constant:calculatedImageSize.height]
        .active = YES;
    
    int iconPadding = [config getHostConfig]->GetSpacing().defaultSpacing;
    
    if (_iconPlacement == ACRAboveTitle) {
        // fix image view to top and center x of the button
        [NSLayoutConstraint constraintWithItem:_iconView
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1.0
                                      constant:self.contentEdgeInsets.top]
            .active = YES;
        [NSLayoutConstraint constraintWithItem:_iconView
                                     attribute:NSLayoutAttributeCenterX
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeCenterX
                                    multiplier:1.0
                                      constant:0]
            .active = YES;
        // image can't be postion at the top of the title, so adjust title inset edges
        [self setTitleEdgeInsets:UIEdgeInsetsMake(0, iconPadding, -imageHeight - iconPadding, 0)];
        [self setImageEdgeInsets:UIEdgeInsetsMake(0, 0, -imageHeight - iconPadding, 0)];
        CGFloat insetConstant = (calculatedImageSize.height + iconPadding) / 2;
        [self setContentEdgeInsets:UIEdgeInsetsMake(self.contentEdgeInsets.top + insetConstant, 0, self.contentEdgeInsets.bottom + insetConstant, 0)];
    } else if (_iconPlacement == ACRLeftOfTitle) {
        int npadding = 0;
        if (self.doesItHaveAnImageView) {
            iconPadding += (self.imageView.frame.size.width + iconPadding);
            npadding = [config getHostConfig]->GetSpacing().defaultSpacing;
        }
        CGFloat widthOffset = (calculatedImageSize.width + iconPadding);
        
        [self setContentEdgeInsets:UIEdgeInsetsMake(self.contentEdgeInsets.top, self.contentEdgeInsets.left + widthOffset / 2, self.contentEdgeInsets.bottom, self.contentEdgeInsets.right + widthOffset / 2)];
        [self setTitleEdgeInsets:UIEdgeInsetsMake(0, npadding, 0, -(widthOffset + npadding))];
        [_iconView.trailingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor constant:-iconPadding].active = YES;
        
        [NSLayoutConstraint constraintWithItem:_iconView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0].active = YES;
        CGFloat offset = -(self.contentEdgeInsets.left + self.contentEdgeInsets.right);
        
        self.titleWidthConstraint = [self.titleLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:offset];
        self.titleWidthConstraint.active = YES;
        
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:(widthOffset / 2)].active = YES;
        
        self.heightConstraint = [self.heightAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.heightAnchor constant:self.contentEdgeInsets.top + self.contentEdgeInsets.bottom];
        self.heightConstraint.active = YES;
    } else if (_iconPlacement == ACRRightOfTitle) {
        int npadding = 0;
        if (self.doesItHaveAnImageView) {
            iconPadding += (self.imageView.frame.size.width + iconPadding);
            npadding = [config getHostConfig]->GetSpacing().defaultSpacing;
        }

        CGFloat widthOffset = (calculatedImageSize.width + iconPadding);

        // Adjust content insets to accommodate icon on the right
        [self setContentEdgeInsets:UIEdgeInsetsMake(
            self.contentEdgeInsets.top,
            self.contentEdgeInsets.left + widthOffset / 2,
            self.contentEdgeInsets.bottom,
            self.contentEdgeInsets.right + widthOffset / 2
        )];

        // Move the title slightly left, and account for spacing
        [self setTitleEdgeInsets:UIEdgeInsetsMake(0, -iconPadding, 0, npadding + calculatedImageSize.width)];

        [_iconView.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:iconPadding].active = YES;

        [NSLayoutConstraint constraintWithItem:_iconView
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.0
                                      constant:0].active = YES;

        CGFloat offset = -(self.contentEdgeInsets.left + self.contentEdgeInsets.right);

        // Title should not exceed button width minus edge insets
        self.titleWidthConstraint = [self.titleLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:offset];
        self.titleWidthConstraint.active = YES;

        // Shift title to left slightly to visually center the whole content (title + icon)
        [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:-(widthOffset / 2)].active = YES;

        // Ensure button height is enough for title + insets
        self.heightConstraint = [self.heightAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.heightAnchor constant:self.contentEdgeInsets.top + self.contentEdgeInsets.bottom];
        self.heightConstraint.active = YES;
    }
}

+ (UIButton *)rootView:(ACRView *)rootView
     baseActionElement:(ACOBaseActionElement *)acoAction
                 title:(NSString *)title
         andHostConfig:(ACOHostConfig *)config;
{
    ACRButton *button = [[ACRButton alloc] initWithExpandable:[acoAction type] == ACRShowCard];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button.titleLabel setFont:[UIFont systemFontOfSize:15.0]];
    button.titleLabel.font = [UIFontMetrics.defaultMetrics scaledFontForFont:button.titleLabel.font];
    button.isAccessibilityElement = YES;
    button.accessibilityLabel = title;
    button.enabled = [acoAction isEnabled];
    
    // Handle dynamic properties if expression evaluation is enabled
    if ([TSExpressionObjCBridge isExpressionEvalEnabled])
    {
        [ACRButton handleExpressionEvaluationForButton:button baseActionElement:acoAction];
    }
    
    button.sentiment = acoAction.sentiment;
    button.actionType = acoAction.type;
    
    button.defaultPositiveBackgroundColor = [config getTextBlockColor:(ACRContainerStyle::ACRDefault) textColor:(ForegroundColor::Accent)subtleOption:false];
    button.defaultDestructiveForegroundColor = [config getTextBlockColor:(ACRContainerStyle::ACRDefault) textColor:(ForegroundColor::Attention)subtleOption:false];
    [button applySentimentStyling];
    
    std::shared_ptr<AdaptiveCards::BaseActionElement> action = [acoAction element];
    NSDictionary *imageViewMap = [rootView getImageMap];
    NSString *iconURL = [NSString stringWithCString:action->GetIconUrl(ACTheme(rootView.theme)).c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *key = iconURL;
    UIImage *img = imageViewMap[key];
    button.iconPlacement = [ACRButton getIconPlacementAtCurrentContext:rootView url:key];
    NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
    BOOL isSplitButtonEnabled = [featureFlagResolver boolForFlag:@"isSplitButtonEnabled"] ?: NO;
    isSplitButtonEnabled = isSplitButtonEnabled &&
    !rootView.isRenderingInsideBottomSheet &&
    [rootView.acrActionDelegate respondsToSelector:@selector(showBottomSheetForSplitButton:completion:)];
    BOOL isSplitButton = action->GetIsSplitAction();
    
    if (img) {
        UIImageView *iconView = [[ACRUIImageView alloc] init];
        iconView.image = img;
        [button addSubview:iconView];
        button.iconView = iconView;
        [button setImageView:img withConfig:config];
    } else if (key.length) {
        NSNumber *number = [NSNumber numberWithUnsignedLongLong:(unsigned long long)action.get()];
        NSString *key = [number stringValue];
        UIImageView *view = [rootView getImageView:key];
        if ([iconURL hasPrefix:@"icon:"]) {
            // Rendering svg fluent icon here on button
            
            // intentionally kept this 24 so that it always loads
            // irrespective of size given in host config.
            // it is possible that host config has some size which is not available in CDN.
            unsigned int imageHeight = 24;
            BOOL isFilled = [[iconURL lowercaseString] containsString:@"filled"];
            NSString *getSVGURL = cdnURLForIcon(@(action->GetSVGPath([iconURL UTF8String]).c_str()));
            UIImageView *view = [[ACRSVGImageView alloc] init:getSVGURL rtl:rootView.context.rtl isFilled:isFilled size:CGSizeMake(imageHeight, imageHeight) tintColor:button.currentTitleColor];
            button.iconView = view;
            [button addSubview:view];
            [button setImageView:view.image withConfig:config aspectRatio:1.0f];
        } else if (view) {
            if (view.image) {
                button.iconView = view;
                [button addSubview:view];
                // Only remove observer if one was actually added for this imageView
                if ([rootView hasKVOObserverForImageView:view]) {
                    [rootView removeObserverOnImageViewForKeyPath:@"image" onObject:view keyToImageView:key];
                }
                [button setImageView:view.image withConfig:config];
            } else {
                button.iconView = view;
                [button addSubview:view];
                [rootView setImageView:key view:button];
            }
        }
    } else {
        button.heightConstraint = [button.heightAnchor constraintGreaterThanOrEqualToAnchor:button.titleLabel.heightAnchor constant:button.contentEdgeInsets.top + button.contentEdgeInsets.bottom];
        button.heightConstraint.active = YES;
    }
    
    if (isSplitButtonEnabled && isSplitButton)
    {
        NSString *chevronDownIcon = @"ChevronDown";
        NSString *url = [[NSString alloc] initWithFormat:@"%@%@/%@.json", baseFluentIconCDNURL, chevronDownIcon, chevronDownIcon];
        CGSize iconSize = CGSizeMake(16, 16);
        UIImageView *view = [[ACRSVGImageView alloc] init:url rtl:rootView.context.rtl isFilled:true size:iconSize tintColor:button.currentTitleColor];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [button addSubview:view];
        [button setTrailingIcon:view WithConfig:config];
    }
    
    if (button.isEnabled == NO) {
        [button setBackgroundColor:[button.backgroundColor colorWithAlphaComponent:0.5]];
    }
    
    return button;
}

- (void)applySentimentStyling
{
    if ([@"positive" caseInsensitiveCompare:_sentiment] == NSOrderedSame) {
        BOOL usePositiveDefault = _positiveUseDefault;
        
        // By default, positive sentiment must have background accentColor and white text/foreground color
        if (usePositiveDefault) {
            [self setBackgroundColor:_defaultPositiveBackgroundColor];
            [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        } else {
            // Otherwise use the values defined by the user in the ACRButton.xib
            [self setBackgroundColor:_positiveBackgroundColor];
            [self setTitleColor:_positiveForegroundColor forState:UIControlStateNormal];
        }
    } else if ([@"destructive" caseInsensitiveCompare:_sentiment] == NSOrderedSame) {
        BOOL useDestructiveDefault = _destructiveUseDefault;
        
        // By default, destructive sentiment must have a attention text/foreground color
        if (useDestructiveDefault) {
            [self setTitleColor:_defaultDestructiveForegroundColor forState:UIControlStateNormal];
        } else {
            // Otherwise use the values defined by the user in the ACRButton.xib
            [self setBackgroundColor:_destructiveBackgroundColor];
            [self setTitleColor:_destructiveForegroundColor forState:UIControlStateNormal];
        }
    }
}

- (BOOL)doesItHaveAnImageView
{
    return (self.actionType == ACRShowCard && self.imageView && self.imageView.frame.size.width);
}

+ (ACRIconPlacement)getIconPlacementAtCurrentContext:(ACRView *)rootView url:(NSString *)key
{
    if (!key or key.length == 0) {
        return ACRNoTitle;
    }
    
    if ([rootView.context.hostConfig getIconPlacement] == ACRAboveTitle and rootView.context.allHasActionIcons) {
        return ACRAboveTitle;
    }
    
    return ACRLeftOfTitle;
}

- (void)setTrailingIcon:(UIImageView *)imageView WithConfig:(ACOHostConfig *)config
{
    self.trailingIconView = imageView;
    int npadding = 0;
    int iconPadding = [config getHostConfig]->GetSpacing().defaultSpacing;
    if (self.doesItHaveAnImageView) {
        iconPadding += (self.imageView.frame.size.width + iconPadding);
        npadding = [config getHostConfig]->GetSpacing().defaultSpacing;
    }

    CGFloat rightIconWidth = imageView.image.size.width;
    CGFloat rightOffset = rightIconWidth + iconPadding;

    [self setContentEdgeInsets:UIEdgeInsetsMake(
        self.contentEdgeInsets.top,
        self.contentEdgeInsets.left + rightOffset / 2,
        self.contentEdgeInsets.bottom,
        self.contentEdgeInsets.right + rightOffset / 2
    )];

    // Shift title left to make space for the right icon
    [self setTitleEdgeInsets:UIEdgeInsetsMake(0, -iconPadding, 0, npadding + rightIconWidth)];

    [imageView.leadingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor constant:iconPadding].active = YES;

    [NSLayoutConstraint constraintWithItem:imageView
                                 attribute:NSLayoutAttributeCenterY
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeCenterY
                                multiplier:1.0
                                  constant:0].active = YES;

    CGFloat offset = -(self.contentEdgeInsets.left + self.contentEdgeInsets.right);

    self.titleWidthConstraint = [self.titleLabel.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:offset];
    self.titleWidthConstraint.active = YES;

    // Move title slightly left to balance the icon on the right
    [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:-(rightOffset / 2)].active = YES;

    self.heightConstraint = [self.heightAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.heightAnchor constant:self.contentEdgeInsets.top + self.contentEdgeInsets.bottom];
    self.heightConstraint.active = YES;
}

#pragma mark - Expression Evaluation Helper
    
+ (void)evaluateDynamicProperties:(NSString * _Nullable)titleDynamic
                 isVisibleDynamic:(NSString * _Nullable)isVisibleDynamic
                 isEnabledDynamic:(NSString * _Nullable)isEnabledDynamic
                           button:(ACRButton *)button
    {
        
        if (titleDynamic && [titleDynamic isKindOfClass:[NSString class]] && titleDynamic.length > 0)
        {
            [self evaluateExpression:titleDynamic completion:^(id value, NSError *error)
             {
                if ([value isKindOfClass:[NSString class]] && [((NSString *)value) length] > 0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [button setTitle:(NSString *)value forState:UIControlStateNormal];
                    });
                }
            }];
        }
        if (isVisibleDynamic && [isVisibleDynamic isKindOfClass:[NSString class]] && isVisibleDynamic.length > 0)
        {
            [self evaluateExpression:isVisibleDynamic completion:^(id value, NSError *error)
             {
                if ([value isKindOfClass:[NSNumber class]])
                {
                    BOOL visible = [(NSNumber *)value boolValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        button.hidden = !visible;
                    });
                }
            }];
        }
        
        if (isEnabledDynamic && [isEnabledDynamic isKindOfClass:[NSString class]] && isEnabledDynamic.length > 0)
        {
            [self evaluateExpression:isEnabledDynamic completion:^(id value, NSError *error)
             {
                if ([value isKindOfClass:[NSNumber class]])
                {
                    BOOL enabled = [(NSNumber *)value boolValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        button.enabled = enabled;
                    });
                }
            }];
        }
    }

+ (void)handleExpressionEvaluationForButton:(ACRButton *)button
                          baseActionElement:(ACOBaseActionElement *)acoElem
{
   
    NSData *additionalProperty = [acoElem additionalProperty];
    if (additionalProperty)
    {
        NSDictionary *additionalProperties = [NSJSONSerialization JSONObjectWithData:additionalProperty
                                                                             options:NSJSONReadingMutableLeaves
                                                                               error:nil];
        NSString * _Nullable titleDynamic = additionalProperties[DYNAMIC_TITLE_PROP];
        NSString * _Nullable isEnabledDynamic = additionalProperties[DYNAMIC_ENABLE_PROP];
        NSString * _Nullable isVisibleDynamic = additionalProperties[DYNAMIC_VISIBLE_PROP];
        [self evaluateDynamicProperties:titleDynamic
                       isVisibleDynamic:isVisibleDynamic
                       isEnabledDynamic:isEnabledDynamic
                                 button:button];
    }

}

/// Evaluates an expression string using the Swift ObjCExpressionEvaluator bridge.
/// Calls the completion block with success/failure and result/error.
+ (void)evaluateExpression:(NSString *)expression completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion {
    [TSExpressionObjCBridge evaluateExpression:expression withData:nil completion:^(NSObject * _Nullable evalResult, NSError * _Nullable evalError)
     {
        if (completion)
        {
            completion(evalResult, evalError);
        }
    }];
}

@end
