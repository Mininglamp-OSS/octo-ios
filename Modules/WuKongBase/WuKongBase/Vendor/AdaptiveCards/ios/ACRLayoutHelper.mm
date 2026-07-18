//
//  ACRWidthDistributor.m
//  AdaptiveCards
//
//  Created by Abhishek on 08/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRLayoutHelper.h"
#import "Column.h"
#import "ColumnSet.h"
#import "ACTable.h"
#import "TableRow.h"
#import "TableCell.h"
#import "UtiliOS.h"
#import "ACOHostConfigPrivate.h"
#import "FlowLayout.h"
#import "Carousel.h"

using namespace AdaptiveCards;

@implementation ACRLayoutHelper

- (instancetype)init
{
    self = [super init];
    return self;
}

- (void)distributeWidth:(float)parentWidth
               rootView:(ACRView *)rootView
             forElement:(std::shared_ptr<AdaptiveCard> const &)card
          andHostConfig:(ACOHostConfig *)config
{
    // we will not do width distribution if flow layout do't apply anywhere in card
    if(![self shouldUseNewLayout:rootView forElement:card andHostConfig:config])
    {
        return;
    }
    std::vector<std::shared_ptr<BaseCardElement>> body = card->GetBody();
    if (body.size() > 0)
    {
        
        float childrenWidth = [self cardWidthDistributor:card availableWidth:parentWidth andHostConfig:config];
        for (const auto &element : body)
        {
            [self distribute:childrenWidth rootView:rootView forElement:element andHostConfig:config];
        }
    }
}

- (void)distribute:(float)parentWidth
          rootView:(ACRView *)rootView
        forElement:(std::shared_ptr<BaseCardElement> const &)elem
     andHostConfig:(ACOHostConfig *)config
{
    // self width is always equal to parent
    [rootView setWidthForElememt:elem->GetInternalId().Hash() width:parentWidth];
    
    // parent width is equally divided amongst all children
    switch (elem->GetElementType()) 
    {
        case CardElementType::Container:
        {
            std::shared_ptr<Container> container = std::dynamic_pointer_cast<Container>(elem);
            long numberOfItems = container->GetItems().size();
            if(numberOfItems > 0)
            {
                float childrenWidth = [self containerWidthDistributor:container availableWidth:parentWidth andHostConfig:config];
                for (const auto &item : container->GetItems())
                {
                    [self distribute:childrenWidth rootView:rootView forElement:item andHostConfig:config];
                }
            }
            
            break;
        }
        case CardElementType::ColumnSet:
        {
            std::shared_ptr<ColumnSet> columnSetElem = std::dynamic_pointer_cast<ColumnSet>(elem);
            std::vector<std::shared_ptr<Column>> columns = columnSetElem->GetColumns();
            std::shared_ptr<HostConfig> hostConfig = [config getHostConfig];
            unsigned int padding = hostConfig->GetSpacing().paddingSpacing;
            unsigned int spacing = getSpacing(elem->GetSpacing(), hostConfig);
            long numberOfColumns = columns.size();
            if(numberOfColumns > 0)
            {
                // removing padding of coloumSet and spacing between elemenets
                float availableSpace = (parentWidth - (2 * padding) - ((numberOfColumns - 1) * spacing));
                
                NSArray<NSNumber *> *columnWidths =  [self columnSetWidthDistributor:columnSetElem availableWidth:availableSpace andHostConfig:config rootView:rootView];
                
                for (NSUInteger i = 0; i < columns.size(); i++)
                {
                    std::shared_ptr<Column> column = columns[i];
                    float childrenWidth = [columnWidths[i] floatValue];
                    [self distribute:childrenWidth rootView:rootView forElement:column andHostConfig:config];
                }
            }
            break;
        }
        case CardElementType::Table:
        {
            std::shared_ptr<Table> table = std::dynamic_pointer_cast<Table>(elem);
            std::vector<std::shared_ptr<TableColumnDefinition>> colums = table->GetColumns();
            long numberOfColumns = colums.size();
            if(numberOfColumns > 0)
            {
                int cellSpacing = [config getHostConfig]->GetTable().cellSpacing;
                float availableSpace = (parentWidth - ((numberOfColumns - 1) * cellSpacing));
                
                NSArray<NSNumber *> *cellWidths = [self tableWidthDistributor:table availableWidth:availableSpace andHostConfig:config rootView:rootView];
               
                std::vector<std::shared_ptr<TableRow>> tableRows = table->GetRows();
                for (const auto &row : tableRows)
                {
                    std::vector<std::shared_ptr<TableCell>> tableCells = row->GetCells();
                    if (tableCells.size() == colums.size())
                    {
                        for (NSUInteger i = 0; i < tableCells.size(); i++)
                        {
                            std::shared_ptr<TableCell> cell = tableCells[i];
                            float childrenWidth = cellWidths[i].floatValue;
                            [self distribute:childrenWidth rootView:rootView forElement:cell andHostConfig:config];
                            
                            std::shared_ptr<TableColumnDefinition> column = colums[i];
                            column->SetPixelWidth(childrenWidth);
                        }
                    }
                    else
                    {
                        // ideally this code should never run, because number of cell in row
                        // and number of columnDefinitions in table should be same
                        // but kept it anyways for wrong payloads
                        for (NSUInteger i = 0; i < tableCells.size(); i++)
                        {
                            std::shared_ptr<TableCell> cell = tableCells[i];
                            float childrenWidth = cellWidths[i].floatValue;
                            [self distribute:childrenWidth rootView:rootView forElement:cell andHostConfig:config];
                            
                            std::shared_ptr<TableColumnDefinition> column = colums[i];
                            column->SetPixelWidth(childrenWidth);
                        }
                    }
                }
            }
            
            break;
        }
            
        case CardElementType::Column:
        {
            std::shared_ptr<Column> column = std::dynamic_pointer_cast<Column>(elem);
            /// set column width explicitly, this way we will bypass existing logic
            column->SetPixelWidth(parentWidth);
            break;
        }
        case CardElementType::Carousel:
        {
            std::shared_ptr<Carousel> carousel = std::dynamic_pointer_cast<Carousel>(elem);
            long numberOfItems = carousel->GetPages().size();
            if(numberOfItems > 0)
            {
                for (const auto &item : carousel->GetPages())
                {
                    [self distribute:parentWidth rootView:rootView forElement:item andHostConfig:config];
                }
            }
            
            break;
        }
        case CardElementType::CarouselPage:
        {
            std::shared_ptr<CarouselPage> carouselPage = std::dynamic_pointer_cast<CarouselPage>(elem);
            long numberOfItems = carouselPage->GetItems().size();
            if(numberOfItems > 0)
            {
                float childrenWidth = [self carouselPageWidthDistributor:carouselPage availableWidth:parentWidth andHostConfig:config];
                for (const auto &item : carouselPage->GetItems())
                {
                    [self distribute:childrenWidth rootView:rootView forElement:item andHostConfig:config];
                }
            }
            
            break;
        }
            
        default:
            break;
    }
}

- (BOOL)shouldUseNewLayout:(ACRView *)rootView
                forElement:(std::shared_ptr<AdaptiveCard> const &)card
             andHostConfig:(ACOHostConfig *)config
{
    NSObject<ACRIFeatureFlagResolver> *featureFlagResolver = [[ACRRegistration getInstance] getFeatureFlagResolver];
    BOOL isFlowLayoutEnabled = [featureFlagResolver boolForFlag:@"isFlowLayoutEnabled"] ?: NO;
    
    if(!isFlowLayoutEnabled)
    {
        return NO;
    }

    std::shared_ptr<AdaptiveCards::Layout> layout = [self layoutToApplyFrom:card->GetLayouts() andHostConfig:config];
    
    BOOL isFlow = (layout->GetLayoutContainerType() == LayoutContainerType::Flow);
    
    std::vector<std::shared_ptr<BaseCardElement>> body = card->GetBody();
    for (const auto &element : body)
    {
        isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:element andHostConfig:config]);
    }
    
    return isFlow;
}

- (BOOL)shouldUseNewLayoutForView:(ACRView *)rootView
                       forElement:(std::shared_ptr<BaseCardElement> const &)elem
                    andHostConfig:(ACOHostConfig *)config
{
    switch (elem->GetElementType())
    {
        case CardElementType::Container:
        {
            std::shared_ptr<Container> container = std::dynamic_pointer_cast<Container>(elem);
            std::shared_ptr<AdaptiveCards::Layout> layout = [self layoutToApplyFrom:container->GetLayouts() andHostConfig:config];
            
            BOOL isFlow = (layout->GetLayoutContainerType() == LayoutContainerType::Flow);
            
            for (const auto &item : container->GetItems())
            {
                isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:item andHostConfig:config]);
            }

            return isFlow;
        }
        case CardElementType::ColumnSet:
        {
            std::shared_ptr<ColumnSet> columnSetElem = std::dynamic_pointer_cast<ColumnSet>(elem);
            BOOL isFlow = NO;
            for (const auto &column : columnSetElem->GetColumns())
            {
                isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:column andHostConfig:config]);
            }
            return isFlow;
        }
        case CardElementType::Table:
        {
            std::shared_ptr<Table> table = std::dynamic_pointer_cast<Table>(elem);
            std::vector<std::shared_ptr<TableColumnDefinition>> colums = table->GetColumns();
            std::vector<std::shared_ptr<TableRow>> tableRows = table->GetRows();
            BOOL isFlow = NO;
            for (const auto &row : tableRows)
            {
                std::vector<std::shared_ptr<TableCell>> tableCells = row->GetCells();
                for (const auto &cell : tableCells)
                {
                    isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:cell andHostConfig:config]);
                }
            }
            return isFlow;
        }
        case CardElementType::TableCell:
        {
            std::shared_ptr<TableCell> container = std::dynamic_pointer_cast<TableCell>(elem);
            std::shared_ptr<AdaptiveCards::Layout> layout = [self layoutToApplyFrom:container->GetLayouts() andHostConfig:config];
            return (layout->GetLayoutContainerType() == LayoutContainerType::Flow);
        }
        case CardElementType::Column:
        {
            std::shared_ptr<Column> container = std::dynamic_pointer_cast<Column>(elem);
            std::shared_ptr<AdaptiveCards::Layout> layout = [self layoutToApplyFrom:container->GetLayouts() andHostConfig:config];
            return (layout->GetLayoutContainerType() == LayoutContainerType::Flow);
        }
        case CardElementType::Carousel:
        {
            std::shared_ptr<Carousel> carousel = std::dynamic_pointer_cast<Carousel>(elem);
            
            BOOL isFlow = NO;
            
            for (const auto &item : carousel->GetPages())
            {
                isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:item andHostConfig:config]);
            }

            return isFlow;
        }
            
        case CardElementType::CarouselPage:
        {
            std::shared_ptr<CarouselPage> carouselPage = std::dynamic_pointer_cast<CarouselPage>(elem);
            std::shared_ptr<AdaptiveCards::Layout> layout = [self layoutToApplyFrom:carouselPage->GetLayouts() andHostConfig:config];
            
            BOOL isFlow = (layout->GetLayoutContainerType() == LayoutContainerType::Flow);
            
            for (const auto &item : carouselPage->GetItems())
            {
                isFlow = isFlow || ([self shouldUseNewLayoutForView:rootView forElement:item andHostConfig:config]);
            }

            return isFlow;
        }
            
        default:
            break;
    }
    return NO;
}

- (std::shared_ptr<AdaptiveCards::Layout>)layoutToApplyFrom:(std::vector<std::shared_ptr<Layout>>)layoutArray andHostConfig:(ACOHostConfig *)config
{
    ACRRegistration *reg = [ACRRegistration getInstance];
    HostWidthConfig hostWidthConfig = [config getHostConfig]->getHostWidth();
    HostWidth hostWidth = convertHostCardContainerToHostWidth([reg getHostCardContainer], hostWidthConfig);
    std::shared_ptr<Layout> final_layout;
    for (const auto& layout : layoutArray)
    {
        if(layout->GetLayoutContainerType() == LayoutContainerType::None)
        {
            continue;
        }
        
        if(layout->MeetsTargetWidthRequirement(hostWidth))
        {
            final_layout = layout;
            break;
        }
        else if (layout->GetTargetWidth() == TargetWidthType::Default)
        {
            final_layout = layout;
        }
    }
    
    
    if (final_layout == nullptr)
    {
        final_layout = std::make_shared<Layout>();
        final_layout->SetLayoutContainerType(LayoutContainerType::Stack);
        final_layout->SetTargetWidth(TargetWidthType::Default);
    }
    
    return final_layout;
}

/**
 * This methods distributes available width amongst all items of given container
 */
- (float)containerWidthDistributor:(std::shared_ptr<Container> const)container
                    availableWidth:(float)availableWidth
                     andHostConfig:(ACOHostConfig *)config
{
    std::shared_ptr<Layout> final_layout = [self layoutToApplyFrom:container->GetLayouts() andHostConfig:config];
    if(final_layout->GetLayoutContainerType() == LayoutContainerType::Flow)
    {
        std::shared_ptr<FlowLayout> flow_layout = std::dynamic_pointer_cast<FlowLayout>(final_layout);
        
        int pixelWidth = [self pixelWidthForItemsInFlow:flow_layout];
        if (pixelWidth != -1)
        {
            return pixelWidth;
        }
    }
    
    return availableWidth;
}

/**
 * This methods distributes available width amongst all items of given carousel page
 */
- (float)carouselPageWidthDistributor:(std::shared_ptr<CarouselPage> const)carouselPage
                    availableWidth:(float)availableWidth
                     andHostConfig:(ACOHostConfig *)config
{
    std::shared_ptr<Layout> final_layout = [self layoutToApplyFrom:carouselPage->GetLayouts() andHostConfig:config];
    if(final_layout->GetLayoutContainerType() == LayoutContainerType::Flow)
    {
        std::shared_ptr<FlowLayout> flow_layout = std::dynamic_pointer_cast<FlowLayout>(final_layout);
        
        int pixelWidth = [self pixelWidthForItemsInFlow:flow_layout];
        if (pixelWidth != -1)
        {
            return pixelWidth;
        }
    }
    
    return availableWidth;
}

/**
 * This methods distributes available width amongst all items of given card
 */
- (float)cardWidthDistributor:(std::shared_ptr<AdaptiveCard> const)card
               availableWidth:(float)availableWidth
                andHostConfig:(ACOHostConfig *)config
{
    std::shared_ptr<Layout> final_layout = [self layoutToApplyFrom:card->GetLayouts() andHostConfig:config];
    if(final_layout->GetLayoutContainerType() == LayoutContainerType::Flow)
    {
        std::shared_ptr<FlowLayout> flow_layout = std::dynamic_pointer_cast<FlowLayout>(final_layout);
        
        int pixelWidth = [self pixelWidthForItemsInFlow:flow_layout];
        if (pixelWidth != -1)
        {
            return pixelWidth;
        }
    }
    
    return availableWidth;
}


/**
 * This methods distributes available width amongst all columns of given columnSet
 * It returns an array with postive or negative values.
 * Postive values shows that width calculation were successful for that index. This width can be applied to column at that index.
 * Negative values shows that width calculation failed for column at that index
 * Ideally, for column with nagative width shouldn't be shown
 */
- (NSArray<NSNumber *> *)columnSetWidthDistributor:(std::shared_ptr<ColumnSet> const)columnSet
                                    availableWidth:(float)availableWidth
                                     andHostConfig:(ACOHostConfig *)config
                                          rootView:(ACRView *)rootView
{
    
    NSMutableArray *relativeWidthRatios = [NSMutableArray array];
    std::vector<std::shared_ptr<Column>> columns = columnSet->GetColumns();
    CGFloat remainingWidth = availableWidth;
    NSMutableArray *finalWidthArray = [NSMutableArray array];
    NSMutableArray *strechOrAutoIndexes = [NSMutableArray array];
    CGFloat minRelativeWidth = CGFLOAT_MAX;
    
    for (NSUInteger i = 0; i < columns.size(); i++)
    {
        std::shared_ptr<Column> column = columns[i];
        auto pixelWidth = column->GetPixelWidth();
        auto width = column->GetWidth();
        if (pixelWidth != 0)
        {
            [finalWidthArray addObject:[NSNumber numberWithInt:pixelWidth]];
            remainingWidth -= pixelWidth;
        }
        else if (width.empty() || width == "stretch" || width == "auto")
        {
            // add these columns as relative width as 1
            [finalWidthArray addObject:[NSNumber numberWithInt:-1]];
            [relativeWidthRatios addObject:[NSNumber numberWithInt:1]];
            [strechOrAutoIndexes addObject:[NSNumber numberWithInt:(int)i]];
        }
        else
        {
            try {
                // This must be relative width
                CGFloat relativeWidth = std::stof(width);
                [relativeWidthRatios addObject:[NSNumber numberWithInt:relativeWidth]];
                [finalWidthArray addObject:[NSNumber numberWithInt:-(relativeWidth)]];
                if (relativeWidth < minRelativeWidth)
                {
                    minRelativeWidth = relativeWidth;
                }
            } 
            catch (...)
            {
                [rootView addWarnings:ACRInvalidValue mesage:@"Invalid column width is given"];
            }
        }
    }
    
    // set strech and auto width same as minimum relative width column
    if(minRelativeWidth != CGFLOAT_MAX)
    {
        for (NSNumber *index: strechOrAutoIndexes)
        {
            int indexInt = [index intValue];
            [finalWidthArray replaceObjectAtIndex:indexInt withObject:[NSNumber numberWithFloat:-(minRelativeWidth)]];
        }
    }
    
    if (relativeWidthRatios.count == 0)
    {
        return finalWidthArray;
    }
    
    if (remainingWidth <= 0)
    {
        [rootView addWarnings:ACRInvalidValue mesage:@"Pixel width overflow, no space left for other columns"];
        return finalWidthArray;
    }
    
    // Distribute remaining to relative width columns
    float sumOfAllRelativeWidth = 0.0;
    float widthMultiplier = 1;
    
    for (NSNumber *number in relativeWidthRatios)
    {
        sumOfAllRelativeWidth += [number intValue];
    }
    
    if (sumOfAllRelativeWidth > 0)
    {
        widthMultiplier = remainingWidth/sumOfAllRelativeWidth;
    }
  
    for (NSUInteger i = 0; i < finalWidthArray.count; i++)
    {
        float existingRelativeValue = [finalWidthArray[i] intValue];
        if (existingRelativeValue < 0)
        {
            // all relative width are inserted as negative numbers, so use nagative multiplier
            float newValue = -(widthMultiplier * existingRelativeValue);
            [finalWidthArray replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:newValue]];
        }
    }
    
    return finalWidthArray;
}

/**
 * This methods distributes available width amongst all cells of given Table
 * It returns an array with postive or negative values.
 * Postive values shows that width calculation were successful for that index. This width can be applied to cell at that index.
 * Negative values shows that width calculation failed for cell at that index
 * Ideally, for cell with nagative width shouldn't be shown
 */
- (NSArray<NSNumber *> *)tableWidthDistributor:(std::shared_ptr<Table> const)table
                                availableWidth:(float)availableWidth
                                 andHostConfig:(ACOHostConfig *)config
                                      rootView:(ACRView *)rootView
{
    NSMutableArray *finalWidthArray = [NSMutableArray array];
    std::vector<std::shared_ptr<TableColumnDefinition>> colums = table->GetColumns();
    CGFloat remainingWidth = availableWidth;
    float sumOfAllRelativeWidth = 0.0;
    float widthMultiplier = 1;
    
    for (const auto &columnDefinition : colums) 
    {
        auto optionalNumericValue = columnDefinition->GetWidth();
        if (optionalNumericValue.has_value()) 
        {
            // relative width
            sumOfAllRelativeWidth += *optionalNumericValue;
            [finalWidthArray addObject:[NSNumber numberWithInt:-(*optionalNumericValue)]];
        }
        else if (auto optionalPixelValue = columnDefinition->GetPixelWidth(); optionalPixelValue.has_value())
        {
            // pixel Width
            availableWidth -= *optionalPixelValue;
            [finalWidthArray addObject:[NSNumber numberWithFloat:*optionalPixelValue]];
        }
        else
        {
            [finalWidthArray addObject:[NSNumber numberWithInt:-1]];
            [rootView addWarnings:ACRInvalidValue mesage:@"Unsupported width value for TableColumnDefinition"];
        }
    }
    
    if (sumOfAllRelativeWidth > 0)
    {
        widthMultiplier = remainingWidth/sumOfAllRelativeWidth;
        for (NSUInteger i = 0; i < finalWidthArray.count; i++)
        {
            float existingRelativeValue = [finalWidthArray[i] intValue];
            if (existingRelativeValue < 0)
            {
                // all relative width are inserted as negative numbers, so use nagative multiplier
                float newValue = -(widthMultiplier * existingRelativeValue);
                [finalWidthArray replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:newValue]];
            }
        }
    }

    return finalWidthArray;
}


- (int)pixelWidthForItemsInFlow:(std::shared_ptr<FlowLayout>)flowLayout
{
    int pixelWidth = flowLayout->GetItemPixelWidth();
    if (pixelWidth != -1)
    {
        int minPixelWidth = flowLayout->GetMinItemPixelWidth();
        int maxPixelWidth = flowLayout->GetMaxItemPixelWidth();
        if (minPixelWidth != -1 && pixelWidth < minPixelWidth)
        {
            pixelWidth = minPixelWidth;
        }
        
        if (maxPixelWidth != -1 && maxPixelWidth > pixelWidth)
        {
            pixelWidth = maxPixelWidth;
        }
        
        return pixelWidth;
        
    }
    return -1;
}




@end
