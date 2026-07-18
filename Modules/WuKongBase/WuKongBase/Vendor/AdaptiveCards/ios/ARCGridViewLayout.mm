//
//  ARCGridViewLayout.m
//  AdaptiveCards
//
//  Created by hiteshkumar on 07/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ARCGridViewLayout.h"
#import "AreaGridLayout.h"
#import <UIKit/UIKit.h>
#import "UtiliOS.h"
#include "ACOHostConfigPrivate.h"

using namespace AdaptiveCards;

@implementation ARCGridViewLayout {
    NSMutableArray<UIView *> *_rows;
    NSMutableArray<NSMutableArray<UIView *> *> *_columns;
    NSInteger _numberOfColumns;
    NSInteger _numberOfRows;
    std::shared_ptr<AdaptiveCards::AreaGridLayout> _gridLayout;
    NSMutableDictionary<NSString *, UIView *> *_viewsByAreaName;
    NSMutableArray<NSString *> *_columnWidthTypes;
    NSMutableArray<NSNumber *> *_columnWidthValues;
    ACRContainerStyle _style;
    NSMutableArray<UIView *> *_viewSubViews;
    CGFloat _rowSpacing;
    CGFloat _columnSpacing;
}

- (instancetype)initWithStyle:(ACRContainerStyle)style
                  parentStyle:(ACRContainerStyle)parentStyle
                   hostConfig:(ACOHostConfig *)acoConfig
                    superview:(UIView<ACRIContentHoldingView> *)superview
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    self = [self initWithFrame:superview.frame];
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

- (instancetype)initWithGridLayout:(std::shared_ptr<AdaptiveCards::AreaGridLayout> const &)gridLayout
                             style:(ACRContainerStyle)style
                       parentStyle:(ACRContainerStyle)parentStyle
                        hostConfig:(ACOHostConfig *)acoConfig
                         superview:(UIView *)superview
{
    std::shared_ptr<HostConfig> config = [acoConfig getHostConfig];
    self = [super initWithFrame:superview.frame];
    if (self) 
    {
        _gridLayout = gridLayout;
        _rows = [NSMutableArray array];
        _columns = [NSMutableArray array];
        _viewsByAreaName = [NSMutableDictionary dictionary];
        _viewSubViews = [NSMutableArray array];
        _rowSpacing = getSpacing(_gridLayout->GetRowSpacing(), config);
        _columnSpacing = getSpacing(_gridLayout->GetColumnSpacing(), config);
        if (style != ACRNone &&
            style != parentStyle) 
        {
            self.backgroundColor = [acoConfig getBackgroundColorForContainerStyle:_style];
            [self setBorderColorWithHostConfig:config];
        }
        [self setUpGridLayout];
    }
    return self;
}

- (void)setUpGridLayout
{
    [self updateNumberOfRowsFromGridLayout]; // Get number of rows
    [self updateNumberOfColumnsFromGridLayout]; // Get number of columns
    [self updateColumnsWidthsFromGridLayout]; // Get widths for columns
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self createRows:_numberOfRows];
    [self setupViewsFromGridLayout];
}

- (void)createRows:(NSInteger)rows 
{
    for (NSInteger rowIndex = 0; rowIndex < rows; rowIndex++) 
    {
        UIView *rowView = [[UIView alloc] init];
        rowView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:rowView];
        
        NSMutableArray<UIView *> *columnViews = [NSMutableArray array];
        NSInteger previousAutoIndex = -1;
        for (NSInteger i = 0; i < _numberOfColumns; i++)
        {
            UIView *columnView = [[UIView alloc] init];
            columnView.translatesAutoresizingMaskIntoConstraints = NO;
            [rowView addSubview:columnView];
            NSString *type = _columnWidthTypes[i];
            NSNumber *value = _columnWidthValues[i];
            NSLayoutConstraint *widthConstraint;
            if ([type isEqualToString:@"fixed"]) 
            {
                CGFloat columnWidth = [value floatValue];
                widthConstraint = [columnView.widthAnchor constraintEqualToConstant:columnWidth];
            } 
            else if ([type isEqualToString:@"percentage"])
            {
                CGFloat percentage = [value floatValue] / 100.0;
                widthConstraint = [columnView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:percentage];
            }
            else if ([type isEqualToString:@"auto"] || type == nil)
            {
                if (previousAutoIndex != -1)
                {
                    widthConstraint = [columnViews[previousAutoIndex].widthAnchor constraintEqualToAnchor:(columnView.widthAnchor)];
                    previousAutoIndex = i;
                }
                else
                {
                    previousAutoIndex = i;
                    widthConstraint = [columnView.widthAnchor constraintGreaterThanOrEqualToConstant:0];
                }
            }
            
            [NSLayoutConstraint activateConstraints:@[
                [columnView.leadingAnchor constraintEqualToAnchor:(i == 0 ? rowView.leadingAnchor : columnViews[i - 1].trailingAnchor) constant:_columnSpacing],
                [columnView.topAnchor constraintEqualToAnchor:rowView.topAnchor],
                [columnView.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor],
                widthConstraint
            ]];
            if (i == _numberOfColumns-1) 
            {
                [NSLayoutConstraint activateConstraints:@[
                    [columnView.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-_columnSpacing]
                ]];
            }
            
            [columnViews addObject:columnView];
        }
        
        if (rowIndex == 0) 
        {
            [NSLayoutConstraint activateConstraints:@[
                [rowView.topAnchor constraintEqualToAnchor:self.topAnchor constant:_rowSpacing], // Add Top constraint
                [rowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [rowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        } 
        else
        {
            UIView *previousRow = _rows.lastObject;
            [NSLayoutConstraint activateConstraints:@[
                [rowView.topAnchor constraintEqualToAnchor:previousRow.bottomAnchor constant:_rowSpacing],
                [rowView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [rowView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }
        
        if (rowIndex == rows - 1)
        {
            [self addConstraints:@[
                [rowView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-_rowSpacing],
            ]];
        }
        [_rows addObject:rowView];
        [_columns addObject:columnViews];
    }
}

- (void)setupViewsFromGridLayout
{
    if (_gridLayout) 
    {
        const std::vector<std::shared_ptr<GridArea>>& areas = _gridLayout->GetAreas();
        
        for (const auto& areaPtr : areas) 
        {
            if (areaPtr) 
            {
                const GridArea* area = areaPtr.get();
                NSString *areaName = [NSString stringWithCString:area->GetName().c_str() encoding:NSUTF8StringEncoding];
                UIView *view = [[UIView alloc] init];
                view.translatesAutoresizingMaskIntoConstraints = NO;
                _viewsByAreaName[areaName] = view;
                [self addView:view
                         row:area->GetRow()
                      column:area->GetColumn()
                    rowSpan:area->GetRowSpan()
                 columnSpan:area->GetColumnSpan()];
            }
        }
    }
}

- (void)addView:(UIView *)view row:(NSInteger)row column:(NSInteger)column rowSpan:(NSInteger)rowSpan columnSpan:(NSInteger)columnSpan
{
    [self addSubview:view];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    // Adjust row and column indices to ensure they fall within bounds
    NSInteger adjustedRow = MIN(MAX(row - 1, 0), (NSInteger)_rows.count - 1);
    NSInteger adjustedColumn = MIN(MAX(column - 1, 0), (NSInteger)_columns[adjustedRow].count - 1);
    
    NSInteger adjustedRowSpan = MIN(MAX(rowSpan - 1, 0), (NSInteger)_rows.count - adjustedRow - 1);
    NSInteger adjustedColumnSpan = MIN(MAX(columnSpan - 1, 0), (NSInteger)_columns[adjustedRow].count - adjustedColumn - 1);
    
    [self createConstraintsForView:view
                               row:adjustedRow
                            column:adjustedColumn
                           rowSpan:adjustedRowSpan
                        columnSpan:adjustedColumnSpan];
}

- (void)createConstraintsForView:(UIView *)view row:(NSInteger)row column:(NSInteger)column rowSpan:(NSInteger)rowSpan columnSpan:(NSInteger)columnSpan
{
    UIView *startColumnView = _columns[row][column];
    UIView *endColumnView = (column + columnSpan < (NSInteger)_columns[row].count) ? _columns[row][column + columnSpan] : self;
    
    UIView *startRowView = _rows[row];
    UIView *endRowView = (row + rowSpan < (NSInteger)_rows.count) ? _rows[row + rowSpan] : self;
    
    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:startColumnView.leadingAnchor],
        [view.topAnchor constraintEqualToAnchor:startRowView.topAnchor],
        [view.trailingAnchor constraintEqualToAnchor:endColumnView.trailingAnchor],
        [view.bottomAnchor constraintEqualToAnchor:endRowView.bottomAnchor]
    ]];
}

- (void)updateNumberOfRowsFromGridLayout
{
    if (_gridLayout) 
    {
        const std::vector<std::shared_ptr<GridArea>>& areas = _gridLayout->GetAreas();
        NSInteger maxRows = 1;
        for (const auto& areaPtr : areas) 
        {
            if (areaPtr) 
            {
                const GridArea* area = areaPtr.get();
                NSInteger rows = area->GetRow() + area->GetRowSpan() - 1;
                if (rows > maxRows)
                {
                    maxRows = rows;
                }
            }
        }
        _numberOfRows = maxRows;
    }
}

- (void)updateNumberOfColumnsFromGridLayout
{
    _numberOfColumns = 1;
    if (_gridLayout)
    {
        const std::vector<std::string>& mColumns = _gridLayout->GetColumns();
        if (!mColumns.empty()) 
        {
            _numberOfColumns = mColumns.size();
        }
    }
}

- (void)updateColumnsWidthsFromGridLayout
{
    if (_gridLayout) 
    {
        const std::vector<std::string>& mColumns = _gridLayout->GetColumns();
        if (!mColumns.empty()) {
            // Arrays to store column types and values
            NSMutableArray<NSString *> *columnTypes = [NSMutableArray array];
            NSMutableArray<NSNumber *> *columnValues = [NSMutableArray array];
            
            CGFloat fixedWidthTotal = 0.0;
            NSInteger autoCount = 0;
            
            for (const std::string& column : mColumns) 
            {
                NSString *columnStr = [NSString stringWithCString:column.c_str() encoding:NSUTF8StringEncoding];
                if ([columnStr hasSuffix:@"px"]) 
                {
                    // Column width in pixels
                    NSString *valueStr = [columnStr substringToIndex:columnStr.length - 2];
                    CGFloat width = [valueStr floatValue];
                    [columnTypes addObject:@"fixed"];
                    [columnValues addObject:@(width)];
                    fixedWidthTotal += width;
                } 
                else if ([columnStr isEqualToString:@"auto"])
                {
                    // Auto width
                    [columnTypes addObject:@"auto"];
                    [columnValues addObject:@(0)];
                    autoCount++;
                }
                else
                {
                    // Default to percentage (if no suffix is provided, assume percentage)
                    CGFloat percentage = [columnStr floatValue];
                    [columnTypes addObject:@"percentage"];
                    [columnValues addObject:@(percentage)];
                }
            }
            _columnWidthTypes = columnTypes;
            _columnWidthValues = columnValues;
        }
    }
}

- (void)addArrangedSubview:(UIView *)view withAreaName:(NSString *)areaName
{
    // If areaName is not available, we can't add the view
    if (areaName == nil || [areaName isEqualToString:@""] || _viewsByAreaName.count == 0)
    {
        return;
    }
    UIView *area = _viewsByAreaName[areaName];
    if (area == nil) /// If area is not available with the given name, we can not add without area
    {
        return;
    }
    [_viewSubViews addObject:view];
    [area addSubview:view];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [view.leadingAnchor constraintEqualToAnchor:area.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:area.trailingAnchor],
        [view.topAnchor constraintEqualToAnchor:area.topAnchor],
        [view.bottomAnchor constraintLessThanOrEqualToAnchor:area.bottomAnchor]
    ]];
}

- (void)setBorderColorWithHostConfig:(std::shared_ptr<HostConfig> const &)config
{
    auto borderColor = config->GetBorderColor([ACOHostConfig getSharedContainerStyle:_style]);
    UIColor *color = [ACOHostConfig convertHexColorCodeToUIColor:borderColor];

    [[self layer] setBorderColor:[color CGColor]];
}

- (NSUInteger)arrangedSubviewsCounts
{
    return _viewSubViews.count;
}

- (ACRContainerStyle)style
{
    return _style;
}

- (NSUInteger)subviewsCounts
{
    return self.subviews.count;
}

- (NSArray<UIView *> *)getArrangedSubviews
{
    return _viewSubViews;
}

- (UIView *)addPaddingFor:(UIView *)view
{
    return view;
}

- (void)addTarget:(NSObject *)target { 
    // Do nothing
}

- (void)adjustHuggingForLastElement { 
    // Do nothing
}

- (void)configureForSelectAction:(ACOBaseActionElement *)action rootView:(ACRView *)rootView { 
    // Do nothing
}

- (UIView *)getLastSubview { 
    return self;
}

- (void)hideAllShowCards { 
    // Do nothing
}

- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)insertionIndex { 
    // Do nothing
}

- (void)removeAllArrangedSubviews { 
    // Do nothing
}

- (void)removeLastViewFromArrangedSubview { 
    // Do nothing
}

- (void)setStyle:(ACRContainerStyle)stye { 
    // Do nothing
}

- (void)updateLayoutAndVisibilityOfRenderedView:(UIView *)renderedView acoElement:(ACOBaseCardElement *)acoElem separator:(ACRSeparator *)separator rootView:(ACRView *)rootView { 
    // Do nothing
}

- (void)increaseIntrinsicContentSize:(UIView *)view
{
}

- (void)decreaseIntrinsicContentSize:(UIView *)view
{
}

@end
