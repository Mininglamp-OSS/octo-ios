//
//  ACRColumnSetRenderer
//  ACRColumnSetRenderer.mm
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#import "ACRColumnSetRenderer.h"
#import "ACOBaseCardElementPrivate.h"
#import "ACOHostConfigPrivate.h"
#import "ACRColumnRenderer.h"
#import "ACRColumnSetView.h"
#import "ACRRegistration.h"
#import "ACRSeparator.h"
#import "ACRViewPrivate.h"
#import "Column.h"
#import "ColumnSet.h"
#import "Enums.h"
#import "SharedAdaptiveCard.h"
#import "UtiliOS.h"

@implementation ACRColumnSetRenderer

+ (ACRColumnSetRenderer *)getInstance
{
    static ACRColumnSetRenderer *singletonInstance = [[self alloc] init];
    return singletonInstance;
}

+ (ACRCardElementType)elemType
{
    return ACRColumnSet;
}

- (UIView *)render:(UIView<ACRIContentHoldingView> *)viewGroup
           rootView:(ACRView *)rootView
             inputs:(NSMutableArray *)inputs
    baseCardElement:(ACOBaseCardElement *)acoElem
         hostConfig:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<ColumnSet> columnSetElem = std::dynamic_pointer_cast<ColumnSet>(elem);
    
    // Get responsive layout's host width
    ACRRegistration *reg = [ACRRegistration getInstance];
    HostWidthConfig hostWidthConfig = config->getHostWidth();
    HostWidth hostWidth = convertHostCardContainerToHostWidth([reg getHostCardContainer], hostWidthConfig);

    [rootView.context pushBaseCardElementContext:acoElem];

    ACRColumnSetView *columnSetView = [[ACRColumnSetView alloc] initWithStyle:(ACRContainerStyle)columnSetElem->GetStyle()
                                                                  parentStyle:[viewGroup style]
                                                                   hostConfig:acoConfig
                                                                    superview:viewGroup];
    columnSetView.rtl = rootView.context.rtl;

    NSString *areaName = stringForCString(elem->GetAreaGridName());
    [viewGroup addArrangedSubview:columnSetView withAreaName:areaName];
    
    [self configureBorderForElement:acoElem container:columnSetView config:acoConfig];

    configBleed(rootView, elem, columnSetView, acoConfig);

    [columnSetView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];

    ACRBaseCardElementRenderer *columnRenderer =
        [[ACRRegistration getInstance] getRenderer:[NSNumber numberWithInt:(int)CardElementType::Column]];
    std::vector<std::shared_ptr<Column>> columns = columnSetElem->GetColumns();

    NSMutableArray<NSLayoutConstraint *> *constraints = [[NSMutableArray alloc] init];

    ACRColumnRenderer *castedRenderer = (ACRColumnRenderer *)columnRenderer;
    auto relativeColumnWidthCounts = 0;

    for (std::shared_ptr<Column> column : columns) {
        if (column->GetVerticalContentAlignment() != VerticalContentAlignment::Top) {
            castedRenderer.fillAlignment = YES;
        }
        auto pixelWidth = column->GetPixelWidth();
        if (pixelWidth == 0) {
            auto width = column->GetWidth();
            if (!width.empty() && width != "stretch" && width != "auto") {
                try {
                    (void)std::stof(width);
                    ++relativeColumnWidthCounts;
                } catch (...) {
                    [rootView addWarnings:ACRInvalidValue mesage:@"Invalid column width is given"];
                }
            }
        }
    }

    columnSetView.hasMoreThanOneColumnWithRelatvieWidth = (relativeColumnWidthCounts > 1);
    ACOBaseCardElement *acoColumn = [[ACOBaseCardElement alloc] init];
    ACRColumnView *prevView = nil, *curView = nil, *stretchView = nil;
    auto firstColumn = columns.begin();
    auto prevColumn = columns.empty() ? nullptr : *firstColumn;
    auto lastColumn = columns.empty() ? nullptr : columns.back();
    ACOFeatureRegistration *featureReg = [ACOFeatureRegistration getInstance];
    ACRSeparator *separator = nil;
    BOOL hasPixelWidthColumn = NO;
    auto accumulativeWidth = 0;
    CGFloat minRelativeWidth = INT_MAX;
    double maxIntrinsicSize = 0;
    UIView *viewWithMinWidth = nil;
    ACRColumnView *viewWithMaxSize = nil;
    NSMutableArray<ACRColumnView *> *viewsWithRelativeWidth = [[NSMutableArray alloc] init];

    for (std::shared_ptr<Column> column : columns) {
        if (*firstColumn != column && column->MeetsTargetWidthRequirement(hostWidth)) {
            separator = [ACRSeparator renderSeparation:column forSuperview:columnSetView withStyle:[ACOHostConfig getPlatformContainerStyle: column->GetStyle()] withHostConfig:config];
        }

        [acoColumn setElem:column];

        @try {
            if ([acoColumn meetsRequirements:featureReg] == NO) {
                @throw [ACOFallbackException fallbackException];
            }
            if (column->MeetsTargetWidthRequirement(hostWidth) == false){
                continue;
            }
            
            if (lastColumn == column) {
                columnSetView.isLastColumn = YES;
            }

            curView = (ACRColumnView *)[columnRenderer render:columnSetView rootView:rootView inputs:inputs baseCardElement:acoColumn hostConfig:acoConfig];
            if (separator && !curView) {
                [columnSetView removeViewFromContentStackView:separator];
            } else {
                [columnSetView updateLayoutAndVisibilityOfRenderedView:curView acoElement:acoColumn separator:separator rootView:rootView];
            }
        } @catch (ACOFallbackException *e) {

            handleFallbackException(e, columnSetView, rootView, inputs, column, acoConfig, true);
            
            if (separator) {
                [columnSetView removeViewFromContentStackView:separator];
            }

            UIView *fallbackView = [columnSetView getLastSubview];
            if ([fallbackView isKindOfClass:[ACRColumnView class]]) {
                curView = (ACRColumnView *)fallbackView;
            } else {
                // the view added wasn't column view, remove and drop it.
                [columnSetView removeViewFromContentStackView:curView];
                curView = prevView;
            }
        }

        // when stretch, views with stretch properties should have equal width
        if (curView.pixelWidth) {
            hasPixelWidthColumn = YES;
            [constraints addObject:
                             [NSLayoutConstraint constraintWithItem:curView
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:nil
                                                          attribute:NSLayoutAttributeNotAnAttribute
                                                         multiplier:1
                                                           constant:curView.pixelWidth]];
        } else if ([curView.columnWidth isEqualToString:@"stretch"]) {
            if (stretchView) {
                [constraints addObject:
                                 [NSLayoutConstraint constraintWithItem:curView
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:stretchView
                                                              attribute:NSLayoutAttributeWidth
                                                             multiplier:1
                                                               constant:0]];
            }
            stretchView = curView;
        } else if (![curView.columnWidth isEqualToString:@"auto"]) {
            if (relativeColumnWidthCounts > 1) {
                [viewsWithRelativeWidth addObject:curView];
                accumulativeWidth += curView.relativeWidth;
                if (minRelativeWidth > curView.relativeWidth) {
                    viewWithMinWidth = curView;
                    minRelativeWidth = curView.relativeWidth;
                }
            }
        }

        // to enable filler space to fill, its superview must strech it
        if (curView.hasStretchableView || (columnSetElem->GetHeight() == HeightType::Stretch)) {
            [columnSetView setAlignmentForColumnStretch];
        }

        CGSize size = [curView intrinsicContentSize];
        if (size.width * size.height > maxIntrinsicSize) {
            maxIntrinsicSize = size.width * size.height;
            viewWithMaxSize = curView;
        }

        prevColumn = column;
    }

    for (ACRColumnView *view in viewsWithRelativeWidth) {
        if (view != viewWithMinWidth && view.relativeWidth) {
            [constraints addObject:
                             [NSLayoutConstraint constraintWithItem:view
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:viewWithMinWidth
                                                          attribute:NSLayoutAttributeWidth
                                                         multiplier:view.relativeWidth / minRelativeWidth
                                                           constant:0]];
        }
    }

    castedRenderer.fillAlignment = NO;

    if ([constraints count]) {
        [NSLayoutConstraint activateConstraints:constraints];
    }

    if (hasPixelWidthColumn && columns.size() == 1) {
        [columnSetView addPaddingSpace];
    }

    std::shared_ptr<BaseActionElement> selectAction = columnSetElem->GetSelectAction();
    ACOBaseActionElement *acoSelectAction = [ACOBaseActionElement getACOActionElementFromAdaptiveElement:selectAction];
    [columnSetView configureForSelectAction:acoSelectAction rootView:rootView];

    [columnSetView configureLayoutAndVisibility:GetACRVerticalContentAlignment(columnSetElem->GetVerticalContentAlignment().value_or(VerticalContentAlignment::Top))
                                      minHeight:columnSetElem->GetMinHeight()
                                     heightType:GetACRHeight(columnSetElem->GetHeight())
                                           type:ACRColumnSet];

    [columnSetView setNeedsLayout];

    [rootView.context popBaseCardElementContext:acoElem];

    columnSetView.accessibilityElements = [columnSetView getArrangedSubviews];

    return columnSetView;
}

- (void)configureBorderForElement:(ACOBaseCardElement *)acoElem container:(ACRContentStackView *)container config:(ACOHostConfig *)acoConfig
{
    std::shared_ptr<BaseCardElement> elem = [acoElem element];
    std::shared_ptr<ColumnSet> containerElem = std::dynamic_pointer_cast<ColumnSet>(elem);
    bool shouldShowBorder = containerElem->GetShowBorder();
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    if(shouldShowBorder)
    {
        container.layer.borderWidth = config->GetBorderWidth(containerElem->GetElementType());
        ACRContainerStyle style = (ACRContainerStyle)containerElem->GetStyle();
        auto borderColor = config->GetBorderColor([ACOHostConfig getSharedContainerStyle:style]);
        UIColor *color = [ACOHostConfig convertHexColorCodeToUIColor:borderColor];
        // we will add padding for any column element which has shouldShowBorder.
        [container applyPadding:config->GetSpacing().paddingSpacing priority:1000];
        [[container layer] setBorderColor:[color CGColor]];
    }
    bool roundedCorner = containerElem->GetRoundedCorners();
    if (roundedCorner)
    {
        container.layer.cornerRadius = config->GetCornerRadius(containerElem->GetElementType());
    }
}

@end
