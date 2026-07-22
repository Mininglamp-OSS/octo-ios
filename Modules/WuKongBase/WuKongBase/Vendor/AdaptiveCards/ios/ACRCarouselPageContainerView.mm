//
//  ACRCarouselPageContainerView.mm
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElementPrivate.h"
#import "ACRCarouselPageContainerView.h"

@interface ACRCarouselPageContainerView()

@property NSMutableArray<UIView *> *carouselPageViewList;
@property PageAnimation pageAnimation;
@property NSInteger carouselPageViewIndex;

@end

@implementation ACRCarouselPageContainerView

-(instancetype) initWithCarouselPageViewList:(NSMutableArray<UIView *> *)carouselPageViewList pageAnimation:(PageAnimation) pageAnimation
{
    self = [super init];
    self.carouselPageViewList = carouselPageViewList;
    self.pageAnimation = pageAnimation;
    self.carouselPageViewIndex = 0;
    
    for(UIView *carouselPageView in carouselPageViewList)
    {
        carouselPageView.translatesAutoresizingMaskIntoConstraints = NO;
        carouselPageView.clipsToBounds = YES;
        carouselPageView.hidden = YES;
        [self addSubview:carouselPageView];
        [NSLayoutConstraint activateConstraints:@[
            [carouselPageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [carouselPageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [carouselPageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [carouselPageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [self.heightAnchor constraintGreaterThanOrEqualToAnchor:carouselPageView.heightAnchor]
        ]];
    }
    if(carouselPageViewList.count > 0)
    {
        carouselPageViewList[0].hidden = NO;
    }
    self.clipsToBounds = YES;
    
    return self;
}

-(void) setCurrentPage:(NSInteger) page
{
    if(page < 0 || (NSUInteger)page >= _carouselPageViewList.count)
    {
        return;
    }
    
    if(page != _carouselPageViewIndex -1 && page != _carouselPageViewIndex + 1)
    {
        /// support transition to next page or previous page only
        return;
    }
    
    UIView *oldView = _carouselPageViewList[_carouselPageViewIndex];
    UIView *newView = _carouselPageViewList[page];
    
    switch (_pageAnimation)
    {
        case PageAnimation::Slide:
            if(page == _carouselPageViewIndex - 1)
            {
                /// right swipe
                [self slideAnimationForRightSwipeForViewToHide:oldView showView:newView];
            }
            else if(page == _carouselPageViewIndex + 1)
            {
                /// left swipe
                [self slideAnimationForLeftSwipeForViewToHide:oldView showView:newView];
            }
            break;
        case PageAnimation::CrossFade:
            [self crossfadeFromView:oldView toView:newView];
            break;
        case PageAnimation::None:
            oldView.hidden = YES;
            newView.hidden = NO;
            break;
        default:
            break;
    }
    _carouselPageViewIndex = page;
}

- (void)crossfadeFromView:(UIView *)fromView toView:(UIView *)toView
{
    
    [UIView transitionWithView:fromView.superview
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        fromView.hidden = YES;  // Hide the current view
                        toView.hidden = NO;    // Show the next view
                    }
                    completion:nil];
}

- (void)slideAnimationForLeftSwipeForViewToHide:(UIView *)viewToHide showView:(UIView *)viewToShow
{
    // Prepare the view to show
    viewToShow.transform = CGAffineTransformMakeTranslation(viewToShow.bounds.size.width, 0);
    viewToShow.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        // Slide out the current view
        viewToHide.transform = CGAffineTransformMakeTranslation(-viewToHide.bounds.size.width, 0);
        
        // Slide in the new view
        viewToShow.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        viewToHide.hidden = YES;
        viewToHide.transform = CGAffineTransformIdentity; // Reset transform for future use
    }];
}

- (void)slideAnimationForRightSwipeForViewToHide:(UIView *)viewToHide showView:(UIView *)viewToShow
{
    // Prepare the view to show
    viewToShow.transform = CGAffineTransformMakeTranslation(-viewToShow.bounds.size.width, 0);
    viewToShow.hidden = NO;
    [UIView animateWithDuration:0.3 animations:^{
        // Slide out the current view
        viewToHide.transform = CGAffineTransformMakeTranslation(viewToHide.bounds.size.width, 0);

        // Slide in the new view
        viewToShow.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        viewToHide.hidden = YES;
        viewToHide.transform = CGAffineTransformIdentity; // Reset transform for future use
    }];
}

@end
