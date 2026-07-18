//
//  ACRPageControl.mm
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRPageControl.h"

@interface CircularView : UIView
@end

@implementation CircularView

- (void)tintColorDidChange
{
    self.backgroundColor = self.tintColor;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateCornerRadius];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self updateCornerRadius];
}

- (void)updateCornerRadius
{
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2;
}

@end

@interface ACRPageControlConfig()

@property (nonatomic, assign) NSInteger numberOfPages;
@property (nonatomic, assign, nonnull) NSNumber *displayPages;
@property (nonatomic, assign) BOOL hidesForSinglePage;
@property (nonatomic, strong, nonnull) UIColor *selctedTintColor;
@property (nonatomic, strong, nonnull) UIColor *unselctedTintColor;
@end

@implementation ACRPageControlConfig

- (instancetype _Nonnull)initWithNumberOfPages:(NSInteger)numberOfPages displayPages:(nullable NSNumber *)displayPages
                              selctedTintColor:(UIColor * _Nonnull)selctedTintColor
                            unselctedTintColor:(UIColor * _Nonnull)unselctedTintColor
                            hidesForSinglePage:(BOOL) hidesForSinglePage
{
    self = [super init];
    if(self) {
        _numberOfPages = numberOfPages;
        _displayPages = displayPages;
        _selctedTintColor = selctedTintColor;
        _unselctedTintColor = unselctedTintColor;
        _hidesForSinglePage = hidesForSinglePage;
    }
    return self;
}

@end

@interface ACRPageControl()

@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, strong, nullable) ACRPageControlConfig *config;
@property (nonatomic, strong) NSMutableArray<CircularView *> *circleViewArray;
@property (nonatomic, assign) CGFloat diameter;
@property (nonatomic, assign) CGFloat spacing;
@end

@implementation ACRPageControl

-(instancetype) initWithConfig:(ACRPageControlConfig *)config
{
    self = [super initWithFrame:CGRectZero];
    _config = config;
    self.backgroundColor = [UIColor clearColor];
    
    [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    
    self.contentMode = UIViewContentModeRedraw;
    self.circleViewArray = [[NSMutableArray alloc] init];
    for(int i=0; i<config.numberOfPages;i++)
    {
        CircularView * circleView = [[CircularView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [self.circleViewArray addObject:circleView];
        [self addSubview:circleView];
    }
    self.clipsToBounds = YES;
    _diameter = 10;
    _spacing = 7;
    return self;
}

// Properties

- (CGSize)contentSize
{
    CGFloat height = _diameter;
    return CGSizeMake(self.requiredLength, height);
}

- (CGSize)intrinsicContentSize
{
    return self.shouldBeHidden ? CGSizeZero : [self contentSize];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return [self contentSize];
}

- (void)setCurrentPage:(NSInteger)currentPage
{
        _currentPage = currentPage;
    
    [UIView animateWithDuration:0.5 animations:^{
        [self updatePositions];
    }];
    
}

-(void) layoutSubviews
{
    [self updatePositions];
}

- (BOOL)shouldBeHidden
{
    return self.config.numberOfPages == 0 || (self.config.hidesForSinglePage && self.config.numberOfPages == 1) || self.config == nil;
}

- (CGFloat)requiredLength
{
    if (self.shouldBeHidden) return 0.0;
    CGFloat diameterSum = (self.displayPages - 1) * _spacing + _diameter;
    return diameterSum + MAX(0.0, (self.displayPages - 1)) * _spacing;
}

- (NSInteger)numberOfPages
{
    return self.config.numberOfPages;
}

- (NSInteger)displayPages
{
    if (self.config.displayPages) {
        return MIN(self.config.displayPages.integerValue, self.config.numberOfPages);
    }
    return self.config.numberOfPages;
}

-(void) updatePositions
{
    if (self.shouldBeHidden || [self numberOfPages] <= 1) return;
    
    NSInteger visibleViewStartIndex = 0;
    BOOL leadingHalfSize = NO;
    BOOL trailingHalfSize = NO;
    
    if (self.config.displayPages && self.config.displayPages.integerValue < self.numberOfPages)
    {
            NSInteger adjustedPage = (NSInteger)((_currentPage + 1) / 3) * 3;
            NSInteger halfDisplayPages = self.config.displayPages.integerValue / 2;
            if (_currentPage <= halfDisplayPages)
            {
                visibleViewStartIndex = 0;
            } else if (adjustedPage >= self.numberOfPages - halfDisplayPages)
            {
                visibleViewStartIndex = self.numberOfPages - self.config.displayPages.integerValue;
            } else
            {
                visibleViewStartIndex = _currentPage - halfDisplayPages;
            }
        
            leadingHalfSize =  _currentPage - halfDisplayPages > 0;
            trailingHalfSize =  _currentPage + halfDisplayPages < self.numberOfPages;
    } else
    {
        visibleViewStartIndex = 0;
    }
    
    NSInteger currentPage = MIN(MAX(self.currentPage, 0), self.numberOfPages - 1);
    
    CGPoint point = CGPointMake( floor((self.bounds.size.width - self.requiredLength) / 2.0 ), 0.0);
    
    point.x -= _spacing *(visibleViewStartIndex);
    
    for(NSInteger i =0 ; i< self.numberOfPages; i++)
    {
        
        BOOL isSelectedPage = (i == currentPage);
        CGFloat scale;
        NSInteger distance = abs(i-_currentPage);
        if(distance == 0) {
            scale = 1;
        } else if(distance <=2)
        {
            scale = 0.6;
        }
        else if (distance == 3)
        {
            scale = 0.4;
        }
        else
        {
            scale = 0;
        }
        
        CGFloat diameter = _diameter * scale;
        point.y = floor((self.bounds.size.height - diameter) / 2.0);
        _circleViewArray[i].frame = CGRectMake(point.x, point.y, diameter, diameter);
        _circleViewArray[i].tintColor = isSelectedPage ? _config.selctedTintColor : _config.unselctedTintColor;
        
        CGFloat offset =  _spacing + diameter;
        
        point.x += offset;
    }
}

@end
