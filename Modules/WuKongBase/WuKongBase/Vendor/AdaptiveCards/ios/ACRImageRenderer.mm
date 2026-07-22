//
//  ACRImageRenderer
//  ACRImageRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACOAdaptiveCardPrivate.h"
#import "ACOParseContext.h"
#import "ACRImageRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRColumnView.h"
#import "ACRContentHoldingUIView.h"
#import "ARCGridViewLayout.h"
#import "ACRImageProperties.h"
#import "ACRTapGestureRecognizerFactory.h"
#import "ACRUIImageView.h"
#import "ACRView.h"
#import "Enums.h"
#import "Image.h"
#import "SharedAdaptiveCard.h"
#import "UtiliOS.h"
#import <Foundation/Foundation.h>

@implementation ACRImageRenderer

typedef NS_ENUM(NSInteger, CustomContentMode) {
    CustomContentModeScaleAspectFitLeft,
    CustomContentModeScaleAspectFitRight,
    CustomContentModeScaleAspectFitTop,
    CustomContentModeScaleAspectFitBottom,
    CustomContentModeScaleAspectFitCenter,
    
    CustomContentModeScaleAspectFillLeft,
    CustomContentModeScaleAspectFillRight,
    CustomContentModeScaleAspectFillTop,
    CustomContentModeScaleAspectFillBottom,
    CustomContentModeScaleAspectFillCenter
};

+ (ACRImageRenderer *)getInstance
{
    static ACRImageRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRImage;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<Image> imgElem = std::dynamic_pointer_cast<Image>(elem);

    // makes parts for building a key to UIImage, there are different interfaces for loading the images
    // we list all the parts that are needed in building the key.
    NSString *number = [[NSNumber numberWithUnsignedLongLong:(unsigned long long)(elem.get())] stringValue];
    std::shared_ptr<AdaptiveCard> card = [[rootView card] card];
    NSString *urlString = [NSString stringWithCString:imgElem->GetUrl(ACTheme(rootView.theme), card->GetResources(), GetDeviceLanguageLocale()).c_str() encoding:[NSString defaultCStringEncoding]];
    NSDictionary *pieces = @{
        @"number" : number,
        @"url" : urlString
    };

    NSString *key = makeKeyForImage(acoConfig, @"image", pieces);
    NSMutableDictionary *imageViewMap = [rootView getImageMap];
    UIImage *img = imageViewMap[key];

    ACRImageProperties *imageProps = [[ACRImageProperties alloc] init:acoElem config:acoConfig image:img];
    // try get an UIImageView
    UIImageView *view = [rootView getImageView:key];
    if (!view && img) {
        CGSize cgsize = imageProps.contentSize;
        // if an UIImage is available, but UIImageView is missing, create one
        view = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cgsize.width, cgsize.height)];
        view.image = img;
    }

    ACRContentHoldingUIView *wrappingView = [[ACRContentHoldingUIView alloc] initWithImageProperties:imageProps imageView:view viewGroup:viewGroup];

    if (!view || !wrappingView) {
        [viewGroup addSubview:wrappingView];
        return wrappingView;
    }

    configRtl(view, rootView.context);
    configRtl(wrappingView, rootView.context);

    view.clipsToBounds = YES;

    std::string backgroundColor = imgElem->GetBackgroundColor();
    if (!backgroundColor.empty()) {
        view.backgroundColor = [ACOHostConfig convertHexColorCodeToUIColor:imgElem->GetBackgroundColor()];
    }
    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:wrappingView withAreaName:areaName];

    switch (imageProps.acrHorizontalAlignment) {
        case ACRCenter:
            [view.centerXAnchor constraintEqualToAnchor:wrappingView.centerXAnchor].active = YES;
            break;
        case ACRRight:
            [view.trailingAnchor constraintEqualToAnchor:wrappingView.trailingAnchor].active = YES;
            break;
        case ACRLeft:
            [view.leadingAnchor constraintEqualToAnchor:wrappingView.leadingAnchor].active = YES;
        default:
            break;
    }

    [wrappingView.heightAnchor constraintEqualToAnchor:view.heightAnchor].active = YES;

    // added padding to strech for image view because stretching ImageView is not desirable
    if (imgElem->GetHeight() == HeightType::Stretch) {
        [viewGroup addArrangedSubview:[viewGroup addPaddingFor:wrappingView] withAreaName:areaName];
    }

    [wrappingView.widthAnchor constraintGreaterThanOrEqualToAnchor:view.widthAnchor].active = YES;

    [view.topAnchor constraintEqualToAnchor:wrappingView.topAnchor].active = YES;

    if (!imageProps.isAspectRatioNeeded) {
        view.contentMode = UIViewContentModeScaleToFill;
    } else {
        view.contentMode = UIViewContentModeScaleAspectFit;
    }

    UILayoutPriority imagePriority = [ACRImageRenderer getImageUILayoutPriority:wrappingView];
    if (imageProps.acrImageSize != ACRImageSizeStretch) {
        [view setContentHuggingPriority:imagePriority forAxis:UILayoutConstraintAxisHorizontal];
        [view setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
        [view setContentCompressionResistancePriority:imagePriority forAxis:UILayoutConstraintAxisHorizontal];
        [view setContentCompressionResistancePriority:imagePriority forAxis:UILayoutConstraintAxisVertical];
    }

    std::shared_ptr<BaseActionElement> selectAction = imgElem->GetSelectAction();
    ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:selectAction];
    // instantiate and add tap gesture recognizer
    addSelectActionToView(acoConfig, acoSelectAction, rootView, view, viewGroup);

    view.translatesAutoresizingMaskIntoConstraints = NO;
    wrappingView.translatesAutoresizingMaskIntoConstraints = NO;

    view.isAccessibilityElement = YES;
    NSMutableString *stringForAccessiblilityLabel = [NSMutableString stringWithCString:imgElem->GetAltText().c_str() encoding:NSUTF8StringEncoding];
    NSString *toolTipAccessibilityLabel = configureForAccessibilityLabel(acoSelectAction, nil);
    if (toolTipAccessibilityLabel) {
        [stringForAccessiblilityLabel appendString:toolTipAccessibilityLabel];
    }

    if (stringForAccessiblilityLabel.length) {
        view.accessibilityLabel = stringForAccessiblilityLabel;
    }

    if (imgElem->GetImageStyle() == ImageStyle::Person) {
        wrappingView.isPersonStyle = YES;
    }
    
    if (imgElem->GetImageStyle() == ImageStyle::RoundedCorners) {
        std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
        view.layer.cornerRadius = config->GetCornerRadius(imgElem->GetElementType());
    }

    if (view && view.image) {
        // if we already have UIImageView and UIImage, configures the constraints and turn off the notification
        [self configUpdateForUIImageView:rootView acoElem:acoElem config:acoConfig image:view.image imageView:view];
    }
    return wrappingView;
}

- (void)configUpdateForUIImageView:(ACRView *)rootView acoElem:(ACOBaseCardElement *)acoElem config:(ACOHostConfig *)acoConfig image:(UIImage *)image imageView:(UIImageView *)imageView
{
    ACRContentHoldingUIView *superview = nil;
    ACRImageProperties *imageProps = nil;
    if ([imageView.superview isKindOfClass:[ACRContentHoldingUIView class]]) {
        superview = (ACRContentHoldingUIView *)imageView.superview;
        imageProps = superview.imageProperties;
        [imageProps updateContentSize:image.size];
    }

    if (!imageProps) {
        imageProps = [[ACRImageProperties alloc] init:acoElem config:acoConfig image:image];
    }

    CGSize cgsize = imageProps.contentSize;

    UILayoutPriority priority = [ACRImageRenderer getImageUILayoutPriority:imageView.superview];
    NSMutableArray<NSLayoutConstraint *> *constraints = [[NSMutableArray alloc] init];

    [constraints addObjectsFromArray:
                     @[
                         [NSLayoutConstraint constraintWithItem:imageView
                                                      attribute:NSLayoutAttributeWidth
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:nil
                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                     multiplier:1.0
                                                       constant:cgsize.width],
                         [NSLayoutConstraint constraintWithItem:imageView
                                                      attribute:NSLayoutAttributeHeight
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:nil
                                                      attribute:NSLayoutAttributeNotAnAttribute
                                                     multiplier:1.0
                                                       constant:cgsize.height]
                     ]];

    constraints[0].priority = priority;
    constraints[1].priority = priority;

    ACRAspectRatio aspectRatio = [ACRImageProperties convertToAspectRatio:cgsize];

    [constraints addObjectsFromArray:@[
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:imageView
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:aspectRatio.heightToWidth
                                      constant:0],
        [NSLayoutConstraint constraintWithItem:imageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:imageView
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:aspectRatio.widthToHeight
                                      constant:0]
    ]];

    constraints[2].priority = priority + 2;
    constraints[3].priority = priority + 2;

    if (imageProps.acrImageSize == ACRImageSizeAuto) {
        [constraints addObject:[imageView.widthAnchor constraintLessThanOrEqualToConstant:imageProps.contentSize.width]];
    }

    [NSLayoutConstraint activateConstraints:constraints];

    if (superview) {
        [superview update:imageProps];
    }

    [rootView removeObserver:rootView forKeyPath:@"image" onObject:imageView];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setImageFitModeFor:imageView image:image imageProps:imageProps];
    });
}

+ (UILayoutPriority)getImageUILayoutPriority:(UIView *)wrappingView
{
    UILayoutPriority priority = [wrappingView contentHuggingPriorityForAxis:UILayoutConstraintAxisHorizontal];
    return (!wrappingView || priority > ACRColumnWidthPriorityStretch) ? UILayoutPriorityDefaultHigh : priority;
}

- (void)setImageFitModeFor:(UIImageView *)imageView
                     image:(UIImage *)image
                imageProps:(ACRImageProperties *)imageProps
{
    ACRImageFitMode fitMode = imageProps.acrImageFitMode;
    
    if (fitMode == ACRImageFitModeFill || image.size.width <= 0 || image.size.height <= 0)
    {
        return;
    }
    
    ACRHorizontalContentAlignment hAlign = (ACRHorizontalContentAlignment)(imageProps.acrHorizontalContentAlignment ?: ACRHorizontalContentAlignmentLeft);
    ACRVerticalContentAlignment vAlign = (ACRVerticalContentAlignment)(imageProps.acrVerticalContentAlignment ?: ACRVerticalContentAlignmentTop);
    
    CGSize viewSize = imageView.bounds.size;
    CGSize imageSize = image.size;
    
    if (viewSize.width <= 0 || viewSize.height <= 0)
    {
        return;
    }
    
    imageView.contentMode = fitMode == ACRImageFitModeContain ? UIViewContentModeScaleAspectFit : UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    
    CGFloat imageViewAspectRatio = viewSize.width / viewSize.height;
    CGFloat imageAspectRatio = imageSize.width / imageSize.height;
    
    CustomContentMode mode = CustomContentModeScaleAspectFitCenter;
    
    if (fitMode == ACRImageFitModeContain)
    {
        if (imageViewAspectRatio > imageAspectRatio)
        {
            // Horizontal alignment
            switch (hAlign)
            {
                case ACRHorizontalContentAlignmentLeft:
                    mode = CustomContentModeScaleAspectFitLeft;
                    break;
                case ACRHorizontalContentAlignmentCenter:
                    mode = CustomContentModeScaleAspectFitCenter;
                    break;
                case ACRHorizontalContentAlignmentRight:
                    mode = CustomContentModeScaleAspectFitRight;
                    break;
            }
        }
        else
        {
            // Vertical alignment
            switch (vAlign)
            {
                case ACRVerticalContentAlignmentTop:
                    mode = CustomContentModeScaleAspectFitTop;
                    break;
                case ACRVerticalContentAlignmentCenter:
                    mode = CustomContentModeScaleAspectFitCenter;
                    break;
                case ACRVerticalContentAlignmentBottom:
                    mode = CustomContentModeScaleAspectFitBottom;
                    break;
            }
        }
    }
    else // ACRImageFitModeCover
    {
        if (imageViewAspectRatio < imageAspectRatio)
        {
            // Horizontal alignment
            switch (hAlign)
            {
                case ACRHorizontalContentAlignmentLeft:
                    mode = CustomContentModeScaleAspectFillLeft;
                    break;
                case ACRHorizontalContentAlignmentCenter:
                    mode = CustomContentModeScaleAspectFillCenter;
                    break;
                case ACRHorizontalContentAlignmentRight:
                    mode = CustomContentModeScaleAspectFillRight;
                    break;
            }
        }
        else
        {
            // Vertical alignment
            switch (vAlign)
            {
                case ACRVerticalContentAlignmentTop:
                    mode = CustomContentModeScaleAspectFillTop;
                    break;
                case ACRVerticalContentAlignmentCenter:
                    mode = CustomContentModeScaleAspectFillCenter;
                    break;
                case ACRVerticalContentAlignmentBottom:
                    mode = CustomContentModeScaleAspectFillBottom;
                    break;
            }
        }
    }
    
    imageView.image = [self makeImage:image forImageView:imageView mode:mode];
    [imageView layoutIfNeeded];
}

- (UIImage *)makeImage:(UIImage *)image forImageView:(UIImageView *)imageView mode:(CustomContentMode)mode
{
    CGSize viewSize = imageView.bounds.size;
    CGSize imageSize = image.size;
    
    if (viewSize.width <= 0 || viewSize.height <= 0 || imageSize.width <= 0 || imageSize.height <= 0)
    {
        return image;
    }
    
    CGFloat aspectWidth = viewSize.width / imageSize.width;
    CGFloat aspectHeight = viewSize.height / imageSize.height;
    
    BOOL isFitMode = (mode <= CustomContentModeScaleAspectFitCenter); // Fit modes come first
    CGFloat scale = isFitMode ? MIN(aspectWidth, aspectHeight) : MAX(aspectWidth, aspectHeight);
    
    CGFloat scaledWidth = imageSize.width * scale;
    CGFloat scaledHeight = imageSize.height * scale;
    
    CGFloat xOffset = 0.0;
    CGFloat yOffset = 0.0;
    
    // Horizontal alignment
    switch (mode)
    {
        case CustomContentModeScaleAspectFitLeft:
        case CustomContentModeScaleAspectFillLeft:
            xOffset = 0;
            break;
            
        case CustomContentModeScaleAspectFitRight:
        case CustomContentModeScaleAspectFillRight:
            xOffset = viewSize.width - scaledWidth;
            break;
            
        case CustomContentModeScaleAspectFitCenter:
        case CustomContentModeScaleAspectFillCenter:
            xOffset = (viewSize.width - scaledWidth) / 2.0;
            break;
            
        default:
            break;
    }
    
    // Vertical alignment
    switch (mode)
    {
        case CustomContentModeScaleAspectFitTop:
        case CustomContentModeScaleAspectFillTop:
            yOffset = 0;
            break;
            
        case CustomContentModeScaleAspectFitBottom:
        case CustomContentModeScaleAspectFillBottom:
            yOffset = viewSize.height - scaledHeight;
            break;
            
        case CustomContentModeScaleAspectFitCenter:
        case CustomContentModeScaleAspectFillCenter:
            yOffset = (viewSize.height - scaledHeight) / 2.0;
            break;
            
        default:
            break;
    }
    
    CGRect drawRect = CGRectMake(xOffset, yOffset, scaledWidth, scaledHeight);
    
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:viewSize];
    UIImage *resultImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context)
                            {
        [[UIColor clearColor] setFill];
        UIRectFill(CGRectMake(0, 0, viewSize.width, viewSize.height));
        [image drawInRect:drawRect];
    }];
    
    return resultImage;
}

@end
