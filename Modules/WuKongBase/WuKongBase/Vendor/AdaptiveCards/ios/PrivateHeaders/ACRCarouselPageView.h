//
//  ACRCarouselPageView.h
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOHostConfig.h"
#import "ACRContentStackView.h"
#import "ACRView.h"
#import <UIKit/UIKit.h>

@interface ACRCarouselPageView : NSObject

-(UIView *) render:(UIView<ACRIContentHoldingView> *)viewGroup
                         rootView:(ACRView *)rootView
                           inputs:(NSMutableArray *)inputs
                  baseCardElement:(ACOBaseCardElement *)acoElem
                       hostConfig:(ACOHostConfig *)acoConfig;
@end
