//
//  ACRCarouselPageContainerView.h
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOHostConfig.h"
#import "ACRContentStackView.h"
#import "ACRView.h"
#import <UIKit/UIKit.h>

@interface ACRCarouselPageContainerView : UIView

-(instancetype) initWithCarouselPageViewList:(NSMutableArray<UIView *> *)initWithCarouselPageViewList pageAnimation:(PageAnimation) pageAnimation;
-(void) setCurrentPage:(NSInteger) page;

@end
