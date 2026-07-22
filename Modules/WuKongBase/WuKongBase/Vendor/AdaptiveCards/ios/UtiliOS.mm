//
//  UtiliOS
//
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import "UtiliOS.h"
#import "ACOBaseActionElementPrivate.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRBaseCardElementRenderer.h"
#import "ACRBaseTarget.h"
#import "ACRColumnSetView.h"
#import "ACRContentStackView.h"
#import "ACRIBaseActionElementRenderer.h"
#import "ACRRegistration.h"
#import "ACRTableRow.h"
#import "ACRTargetBuilderDirector.h"
#import "ACRUIImageView.h"
#import "ACRViewPrivate.h"
#import "BackgroundImage.h"
#import "BaseActionElement.h"
#import "Enums.h"
#import "MarkDownParser.h"
#import "RichTextElementProperties.h"
#import "TextRun.h"
#import "ACRTapGestureRecognizerFactory.h"

using namespace AdaptiveCards;

// tolerance value for computing scaler for background cover size
const CGFloat kACRScalerTolerance = 0.025f;
NSString const *baseFluentIconCDNURL = @"https://res-1.cdn.office.net/assets/fluentui-react-icons/2.0.226/";

void configVisibility(UIView *view, std::shared_ptr<BaseCardElement> const &visibilityInfo)
{
    if (!visibilityInfo->GetIsVisible()) {
        view.hidden = YES;
    } else {
        view.hidden = NO;
    }

    NSString *hashkey = [NSString stringWithCString:visibilityInfo->GetId().c_str()
                                           encoding:NSUTF8StringEncoding];
    view.tag = hashkey.hash;
}

void configVisibilityWithVisibilityManager(ACRView *rootView, NSObject<ACOIVisibilityManagerFacade> *facade, ACRContentStackView *view)
{
    for (UIView *subview in [view getContentStackSubviews]) {
        [rootView.context registerVisibilityManager:facade targetViewTag:subview.tag];
    }
}


void configSeparatorVisibility(ACRSeparator *view,
                               std::shared_ptr<BaseCardElement> const &visibilityInfo)
{
    if (!view) {
        return;
    }

    if (!visibilityInfo->GetIsVisible()) {
        view.hidden = YES;
    }
    NSMutableString *hashkey = [NSMutableString stringWithCString:visibilityInfo->GetId().c_str()
                                                         encoding:NSUTF8StringEncoding];
    [hashkey appendString:@"-separator"];
    view.tag = hashkey.hash;
    view.isVisibilityObserved = YES;
}

ACRRtl getiOSRtl(std::optional<bool> const rtl)
{
    ACRRtl acrtl = ACRRtlNone;
    if (rtl.has_value()) {
        BOOL doSetRTL = rtl.value_or(false);
        if (doSetRTL) {
            acrtl = ACRRtlRTL;
        } else {
            acrtl = ACRRtlLTR;
        }
    }
    return acrtl;
}

void configRtl(UIView *view, ACORenderContext *context)
{
    if (!view || !context) {
        return;
    }

    ACRRtl rtl = context.rtl;
    if (rtl == ACRRtlNone) {
        return;
    } else if (rtl == ACRRtlRTL) {
        view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    } else if (rtl == ACRRtlRTL) {
        view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    }
}

void renderBackgroundImage(const std::shared_ptr<AdaptiveCards::BackgroundImage> backgroundImage,
                           ACRContentStackView *containerView, ACRView *rootView)
{
    if (rootView == nil || backgroundImage == nullptr || backgroundImage->GetUrl(ACTheme(rootView.theme)).empty()) {
        return;
    }

    std::string imageUrl = backgroundImage->GetUrl(ACTheme(rootView.theme));
    NSString *key = [[NSNumber numberWithUnsignedLongLong:(unsigned long long)(backgroundImage.get())] stringValue];
    if ([key length]) {
        UIImageView *imgView = nil;
        UIImage *img = [rootView getImageMap][key];
        if (img && [img isKindOfClass:[UIImage class]]) {
            switch (backgroundImage->GetFillMode()) {
                case ImageFillMode::Repeat:
                case ImageFillMode::RepeatHorizontally:
                case ImageFillMode::RepeatVertically:
                    imgView = [[ACRUIImageView alloc] init];
                    imgView.backgroundColor = [UIColor colorWithPatternImage:img];
                    break;
                case ImageFillMode::Cover:
                default:
                    imgView = [[ACRUIImageView alloc] initWithImage:img];
                    break;
            }
        } else {
            NSNumber *number =
                [NSNumber numberWithUnsignedLongLong:(unsigned long long)backgroundImage.get()];
            NSString *imageViewKey = [number stringValue];
            imgView = [rootView getImageView:imageViewKey];
            if (!imgView) {
                imgView = [rootView getImageView:@"backgroundImage"];
            }
        }

        if (imgView) {
            imgView.translatesAutoresizingMaskIntoConstraints = NO;
            [containerView insertSubview:imgView atIndex:0];

            if (imgView.image) {
                // if image is ready, proceed to setting contraints
                renderBackgroundImage(rootView, backgroundImage.get(), imgView, imgView.image);
            }
        }
    }
}

void renderBackgroundImage(ACRView *rootView, const BackgroundImage *backgroundImageProperties, UIImageView *imageView,
                           UIImage *image)
{
    if (rootView == nil || backgroundImageProperties == nullptr || imageView == nullptr || image == nullptr || ![image isKindOfClass:[UIImage class]]) {
        return;
    }

    if (backgroundImageProperties->GetFillMode() == ImageFillMode::Repeat ||
        backgroundImageProperties->GetFillMode() == ImageFillMode::RepeatHorizontally ||
        backgroundImageProperties->GetFillMode() == ImageFillMode::RepeatVertically) {
        imageView.backgroundColor = [UIColor colorWithPatternImage:image];
        [rootView removeObserver:rootView forKeyPath:@"image" onObject:imageView];
        imageView.image = nil;
    }
    applyBackgroundImageConstraints(backgroundImageProperties, imageView, image);
    [rootView removeObserver:rootView forKeyPath:@"image" onObject:imageView];
}

// apply contraints for 'Cover' fill mode
// the backgroundView is set on the targetView
void renderBackgroundCoverMode(UIView *backgroundView, UIView *targetView, NSMutableArray<NSLayoutConstraint *> *constraints, ACRContentStackView *parentView)
{
    if (!targetView) {
        targetView = parentView;
    }

    if (!backgroundView || !targetView || ![backgroundView isKindOfClass:[UIImageView class]] || parentView.isBackgroundImageSet) {
        return;
    }

    UIImageView *imageView = (UIImageView *)backgroundView;
    UIImage *image = imageView.image;

    if (!image) {
        return;
    }

    parentView.isBackgroundImageSet = YES;

    imageView.contentMode = UIViewContentModeScaleAspectFill;
    // Fill Mode Description
    // ScaleAspectFill increases one dimension of image proportionally if
    // corresponding dimension increases but it does not increase view surroinding the image
    // find which dimension is in deficit and act accordingly
    // when both dimensions are in deficit find the most deficient dimension
    // and increase
    // center the modified image view to the target view.

    CGSize targetViewSize = targetView.frame.size;
    CGSize sourceSize = image.size;
    BOOL isDeficientInWidth = NO;
    BOOL isDeficientInHeight = NO;

    if (sourceSize.width < targetViewSize.width) {
        isDeficientInWidth = YES;
    }

    if (sourceSize.height < targetViewSize.height) {
        isDeficientInHeight = YES;
    }

    if (isDeficientInWidth || isDeficientInHeight) {
        [constraints addObjectsFromArray:@[
            [imageView.widthAnchor constraintGreaterThanOrEqualToAnchor:targetView.widthAnchor],
            [imageView.heightAnchor constraintGreaterThanOrEqualToAnchor:targetView.heightAnchor]
        ]];
    } else {
        // scale background image view to the minimum size that can still cover all of the target view.
        CGRect newCoverRect = FindClosestRectToCover(CGRectMake(0, 0, sourceSize.width, sourceSize.height), targetView.frame);
        [constraints addObjectsFromArray:@[
            [imageView.widthAnchor constraintEqualToConstant:newCoverRect.size.width],
            [imageView.heightAnchor constraintEqualToConstant:newCoverRect.size.height]
        ]];
    }
}

void applyBackgroundImageConstraints(const BackgroundImage *backgroundImageProperties,
                                     UIImageView *imageView, UIImage *image)
{
    if (backgroundImageProperties == nullptr || imageView == nullptr || image == nullptr) {
        return;
    }

    UIView *superView = [imageView superview];
    if (superView == nullptr) {
        return;
    }

    UIView *backgroundView = nil;
    if ([superView isKindOfClass:[ACRContentStackView class]]) {
        backgroundView = ((ACRContentStackView *)superView).backgroundView;
        if (backgroundView) {
            [imageView removeFromSuperview];
            [backgroundView addSubview:imageView];
        }
    }

    UIView *targetView = backgroundView ? backgroundView : superView;

    NSMutableArray<NSLayoutConstraint *> *constraints = [[NSMutableArray alloc] init];
    switch (backgroundImageProperties->GetFillMode()) {
        case ImageFillMode::Repeat: {
            [constraints addObjectsFromArray:@[
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeTop
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeTop
                                            multiplier:1.0
                                              constant:0],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeBottom
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeBottom
                                            multiplier:1.0
                                              constant:0],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeLeading
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeLeading
                                            multiplier:1.0
                                              constant:0],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeTrailing
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeTrailing
                                            multiplier:1.0
                                              constant:0]
            ]];

            imageView.contentMode = UIViewContentModeScaleAspectFill;
            break;
        }
        case ImageFillMode::RepeatHorizontally: {
            [constraints addObjectsFromArray:@[
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeHeight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1.0
                                              constant:image.size.height],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeLeading
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeLeading
                                            multiplier:1.0
                                              constant:0],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeTrailing
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeTrailing
                                            multiplier:1.0
                                              constant:0]
            ]];

            configVerticalAlignmentConstraintsForBackgroundImageView(backgroundImageProperties, superView, imageView, constraints);
            break;
        }
        case ImageFillMode::RepeatVertically: {
            [constraints addObjectsFromArray:@[
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1.0
                                              constant:image.size.width],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeTop
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeTop
                                            multiplier:1.0
                                              constant:0],
                [NSLayoutConstraint constraintWithItem:imageView
                                             attribute:NSLayoutAttributeBottom
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:targetView
                                             attribute:NSLayoutAttributeBottom
                                            multiplier:1.0
                                              constant:0]
            ]];
            configHorizontalAlignmentConstraintsForBackgroundImageView(backgroundImageProperties, targetView, imageView, constraints);
            break;
        }
        case ImageFillMode::Cover:
        default: {
            // we should not apply the constraints if the superView's frame is not ready
            // check layoutSubview of ACRContentStackView to see the alternate case
            if (superView.frame.size.width != 0 && superView.frame.size.height != 0) {
                renderBackgroundCoverMode(imageView, targetView, constraints, (ACRContentStackView *)superView);
            }

            configVerticalAlignmentConstraintsForBackgroundImageView(backgroundImageProperties, targetView, imageView, constraints);

            configHorizontalAlignmentConstraintsForBackgroundImageView(backgroundImageProperties, targetView, imageView, constraints);

            targetView.clipsToBounds = YES;
            break;
        }
    }
    [NSLayoutConstraint activateConstraints:constraints];
}

void configBleed(ACRView *rootView, std::shared_ptr<BaseCardElement> const &elem,
                 ACRContentStackView *container, ACOHostConfig *acoConfig)
{
    configBleed(rootView, elem, container, acoConfig, nil);
}

void configBleed(ACRView *rootView, std::shared_ptr<BaseCardElement> const &elem,
                 ACRContentStackView *container, ACOHostConfig *acoConfig, UIView<ACRIContentHoldingView> *superview)
{
    std::shared_ptr<StyledCollectionElement> collection =
        std::dynamic_pointer_cast<StyledCollectionElement>(elem);
    if (collection) {
        // check current collection type element has padding, if so added to the padding map
        [rootView updatePaddingMap:collection view:container];
        // bleed specification requires the object that's asked to be bled to have padding
        if (collection->GetPadding()) {
            std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
            // bleed specification requires that there should be at leat one parental object with
            // padding
            if (collection->GetCanBleed()) {
                InternalId parentInternalId = collection->GetParentalId();
                ACRContentStackView *parentView =
                    (ACRContentStackView *)[rootView getBleedTarget:parentInternalId];
                // c++ to object-c enum conversion
                ContainerBleedDirection adaptiveBleedDirection = collection->GetBleedDirection();
                ACRBleedDirection direction = (ACRBleedDirection)adaptiveBleedDirection;
                if (![parentView isKindOfClass:[ACRColumnSetView class]] || parentView != superview) {
                    parentView = nil;
                }

                // 1. create a background view (bv).
                // 2. bv is added to bleed target view (tv), which is also a parent view.
                // bv is then pinned to the tv according to the bleed direction
                // bv gets current container view's (cv) container style
                // and cv's container style is reset to transparent, such that
                // bv's container style will be diplayed.
                // container view's stack view (csv) holds content views, and bv dislpays
                // container style we transpose them, and get the final result

                UIView *backgroundView = [[UIView alloc] init];
                container.backgroundView = backgroundView;
                backgroundView.translatesAutoresizingMaskIntoConstraints = NO;

                [container addSubview:backgroundView];
                [container sendSubviewToBack:backgroundView];
                backgroundView.backgroundColor = container.backgroundColor;
                container.backgroundColor = UIColor.clearColor;

                [container bleed:config->GetSpacing().paddingSpacing
                        priority:1000
                          target:backgroundView
                       direction:direction
                      parentView:parentView];

                if ([container layer].borderWidth) {
                    [backgroundView layer].borderWidth = [container layer].borderWidth;
                    [container layer].borderWidth = 0;
                }

                if ([container layer].borderColor) {
                    [backgroundView layer].borderColor = [container layer].borderColor;
                    [container layer].borderColor = 0;
                }
                
                if ([container layer].cornerRadius) {
                    [backgroundView layer].cornerRadius = [container layer].cornerRadius;
                    [container layer].cornerRadius = 0;
                }
            }
        }
    }
}

ObserverActionBlock generateBackgroundImageObserverAction(
    std::shared_ptr<BackgroundImage> backgroundImageProperties, ACRView *observer,
    std::shared_ptr<BaseCardElement> const &context)
{
    return ^(NSObject<ACOIResourceResolver> *imageResourceResolver, NSString *key,
            __unused std::shared_ptr<BaseCardElement> const &elem, NSURL *url, ACRView *rootView) {
        UIImageView *view = [imageResourceResolver resolveImageViewResource:url];
        if (view) {
            // Use the new safe KVO method
            [observer startObserving:view
                             keyPath:@"image"
                             options:NSKeyValueObservingOptionNew
                             context:backgroundImageProperties.get()];

            // store the image view and column for easy retrieval in ACRView::observeValueForKeyPath
            [rootView setImageView:key view:view];
            [rootView setImageContext:key context:context];
        }
    };
}

void handleFallbackException(ACOFallbackException *exception, UIView<ACRIContentHoldingView> *view,
                             ACRView *rootView, NSMutableArray *inputs,
                             std::shared_ptr<BaseCardElement> const &givenElem,
                             ACOHostConfig *config,
                             bool canFallbackToAncestor)
{
    std::shared_ptr<BaseElement> fallbackBaseElement = nullptr;
    std::shared_ptr<BaseCardElement> elem = givenElem;
    FallbackType fallbackType = elem->GetFallbackType();
    bool bHandled = false;
    ACRRegistration *reg = [ACRRegistration getInstance];

    do {
        fallbackType = elem->GetFallbackType();
        if (fallbackType != FallbackType::Content) {
            break;
        }

        fallbackBaseElement = elem->GetFallbackContent();
        elem = std::static_pointer_cast<BaseCardElement>(fallbackBaseElement);
        if (!elem) {
            break;
        }

        ACOBaseCardElement *acoElem = [[ACOBaseCardElement alloc] init];
        [acoElem setElem:elem];

        ACRBaseCardElementRenderer *renderer =
            [reg getRenderer:[NSNumber numberWithInt:(int)elem->GetElementType()]];

        if (renderer) {
            @try {
                const CardElementType elemType = givenElem->GetElementType();
                removeLastViewFromCollectionView(elemType, view);
                [renderer render:view
                           rootView:rootView
                             inputs:inputs
                    baseCardElement:acoElem
                         hostConfig:config];
                bHandled = true;
            } @catch (ACOFallbackException *e) {
                NSLog(@"Fallback Failed, trying different fallback");
                NSLog(@"%@", e);
            }
        }

    } while (!bHandled);

    if (!bHandled) {
        if (canFallbackToAncestor && fallbackType != FallbackType::Drop) {
            @throw exception;
        } else {
            const CardElementType elemType = givenElem->GetElementType();
            removeLastViewFromCollectionView(elemType, view);
        }
    }
}

bool handleRootFallback(std::shared_ptr<AdaptiveCard> const &adaptiveCard,
                        UIView<ACRIContentHoldingView> *view,
                             ACRView *rootView, NSMutableArray *inputs,
                             ACOHostConfig *config)
{
    FallbackType fallbackType = adaptiveCard->GetRootFallbackType();
    std::shared_ptr<BaseElement> fallbackBaseElement = adaptiveCard->GetRootFallbackContent();
    std::shared_ptr<BaseCardElement> elem = std::static_pointer_cast<BaseCardElement>(fallbackBaseElement);
    ACRRegistration *reg = [ACRRegistration getInstance];
    
    if (fallbackType != FallbackType::Content || !elem)
    {
        return false;
    }
    
    ACOBaseCardElement *acoElem = [[ACOBaseCardElement alloc] init];
    [acoElem setElem:elem];

    ACRBaseCardElementRenderer *renderer =
        [reg getRenderer:[NSNumber numberWithInt:(int)elem->GetElementType()]];
    
    if (renderer) {
        @try {
            
            UIView* renderedView = [renderer render:view
                                           rootView:rootView
                                             inputs:inputs
                                    baseCardElement:acoElem
                                         hostConfig:config];
            [view removeAllArrangedSubviews];
            [view insertArrangedSubview:renderedView atIndex:0];
            
            return true;
            
        } @catch (ACOFallbackException *e) {
            NSLog(@"Root Fallback Failed");
            NSLog(@"%@", e);
        }
    }
    return false;
}

void removeLastViewFromCollectionView(const CardElementType elemType,
                                      UIView<ACRIContentHoldingView> *view)
{
    if (elemType == CardElementType::Container || elemType == CardElementType::Column ||
        elemType == CardElementType::ColumnSet) {
        [view removeLastViewFromArrangedSubview];
    }
}

void handleActionFallbackException(ACOFallbackException *exception,
                                   UIView<ACRIContentHoldingView> *view, ACRView *rootView,
                                   NSMutableArray *inputs, ACOBaseActionElement *acoElem,
                                   ACOHostConfig *config,
                                   UIStackView *actionSet)
{
    std::shared_ptr<BaseElement> fallbackBaseElement = nullptr;
    std::shared_ptr<BaseActionElement> elem = acoElem.element;
    bool bCanFallbackToAncestor = elem->CanFallbackToAncestor();
    FallbackType fallbackType = elem->GetFallbackType();
    bool bHandled = false;
    ACRRegistration *reg = [ACRRegistration getInstance];

    do {
        fallbackType = elem->GetFallbackType();
        if (fallbackType != FallbackType::Content) {
            break;
        }

        fallbackBaseElement = elem->GetFallbackContent();
        elem = std::static_pointer_cast<BaseActionElement>(fallbackBaseElement);
        if (!elem) {
            break;
        }

        ACOBaseActionElement *actionElement =
            [[ACOBaseActionElement alloc] initWithBaseActionElement:elem];

        ACRBaseActionElementRenderer *renderer =
            [reg getActionRenderer:[NSNumber numberWithInt:(int)elem->GetElementType()]];

        if (renderer) {
            @try {
                UIButton *button = [renderer renderButton:rootView
                                                   inputs:inputs
                                                superview:view
                                        baseActionElement:actionElement
                                               hostConfig:config];
                [actionSet addArrangedSubview:button];
                bHandled = true;
            } @catch (ACOFallbackException *e) {
                NSLog(@"Fallabck Failed, trying different fallback");
                NSLog(@"%@", e);
            }
        }

    } while (!bHandled);

    if (!bHandled) {
        if (bCanFallbackToAncestor && fallbackType != FallbackType::Drop) {
            @throw exception;
        }
    }
}

UIFontDescriptor *getItalicFontDescriptor(UIFontDescriptor *descriptor, bool isItalic)
{
    if (isItalic && descriptor) {
        return [descriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    }

    return descriptor;
}

ACRRenderingStatus buildTargetForButton(ACRTargetBuilderDirector *director,
                                        ACOBaseActionElement *action,
                                        UIButton *button, NSObject **target)
{
    *target = [director build:action forButton:button];
    if (action.tooltip && target) {
        [((ACRBaseTarget *)*target) addGestureRecognizer:button toolTipText:action.tooltip];
    }
    return *target ? ACRRenderingStatus::ACROk : ACRRenderingStatus::ACRFailed;
}

ACRRenderingStatus buildTarget(ACRTargetBuilderDirector *director,
                               ACOBaseActionElement *action,
                               NSObject **target)
{
    *target = [director build:action];
    return *target ? ACRRenderingStatus::ACROk : ACRRenderingStatus::ACRFailed;
}

void setAccessibilityTrait(UIView *recipientView, ACOBaseActionElement *action)
{
    recipientView.userInteractionEnabled = [action isEnabled];
    recipientView.accessibilityTraits |= action.accessibilityTraits;
    if (![action isEnabled]) {
        recipientView.accessibilityTraits |= UIAccessibilityTraitNotEnabled;
    }
}

NSString *configureForAccessibilityLabel(ACOBaseActionElement *action, NSString *contentString)
{
    NSMutableArray<NSString *> *accessibilityLabels = [[NSMutableArray alloc] init];
    if (action.title) {
        [accessibilityLabels addObject:action.title];
    } else {
        if (contentString) {
            [accessibilityLabels addObject:contentString];
        }
    }

    if (action.tooltip) {
        [accessibilityLabels addObject:action.tooltip];
    }

    return [accessibilityLabels componentsJoinedByString:@", "];
}

UIFont *getFont(ACOHostConfig *hostConfig, const AdaptiveCards::RichTextElementProperties &textProperties)
{
    FontType sharedFontType = textProperties.GetFontType().value_or(FontType::Default);
    TextWeight sharedTextWeight = textProperties.GetTextWeight().value_or(TextWeight::Default);
    TextSize sharedTextSize = textProperties.GetTextSize().value_or(TextSize::Default);

    int fontweight = [hostConfig getTextBlockFontWeight:sharedFontType
                                             textWeight:sharedTextWeight];
    // sanity check, 400 is the normal font;
    if (fontweight <= 0 || fontweight > 900) {
        fontweight = 400;
    }
    UIFont *font = nil;
    fontweight -= 100;
    fontweight /= 100;

    if (![hostConfig getFontFamily:sharedFontType]) {
        const NSArray<NSNumber *> *fontweights = @[ @(UIFontWeightUltraLight), @(UIFontWeightThin), @(UIFontWeightLight), @(UIFontWeightRegular), @(UIFontWeightMedium),
                                                    @(UIFontWeightSemibold), @(UIFontWeightBold), @(UIFontWeightHeavy), @(UIFontWeightBlack) ];
        const CGFloat size = [hostConfig getTextBlockTextSize:sharedFontType textSize:sharedTextSize];
        if (textProperties.GetFontType() == FontType::Monospace) {
            const NSArray<NSString *> *weights = @[ @"UltraLight", @"Thin", @"Light", @"Regular",
                                                        @"Medium", @"Semibold", @"Bold", @"Heavy", @"Black" ];
            UIFontDescriptor *descriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:@{UIFontDescriptorFamilyAttribute : @"Courier New",
                                                                                                UIFontDescriptorFaceAttribute : weights[fontweight]}];
            descriptor = getItalicFontDescriptor(descriptor, textProperties.GetItalic());

            font = [UIFont fontWithDescriptor:descriptor size:[hostConfig getTextBlockTextSize:sharedFontType textSize:sharedTextSize]];
        } else {
            font = [UIFont systemFontOfSize:size weight:[fontweights[fontweight] floatValue]];

            if (textProperties.GetItalic()) {
                font = [UIFont fontWithDescriptor:
                                   getItalicFontDescriptor(font.fontDescriptor, textProperties.GetItalic())
                                             size:size];
            }
        }
    } else {
        // font weight as string since font weight as double doesn't work
        // normailze fontweight for indexing
        const NSArray<NSString *> *fontweights = @[ @"UltraLight", @"Thin", @"Light", @"Regular",
                                                    @"Medium", @"Semibold", @"Bold", @"Heavy", @"Black" ];
        UIFontDescriptor *descriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:
                                                             @{UIFontDescriptorFamilyAttribute : [hostConfig getFontFamily:sharedFontType],
                                                               UIFontDescriptorFaceAttribute : fontweights[fontweight]}];

        descriptor = getItalicFontDescriptor(descriptor, textProperties.GetItalic());

        font = [UIFont fontWithDescriptor:descriptor size:[hostConfig getTextBlockTextSize:sharedFontType textSize:sharedTextSize]];
    }

    // Guard against nil font — fontWithDescriptor:size: returns nil when the
    // host config specifies a font family/face not available on the device.
    // Fall back to the system font at the requested size.
    if (!font) {
        font = [UIFont systemFontOfSize:[hostConfig getTextBlockTextSize:sharedFontType textSize:sharedTextSize]];
    }
    return [UIFontMetrics.defaultMetrics scaledFontForFont:font];
}

void buildIntermediateResultForText(ACRView *rootView, ACOHostConfig *hostConfig, RichTextElementProperties const &textProperties, NSString *elementId)
{
    std::shared_ptr<MarkDownParser> markDownParser = std::make_shared<MarkDownParser>([ACOHostConfig getLocalizedDate:textProperties.GetText() language:textProperties.GetLanguage()]);

    std::string markdownString;
    
    NSString *markDownParserString = [NSString stringWithCString:markDownParser->GetRawText().c_str() encoding:NSUTF8StringEncoding];
    
    // This validation prevents to detect the dot and space ". " of hungarian date as a list of elements in parsing
    if (matchHungarianDateRegex(markDownParserString))
    {
        markdownString = std::string([[NSString stringWithFormat:@"<p>%@</p>", markDownParserString] UTF8String]);
    }
    else
    {
        // MarkDownParser transforms text with MarkDown to a html string
        markdownString = markDownParser->TransformToHtml();
    }
    NSString *parsedString = (markDownParser->HasHtmlTags()) ? [NSString stringWithCString:markdownString.c_str() encoding:NSUTF8StringEncoding] : [NSString stringWithCString:markDownParser->GetRawText().c_str() encoding:NSUTF8StringEncoding];

    // Convert <ul>/<li> to literal "• " bullets and <br> separators.
    // Apple's NSHTMLTextDocumentType renders list bullets via NSTextList in the
    // paragraph style, which is overwritten downstream in ACRTextBlockRenderer
    // when alignment is applied — wiping out the bullet markers. Mirroring the
    // Android renderer (RendererUtil.UlTagHandler) by injecting bullets as text
    // makes the marker survive any paragraph-style changes.
    if (markDownParser->HasHtmlTags() && [parsedString containsString:@"<li>"]) {
        // Strip the list containers, then rewrite each well-formed <li>…</li>
        // pair into a "• " line ending in <br>. Matching the pair with one
        // regex avoids leaking a half-formed bullet from a stray <li> or </li>.
        NSRegularExpression *ulRegex =
            [NSRegularExpression regularExpressionWithPattern:@"<ul>(.*?)</ul>"
                                                      options:NSRegularExpressionDotMatchesLineSeparators
                                                        error:nil];
        parsedString = [ulRegex stringByReplacingMatchesInString:parsedString
                                                         options:0
                                                           range:NSMakeRange(0, parsedString.length)
                                                    withTemplate:@"$1"];

        NSRegularExpression *liRegex =
            [NSRegularExpression regularExpressionWithPattern:@"<li>(.*?)</li>"
                                                      options:NSRegularExpressionDotMatchesLineSeparators
                                                        error:nil];
        parsedString = [liRegex stringByReplacingMatchesInString:parsedString
                                                         options:0
                                                           range:NSMakeRange(0, parsedString.length)
                                                    withTemplate:@"• $1<br>"];
    }

    if (markDownParser->HasHtmlTags() && ([parsedString containsString:@"\n"] || [parsedString containsString:@"\r"])) {
        // Different systems have different line break styles
        // Windows style: \r\n
        // Modern mac style: \n
        // Old mac style: \r
        NSString *replacementPattern = [parsedString containsString:@"\r\n"] ? @"\r\n" : @"[\\n\\r]";
        parsedString = [parsedString stringByReplacingOccurrencesOfString:replacementPattern
                                                               withString:@"<br>"
                                                                  options:NSRegularExpressionSearch
                                                                    range:NSMakeRange(0, [parsedString length])];
    }
    // Added manual replace of \\* when the text is used directly, html parsing is exluding this case successfully
    if (!markDownParser->HasHtmlTags())
    {
        NSSet* symbolsToRemove = [NSSet setWithObjects:@"*", @"_", nil];
        parsedString = stringWithRemovedBackslashedSymbols(parsedString, symbolsToRemove);
    }
    
    NSDictionary *data = nil;

    FontType sharedFontType = textProperties.GetFontType().value_or(FontType::Default);
    TextWeight sharedTextWeight = textProperties.GetTextWeight().value_or(TextWeight::Default);
    TextSize sharedTextSize = textProperties.GetTextSize().value_or(TextSize::Default);

    // use Apple's html rendering only if the string has markdowns
    if (markDownParser->HasHtmlTags()) {
        NSString *fontFamilyName = nil;

        if (![hostConfig getFontFamily:sharedFontType]) {
            if (sharedFontType == FontType::Monospace) {
                fontFamilyName = @"'Courier New'";
            } else {
                fontFamilyName = @"'-apple-system',  'San Francisco'";
            }
        } else {
            fontFamilyName = [hostConfig getFontFamily:sharedFontType];
        }

        NSString *font_style = textProperties.GetItalic() ? @"italic" : @"normal";
        // Font and text size are applied as CSS style by appending it to the html string
        parsedString = [parsedString stringByAppendingString:[NSString stringWithFormat:@"<style>body{font-family: %@; font-size:%dpx; font-weight: %d; font-style: %@;}</style>",
                                                                                        fontFamilyName,
                                                                                        [hostConfig getTextBlockTextSize:sharedFontType
                                                                                                                textSize:sharedTextSize],
                                                                                        [hostConfig getTextBlockFontWeight:sharedFontType
                                                                                                                textWeight:sharedTextWeight],
                                                                                        font_style]];

        NSData *htmlData = [parsedString dataUsingEncoding:NSUTF16StringEncoding];
        NSDictionary *options = @{NSDocumentTypeDocumentAttribute : NSHTMLTextDocumentType};
        data = @{@"html" : htmlData, @"options" : options};
    } else {
        UIFont *font = getFont(hostConfig, textProperties);

        NSDictionary *attributeDictionary = @{NSFontAttributeName : font};
        data = @{@"nonhtml" : parsedString, @"descriptor" : attributeDictionary};
    }

    if (elementId) {
        [rootView enqueueIntermediateTextProcessingResult:data
                                                elementId:elementId];
    }
}

void UpdateFontWithDynamicType(NSMutableAttributedString *content)
{
    [content enumerateAttribute:NSFontAttributeName
                        inRange:NSMakeRange(0, content.length)
                        options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                     usingBlock:^(id value, NSRange range, __unused BOOL *stop) {
                         [content addAttribute:NSFontAttributeName value:[UIFontMetrics.defaultMetrics scaledFontForFont:(UIFont *)value] range:range];
                     }];
}

unsigned int getIconSize(IconSize iconSize)
{
    unsigned int _size = 24;
    switch (iconSize)
    {
        case IconSize::xxSmall:
            _size = 16;
            break;
        case IconSize::xSmall:
            _size = 20;
            break;
        case IconSize::Small:
            _size = 24;
            break;
        case IconSize::Standard:
            _size = 32;
            break;
        case IconSize::Medium:
            _size = 48;
            break;
        case IconSize::Large:
            _size = 56;
            break;
        case IconSize::xLarge:
            _size = 72;
            break;
        case IconSize::xxLarge:
            _size = 96;
            break;
    }
    return _size;
}

void TexStylesToRichTextElementProperties(const std::shared_ptr<TextBlock> &textBlock,
                                          const TextStyleConfig &textStyleConfig,
                                          RichTextElementProperties &textProp)
{
    textProp.SetText(textBlock->GetText());
    textProp.SetLanguage(textBlock->GetLanguage());
    textProp.SetTextSize(textBlock->GetTextSize().value_or(textStyleConfig.size));
    textProp.SetTextWeight(textBlock->GetTextWeight().value_or(textStyleConfig.weight));
    textProp.SetFontType(textBlock->GetFontType().value_or(textStyleConfig.fontType));
    textProp.SetTextColor(textBlock->GetTextColor().value_or(textStyleConfig.color));
    textProp.SetIsSubtle(textBlock->GetIsSubtle().value_or(textStyleConfig.isSubtle));
}

void TextRunToRichTextElementProperties(const std::shared_ptr<TextRun> &textRun, RichTextElementProperties &textProp)
{
    textProp.SetText(textRun->GetText());
    textProp.SetTextSize(textRun->GetTextSize());
    textProp.SetTextWeight(textRun->GetTextWeight());
    textProp.SetFontType(textRun->GetFontType());
    textProp.SetTextColor(textRun->GetTextColor());
    textProp.SetIsSubtle(textRun->GetIsSubtle());
    textProp.SetLanguage(textRun->GetLanguage());
    textProp.SetItalic(textRun->GetItalic());
    textProp.SetStrikethrough(textRun->GetStrikethrough());
}

ACOBaseActionElement *deserializeUnknownActionToCustomAction(const std::shared_ptr<UnknownAction> unknownAction)
{
    ACRRegistration *reg = [ACRRegistration getInstance];
    ACOBaseActionElement *customAction = nil;
    if (reg) {
        NSString *type = [NSString stringWithCString:unknownAction->GetElementTypeString().c_str() encoding:NSUTF8StringEncoding];
        NSObject<ACOIBaseActionElementParser> *parser = [reg getCustomActionElementParser:type];
        if (!parser) {
            @throw [ACOFallbackException fallbackException];
        }
        Json::Value blob = unknownAction->GetAdditionalProperties();
        Json::StreamWriterBuilder streamWriterBuilder;
        auto writer = streamWriterBuilder.newStreamWriter();
        std::stringstream sstream;
        writer->write(blob, &sstream);
        delete writer;
        NSString *jsonString =
            [[NSString alloc] initWithCString:sstream.str().c_str()
                                     encoding:NSUTF8StringEncoding];
        if (jsonString.length > 0) {
            NSData *jsonPayload = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            ACOParseContext *context = [reg getParseContext];
            customAction = [parser deserialize:jsonPayload parseContext:context];
        }
    }
    return customAction;
}

UIColor *getForegroundUIColorFromAdaptiveAttribute(std::shared_ptr<HostConfig> const &config, ACRContainerStyle style, ForegroundColor textColor, bool isSubtle)
{
    const std::string str = config->GetForegroundColor([ACOHostConfig getSharedContainerStyle:style], textColor, isSubtle);
    return [ACOHostConfig convertHexColorCodeToUIColor:str];
}

unsigned int getSpacing(Spacing spacing, std::shared_ptr<HostConfig> const &config)
{
    switch (spacing) {
        case Spacing::ExtraLarge:
            return config->GetSpacing().extraLargeSpacing;
        case Spacing::Large:
            return config->GetSpacing().largeSpacing;
        case Spacing::Medium:
            return config->GetSpacing().mediumSpacing;
        case Spacing::Small:
            return config->GetSpacing().smallSpacing;
        case Spacing::Padding:
            return config->GetSpacing().paddingSpacing;
        case Spacing::Default:
            return config->GetSpacing().defaultSpacing;
        case Spacing::ExtraSmall:
            return config->GetSpacing().extraSmallSpacing;
        default:
            break;
    }

    return 0;
}

void configVerticalAlignmentConstraintsForBackgroundImageView(const BackgroundImage *backgroundImageProperties, UIView *superView, UIImageView *imageView, NSMutableArray<NSLayoutConstraint *> *constraints)
{
    if (!backgroundImageProperties || !superView || !imageView) {
        return;
    }

    switch (backgroundImageProperties->GetVerticalAlignment()) {
        case VerticalAlignment::Bottom:
            [constraints addObject:[imageView.bottomAnchor constraintEqualToAnchor:superView.bottomAnchor]];
            break;
        case VerticalAlignment::Center:
            [constraints addObject:[imageView.centerYAnchor constraintEqualToAnchor:superView.centerYAnchor]];
            break;
        case VerticalAlignment::Top:
        default:
            [constraints addObject:[imageView.topAnchor constraintEqualToAnchor:superView.topAnchor]];
            break;
    }
}

void configHorizontalAlignmentConstraintsForBackgroundImageView(const BackgroundImage *backgroundImageProperties, UIView *superView, UIImageView *imageView, NSMutableArray<NSLayoutConstraint *> *constraints)
{
    if (!backgroundImageProperties || !superView || !imageView) {
        return;
    }

    switch (backgroundImageProperties->GetHorizontalAlignment()) {
        case HorizontalAlignment::Right:
            [constraints addObject:[imageView.trailingAnchor constraintEqualToAnchor:superView.trailingAnchor]];
            break;
        case HorizontalAlignment::Center:
            [constraints addObject:[imageView.centerXAnchor constraintEqualToAnchor:superView.centerXAnchor]];
            break;
        case HorizontalAlignment::Left:
        default:
            [constraints addObject:[imageView.leadingAnchor constraintEqualToAnchor:superView.leadingAnchor]];
            break;
    }
}

NSMutableAttributedString *initAttributedText(ACOHostConfig *acoConfig, const std::string &text, const AdaptiveCards::RichTextElementProperties &textElementProperties, ACRContainerStyle style)
{
    UIFont *font = getFont(acoConfig, textElementProperties);
    auto foregroundColor = [acoConfig getTextBlockColor:style textColor:textElementProperties.GetTextColor().value_or(ForegroundColor::Default) subtleOption:NO];

    return [[NSMutableAttributedString alloc] initWithString:[NSString stringWithCString:text.c_str() encoding:NSUTF8StringEncoding] attributes:@{NSFontAttributeName : font, NSForegroundColorAttributeName : foregroundColor}];
}

NSString *makeKeyForImage(ACOHostConfig *acoConfig, NSString *keyType, NSDictionary<NSString *, NSString *> *pieces)
{
    ACOResolverIFType resolverType = ACODefaultIF;
    NSString *urlString = pieces[@"url"], *key = urlString;
    NSURL *url = nil;

    if (urlString) {
        url = [NSURL URLWithString:urlString];
        resolverType = [acoConfig getResolverIFType:[url scheme]];
    }

    if ([keyType isEqualToString:@"image"] || [keyType isEqualToString:@"media-poster"]) {
        if (ACOImageViewIF == resolverType) {
            key = pieces[@"number"];
        }
    } else if ([keyType isEqualToString:@"media-playicon-image"]) {
        key = (ACOImageViewIF == resolverType) ? pieces[@"playicon-url-viewIF"] : pieces[@"playicon-url"];
    } else if ([keyType isEqualToString:@"media-playicon-imageView"]) {
        key = (ACOImageViewIF == resolverType) ? pieces[@"playicon-url-imageView-viewIF"] : pieces[@"playicon-url-imageView"];
    }
    return key;
}

ACRImageSize getACRImageSize(ImageSize adaptiveImageSize, BOOL hasExplicitDimensions)
{
    if (hasExplicitDimensions) {
        return ACRImageSizeExplicit;
    }

    switch (adaptiveImageSize) {
        case ImageSize::None:
            return ACRImageSizeNone;
        case ImageSize::Auto:
            return ACRImageSizeAuto;
        case ImageSize::Stretch:
            return ACRImageSizeStretch;
        case ImageSize::Small:
            return ACRImageSizeSmall;
        case ImageSize::Medium:
            return ACRImageSizeMedium;
        case ImageSize::Large:
            return ACRImageSizeLarge;
        default:
            return ACRImageSizeAuto;
    }
}

ACRHorizontalAlignment getACRHorizontalAlignment(HorizontalAlignment horizontalAlignment)
{
    switch (horizontalAlignment) {
        case HorizontalAlignment::Left:
            return ACRLeft;
        case HorizontalAlignment::Center:
            return ACRCenter;
        case HorizontalAlignment::Right:
            return ACRRight;
        default:
            return ACRLeft;
    }
}

ACRImageFitMode getACRImageFitMode(ImageFitMode fitMode)
{
    switch (fitMode) {
        case ImageFitMode::Fill:
            return ACRImageFitModeFill;
        case ImageFitMode::Contain:
            return ACRImageFitModeContain;
        case ImageFitMode::Cover:
            return ACRImageFitModeCover;
    }
}

ACRHorizontalContentAlignment getACRHorizontalContentAlignment(HorizontalContentAlignment horizontalContentAlignment)
{
    switch (horizontalContentAlignment) {
        case HorizontalContentAlignment::Left:
            return ACRHorizontalContentAlignmentLeft;
        case HorizontalContentAlignment::Right:
            return ACRHorizontalContentAlignmentRight;
        case HorizontalContentAlignment::Center:
            return ACRHorizontalContentAlignmentCenter;
    }
}

ACRVerticalContentAlignment getACRVerticalContentAlignment(VerticalContentAlignment verticalContentAlignment)
{
    switch (verticalContentAlignment) {
        case VerticalContentAlignment::Top:
            return ACRVerticalContentAlignmentTop;
        case VerticalContentAlignment::Bottom:
            return ACRVerticalContentAlignmentBottom;
        case VerticalContentAlignment::Center:
            return ACRVerticalContentAlignmentCenter;
    }
}

ACRRatingSize getRatingSize(RatingSize ratingSize)
{
    switch (ratingSize) {
        case RatingSize::Medium:
            return ACRMedium;
        case RatingSize::Large:
            return ACRLarge;
        default:
            return ACRMedium;
    }
}

ACRRatingColor getRatingColor(RatingColor ratingColor)
{
    switch (ratingColor) {
        case RatingColor::Neutral:
            return ACRNeutral;
        case RatingColor::Marigold:
            return ACRMarigold;
        default:
            return ACRNeutral;
    }
}

ACRRatingStyle getRatingStyle(RatingStyle ratingStyle)
{
    switch (ratingStyle) {
        case RatingStyle::Default:
            return ACRDefaultStyle;
        case RatingStyle::Compact:
            return ACRCompactStyle;
        default:
            return ACRDefaultStyle;
    }
}

ACRIconPosition getIconPosition(IconPosition iconPosition)
{
    switch (iconPosition) {
        case IconPosition::Before:
            return ACRBeforePosition;
        case IconPosition::After:
            return ACRAfterPosition;
        default:
            return ACRBeforePosition;
    }
}

ACRShape getShape(Shape shape)
{
    switch (shape) {
        case Shape::Square:
            return ACRSquare;
        case Shape::Rounded:
            return ACRRounded;
        case Shape::Circular:
            return ACRCircular;
        default:
            return ACRSquare;
    }
}

ACRBadgeStyle getBadgeStyle(BadgeStyle badgeStyle)
{
    switch (badgeStyle) {
        case BadgeStyle::Default:
            return ACRBadgeDefaultStyle;
        case BadgeStyle::Accent:
            return ACRBadgeAccentStyle;
        case BadgeStyle::Attention:
            return ACRBadgeAttentionStyle;
        case BadgeStyle::Good:
            return ACRBadgeGoodStyle;
        case BadgeStyle::Informative:
            return ACRBadgeInformativeStyle;
        case BadgeStyle::Subtle:
            return ACRBadgeSubtleStyle;
        case BadgeStyle::Warning:
            return ACRBadgeWarningStyle;
        default:
            return ACRBadgeDefaultStyle;
    }
}

ACRBadgeSize getBadgeSize(BadgeSize badgeSize)
{
    switch (badgeSize) {
        case BadgeSize::Medium:
            return ACRMediumSize;
        case BadgeSize::Large:
            return ACRLargeSize;
        case BadgeSize::ExtraLarge:
            return ACRExtraLargeSize;
        default:
            return ACRMediumSize;
    }
}

ACRBadgeAppearance getBadgeAppearance(BadgeAppearance badgeAppearance)
{
    switch (badgeAppearance) {
        case BadgeAppearance::Filled:
            return ACRFilled;
        case BadgeAppearance::Tint:
            return ACRTint;
        default:
            return ACRFilled;
    }
}

ACRHeightType GetACRHeight(HeightType adaptiveHeight)
{
    ACRHeightType height = ACRHeightAuto;
    switch (adaptiveHeight) {
        case AdaptiveCards::HeightType::Auto:
            height = ACRHeightAuto;
            break;
        case AdaptiveCards::HeightType::Stretch:
            height = ACRHeightStretch;
            break;
    }
    return height;
}

ACRVerticalContentAlignment GetACRVerticalContentAlignment(VerticalContentAlignment adaptiveVerticalContentAlignment)
{
    ACRVerticalContentAlignment contentAlignment = ACRVerticalContentAlignmentTop;
    switch (adaptiveVerticalContentAlignment) {
        case AdaptiveCards::VerticalContentAlignment::Top:
            contentAlignment = ACRVerticalContentAlignmentTop;
            break;
        case AdaptiveCards::VerticalContentAlignment::Center:
            contentAlignment = ACRVerticalContentAlignmentCenter;
            break;
        case AdaptiveCards::VerticalContentAlignment::Bottom:
            contentAlignment = ACRVerticalContentAlignmentBottom;
            break;
    }
    return contentAlignment;
}

void printSize(NSString *msg, CGSize size)
{
    NSLog(@"%@, size = %f x %f", msg, size.width, size.height);
}

NSData *JsonToNSData(const Json::Value &blob)
{
    Json::StreamWriterBuilder streamWriterBuilder;
    std::unique_ptr<Json::StreamWriter> writer(streamWriterBuilder.newStreamWriter());
    std::stringstream sstream;
    writer->write(blob, &sstream);
    NSString *jsonString =
        [[NSString alloc] initWithCString:sstream.str().c_str()
                                 encoding:NSUTF8StringEncoding];
    return (jsonString.length > 0) ? [jsonString dataUsingEncoding:NSUTF8StringEncoding] : nil;
}

void partitionActions(
    const std::vector<std::shared_ptr<BaseActionElement>> &elems,
    std::vector<std::shared_ptr<BaseActionElement>> &primary,
    std::vector<std::shared_ptr<BaseActionElement>> &secondary,
    unsigned int maxActions,
    ACRView *rootView)
{
    std::partition_copy(std::begin(elems),
                        std::end(elems),
                        std::inserter(secondary, std::end(secondary)),
                        std::inserter(primary, std::end(primary)),
                        [](std::shared_ptr<BaseActionElement> elem) {
                            return elem->GetMode() == Mode::Secondary;
                        });

    unsigned long uMaxActionsToRender = MIN(maxActions, primary.size());

    BOOL allowMoreThanMaxActionsInOverflowMenu = NO;
    if ([rootView.acrActionDelegate respondsToSelector:@selector(shouldAllowMoreThanMaxActionsInOverflowMenu)]) {
        allowMoreThanMaxActionsInOverflowMenu =
            [rootView.acrActionDelegate shouldAllowMoreThanMaxActionsInOverflowMenu];
    }

    if (uMaxActionsToRender < primary.size()) {
        auto start = std::begin(primary) + uMaxActionsToRender;
        auto end = std::end(primary);

        if (allowMoreThanMaxActionsInOverflowMenu) {
            std::copy(start, end, std::back_inserter(secondary));
        } else {
            [rootView addWarnings:ACRWarningStatusCode::ACRMaxActionsExceeded
                           mesage:@"Some actions were not rendered due to exceeding the maximum number "
                                  @"of actions allowed"];
        }

        primary.erase(start, end);
    }
}

UIImage *scaleImageToSize(UIImage *image, CGSize newSize)
{
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

NSNumber *iOSInternalIdHash(const std::size_t internalIdHash)
{
    return [NSNumber numberWithLong:internalIdHash];
}

id traverseResponderChainForUIViewController(UIView *view)
{
    id nextResponder = [view nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return traverseResponderChainForUIViewController((UIView *)nextResponder);
    } else {
        return nil;
    }
}

/// returns CGRect that covers target rect while maintaining the aspect ratio of coverRect
CGRect FindClosestRectToCover(CGRect coverRect, CGRect targetRectToCover)
{
    // do binary search upto the tolerance value
    CGFloat scalerLowBound = 0.0f, scalerHighBound = 1.0f, scalerMidPoint = 0.0f;
    while (abs(scalerLowBound - scalerHighBound) > kACRScalerTolerance) {
        scalerMidPoint = (scalerLowBound + scalerHighBound) / 2.0f;
        CGFloat scaledWidth = coverRect.size.width * scalerMidPoint;
        CGFloat scaledHeight = coverRect.size.height * scalerMidPoint;
        if (scaledWidth > targetRectToCover.size.width && scaledHeight > targetRectToCover.size.height) {
            scalerHighBound = scalerMidPoint;
        } else {
            scalerLowBound = scalerMidPoint;
        }
    }

    if (coverRect.size.width * scalerMidPoint < targetRectToCover.size.width ||
        coverRect.size.height * scalerMidPoint < targetRectToCover.size.height) {
        scalerMidPoint = scalerHighBound;
    }

    return CGRectMake(0, 0, coverRect.size.width * scalerMidPoint, coverRect.size.height * scalerMidPoint);
}

void addSelectActionToView(ACOHostConfig *acoConfig, ACOBaseActionElement *acoSelectAction, ACRView *rootView, UIView *view, UIView<ACRIContentHoldingView> *viewGroup)
{
    ACRBaseTarget *target = [ACRTapGestureRecognizerFactory addTapGestureRecognizerToUIView:viewGroup
                                                                                   rootView:rootView
                                                                              recipientView:view
                                                                              actionElement:acoSelectAction
                                                                                 hostConfig:acoConfig];
    if (target && acoSelectAction.inlineTooltip) {
        [target addGestureRecognizer:view toolTipText:acoSelectAction.inlineTooltip];
    }
}

HostWidth convertHostCardContainerToHostWidth(int hostCardContainer, HostWidthConfig& hostWidthConfig)
{
    if (hostCardContainer <= 0 || hostWidthConfig.veryNarrow == 0 || hostWidthConfig.narrow == 0 || hostWidthConfig.standard == 0)
    {
        return HostWidth::Default;
    }

    HostWidth hostWidth;

    if (hostCardContainer <= (int)hostWidthConfig.veryNarrow) {
        hostWidth = HostWidth::VeryNarrow;
    } else if (hostCardContainer > (int)hostWidthConfig.veryNarrow && hostCardContainer <= (int)hostWidthConfig.narrow) {
        hostWidth = HostWidth::Narrow;
    } else if (hostCardContainer > (int)hostWidthConfig.narrow && hostCardContainer <= (int)hostWidthConfig.standard) {
        hostWidth = HostWidth::Standard;
    } else {
        hostWidth = HostWidth::Wide;
    }

    return hostWidth;
}

// Validate date of type "YYYY. MM. DD. HH:MM AM|PM" to prevent parsing issues
bool matchHungarianDateRegex(NSString *stringToValidate)
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[0-9]{4}. [0-9]{2}. [0-9]{2}. [0-9]{2}:[0-9]{2} [AM|PM]" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:stringToValidate options:0 range:NSMakeRange(0, [stringToValidate length])];
    // Only true if exists a match and is the complete string
    return match != nil && stringToValidate.length == (match.range.length + 1);
}

NSString* stringWithRemovedBackslashedSymbols(NSString *stringToRemoveSymbols, NSSet<NSString *> *symbolsSet)
{
    NSString* tempString = stringToRemoveSymbols;
    for (NSString* symbol in symbolsSet)
    {
        tempString = [tempString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\\%@", symbol]
                                                           withString:symbol];
    }
    return tempString;
}

BOOL isNullOrEmpty(NSString *string) {
    if (string) {
        NSRange range = [string rangeOfString:string];
        BOOL isEmpty = (range.length <= 0 || [string isEqualToString:@" "]);
        BOOL isNull = string == (id)[NSNull null];
        return (isNull || isEmpty);
    }
    return YES;
}

NSString *stringForCString(const std::optional<std::string> cString)
{
    if (!cString.has_value())
    {
        return @"";
    }
    
    const char* cStr = cString->c_str();
    if (!cStr)
    {
        return @"";
    }
    
    return [NSString stringWithCString:cStr encoding:NSUTF8StringEncoding];
}

NSString *cdnURLForIcon(NSString *iconPath)
{
    NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
    NSString const *CDNPath = [featureFlagResolver stringForFlag:@"fluentIconCdnURL"] ?: baseFluentIconCDNURL;
    return [[NSString alloc] initWithFormat:@"%@%@",CDNPath, iconPath];
}

std::string GetDeviceLanguageLocale()
{
    @autoreleasepool {
        NSString *languageID = [[NSLocale preferredLanguages] firstObject];
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:languageID];
        NSString *languageCode = [locale objectForKey:NSLocaleLanguageCode];
        NSString *regionCode   = [locale objectForKey:NSLocaleCountryCode];
        NSString *formatted = regionCode ? [NSString stringWithFormat:@"%@-%@", [languageCode lowercaseString], [regionCode uppercaseString]] : [languageCode lowercaseString];

        return [formatted UTF8String];
    }
}
