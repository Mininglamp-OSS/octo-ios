//
//  ACRSVGImageView.h
//  AdaptiveCards
//
//  Created by Abhishek on 26/04/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACOBaseCardElement.h"
#import "ACOHostConfig.h"
#import "ACOEnums.h"
#import <UIKit/UIKit.h>

@interface ACRSVGImageView : UIImageView

@property UIColor *svgTintColor;
@property UIImage *svgImage;
@property CGSize size;

- (instancetype)init:(NSString *)iconURL
                 rtl:(ACRRtl)rtl
            isFilled:(BOOL)isFilled
                size:(CGSize)size
           tintColor:(UIColor *)tintColor;

+ (void)requestIcon:(NSString *)iconURL
             filled:(BOOL)filled
               size:(CGSize)size
                rtl:(ACRRtl)rtl
         completion:(void (^)(UIImage *))completion;

@end
