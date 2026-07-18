//
//  ACRSVGIconHoldingView.h
//  AdaptiveCards
//
//  Created by Abhishek on 29/04/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElement.h"
#import "ACOHostConfig.h"
#import "ACOEnums.h"
#import <UIKit/UIKit.h>

@interface ACRSVGIconHoldingView : UIView

- (instancetype)init:(UIImageView *)imageView
                size:(CGSize)size;

@end
