//
//  ACRPopoverTarget.h
//  AdaptiveCards
//
//  Created by Jitisha Azad on 01/07/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACOInputResults.h"
#import "ACRBaseTarget.h"
#import <AdaptiveCards/ACOInputResults.h>
#import <AdaptiveCards/ACRBaseTarget.h>

#import "ACRIContentHoldingView.h"
#import "ACRView.h"
#import <UIKit/UIKit.h>

@interface ACRPopoverTarget : ACRBaseTarget

- (instancetype)initWithActionElement:(ACOBaseActionElement *)actionElement rootView:(ACRView *)rootView;

- (IBAction)send:(UIButton *)sender;

@end
