//
//  ACRFlowLayout.m
//  AdaptiveCards
//
//  Created by Abhishek on 16/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACRFlowLayout.h"
#import "ACOBaseCardElementPrivate.h"
#include "ACOHostConfigPrivate.h"
#import "ACRShowCardTarget.h"
#import "ACRViewPrivate.h"
#import "UtiliOS.h"

using namespace AdaptiveCards;

@implementation ACRFlowLayout {
    NSMutableArray *_targets;
    NSMutableArray<ACRShowCardTarget *> *_showcardTargets;
    ACRContainerStyle _style;
    NSMutableDictionary<NSString *, NSValue *> *_subviewIntrinsicContentSizeCollection;
    ACRVerticalContentAlignment _verticalContentAlignment;
    ACRHorizontalAlignment _horizontalAlignment;
    UIStackView *_verticalStack;
    UIStackView *_horizontalStack;
    CGFloat _remainingRowSpace;
    CGFloat _availableRowSpace;
    std::shared_ptr<FlowLayout> _layout;
    CGFloat _rowSpacing;
    CGFloat _columnSpacing;
    NSInteger _numberOfItems;
    UIView *_lastItem;
}

- (instancetype)initWithFlowLayout:(std::shared_ptr<AdaptiveCards::FlowLayout> const &)flowLayout
                             style:(ACRContainerStyle)style
                       parentStyle:(ACRContainerStyle)parentStyle
                        hostConfig:(ACOHostConfig *)acoConfig
                          maxWidth:(CGFloat)maxWidth
                         superview:(UIView *)superview

{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    self = [self initWithFrame:superview.frame attributes:nil];
    if (self) 
    {
        _style = style;
        _layout = flowLayout;
        _availableRowSpace = maxWidth;
        _remainingRowSpace = _availableRowSpace;
        _rowSpacing = getSpacing(_layout->GetRowSpacing(), config);
        _columnSpacing = getSpacing(_layout->GetColumnSpacing(), config);
        _targets = [[NSMutableArray alloc] init];
        _showcardTargets = [[NSMutableArray alloc] init];
        _numberOfItems = 0;
        if (style != ACRNone &&
            style != parentStyle)
        {
            self.backgroundColor = [acoConfig getBackgroundColorForContainerStyle:_style];
            [self setBorderColorWithHostConfig:config];
        }
        [self setUpGrid];
    }
    return self;
}

- (instancetype)initWithStyle:(ACRContainerStyle)style
                  parentStyle:(ACRContainerStyle)parentStyle
                   hostConfig:(ACOHostConfig *)acoConfig
                    superview:(UIView *)superview
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    self = [self initWithFrame:superview.frame attributes:nil];
    if (self) 
    {
        _style = style;
        if (style != ACRNone &&
            style != parentStyle) 
        {
            self.backgroundColor = [acoConfig getBackgroundColorForContainerStyle:_style];
            [self setBorderColorWithHostConfig:config];
        }
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame attributes:(nullable NSDictionary<NSString *, id> *)attributes
{
     return [super initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
}

- (void)setUpGrid
{
    _verticalStack = [self createVerticalStack];
    [self addNewRowWithView:nil];
}

- (void)addNewRowWithView:(UIView *)view
{
    _horizontalStack = [self createHorizontalStack];
    [_verticalStack addArrangedSubview:_horizontalStack];
    if(view)
    {
        [_horizontalStack addArrangedSubview:view];
    }
}

- (void)addViewInCurrentRow:(UIView *)view
{
    [_horizontalStack addArrangedSubview:view];
}

- (UIStackView *)createHorizontalStack
{
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.alignment = UIStackViewAlignmentFill;
    stackView.distribution = UIStackViewDistributionFill;
    stackView.spacing = _columnSpacing;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    return stackView;
}

-(UIStackViewAlignment) horizontalAlignment
{
    if(_layout->GetItemFit() == ItemFit::Fill)
    {
        return UIStackViewAlignmentFill;
    }
    
    switch (_layout->GetHorizontalAlignment()) 
    {
        case AdaptiveCards::HorizontalAlignment::Center:
            return UIStackViewAlignmentCenter;
            
        case AdaptiveCards::HorizontalAlignment::Right:
            return UIStackViewAlignmentTrailing;
            
        case AdaptiveCards::HorizontalAlignment::Left:
            return UIStackViewAlignmentLeading;
    }
    
}

- (UIStackView *)createVerticalStack
{
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = [self horizontalAlignment];
    stackView.distribution = UIStackViewDistributionEqualSpacing;
    stackView.spacing = _rowSpacing;
    
    [self addSubview:stackView];
    
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutConstraint *selfWidth = [self.widthAnchor constraintEqualToConstant:_availableRowSpace];
    selfWidth.priority = 999;
    NSLayoutConstraint *leading = [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
    NSLayoutConstraint *trailing = [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor];
    NSLayoutConstraint *top = [stackView.topAnchor constraintEqualToAnchor:self.topAnchor];
    NSLayoutConstraint *bottom = [stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor];
    
    [NSLayoutConstraint activateConstraints:@[selfWidth, leading, trailing, top, bottom]];
    
    return stackView;
}

- (void)setBorderColorWithHostConfig:(std::shared_ptr<HostConfig> const &)config
{
    auto borderColor = config->GetBorderColor([ACOHostConfig getSharedContainerStyle:_style]);
    UIColor *color = [ACOHostConfig convertHexColorCodeToUIColor:borderColor];

    [[self layer] setBorderColor:[color CGColor]];
}

- (CGFloat)sizeForView:(UIView *)view fittingSize:(CGSize)fittingSize
{
    CGFloat widthForItem = fittingSize.width;
    
    if (_layout->GetItemPixelWidth() != -1)
    {
        widthForItem = _layout->GetItemPixelWidth();
    }
    CGFloat maxItemWidth = _layout->GetMaxItemPixelWidth();
    if (maxItemWidth != -1 && widthForItem > maxItemWidth)
    {
        widthForItem = maxItemWidth;
    }
    
    CGFloat minItemWidth = _layout->GetMinItemPixelWidth();
    if (minItemWidth != -1 && widthForItem < minItemWidth)
    {
        widthForItem = minItemWidth;
    }
    
    return widthForItem;
}

- (void)addArrangedSubview:(UIView *)view withAreaName:(NSString *)areaName
{
    CGSize fittingSize = [view systemLayoutSizeFittingSize:UILayoutFittingExpandedSize];
    CGFloat sizeForView = [self sizeForView:view fittingSize:fittingSize];
    if (sizeForView != fittingSize.width)
    {
        // this means that we need to resize view even futhur
        NSLayoutConstraint *itemWidth = [view.widthAnchor constraintEqualToConstant:sizeForView];
        itemWidth.priority = 999;
        [itemWidth setActive:YES];
    }
    if (_remainingRowSpace > (sizeForView + _columnSpacing))
    {
        [self addViewInCurrentRow:view];
        _remainingRowSpace -= (sizeForView + _columnSpacing);
    }
    else
    {
        [self addNewRowWithView:view];
        _remainingRowSpace = _availableRowSpace - (sizeForView + _columnSpacing);
    }
    _numberOfItems += 1;
    _lastItem = view;
}

- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)insertionIndex
{
    //not supported
}

- (void)removeLastViewFromArrangedSubview
{
    //not supported
}

- (void)removeAllArrangedSubviews
{
    //not supported
}

- (void)addTarget:(NSObject *)target
{
    [_targets addObject:target];

    if ([target isKindOfClass:[ACRShowCardTarget class]]) 
    {
        [_showcardTargets addObject:(ACRShowCardTarget *)target];
    }
}

- (void)configureForSelectAction:(ACOBaseActionElement *)action rootView:(ACRView *)rootView
{
    // This is already handled in ACRContentStackView
    // Any new layout is also added inside ACRContentStackView
}

- (void)adjustHuggingForLastElement
{
    //not supported
}

- (ACRContainerStyle)style
{
    return _style;
}

- (void)setStyle:(ACRContainerStyle)stye
{
    _style = stye;
}

- (void)hideAllShowCards
{
    for (ACRShowCardTarget *target in _showcardTargets) 
    {
        [target hideShowCard];
    }
}

- (NSUInteger)subviewsCounts
{
    return _numberOfItems;
}

- (NSUInteger)arrangedSubviewsCounts
{
    return _numberOfItems;
}

- (UIView *)getLastSubview
{
    return _lastItem;
}

- (void)updateLayoutAndVisibilityOfRenderedView:(UIView *)renderedView
                                     acoElement:(ACOBaseCardElement *)acoElem
                                      separator:(ACRSeparator *)separator
                                       rootView:(ACRView *)rootView
{
    // We don't have separators in flow container, so this is not supported
}

- (UIView *)addPaddingFor:(UIView *)view
{
    return [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)decreaseIntrinsicContentSize:(UIView *)view
{
    //not supported
}

- (void)increaseIntrinsicContentSize:(UIView *)view
{
    //not supported
}


@end
