//
//  ACRInputToggleView.h
//  AdaptiveCards
//
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import "ACOBaseCardElement.h"
#import "ACRIBaseInputHandler.h"
#import <UIKit/UIKit.h>
#import "ACRView.h"

@protocol ACRRatingValueChangeDelegate

-(void)didChangeValueTo:(NSInteger)newValue;

@end

@interface ACRRatingView : UIView

@property (weak) id<ACRRatingValueChangeDelegate> ratingValueChangeDelegate;

- (instancetype)initWithEditableValue:(double)value
                                  max:(NSInteger)max
                                 size:(ACRRatingSize)size
                          ratingColor:(ACRRatingColor)ratingColor
                           hostConfig:(ACOHostConfig *)hostConfig;

- (instancetype)initWithReadonlyValue:(double)value
                                  max:(NSInteger)max
                                 size:(ACRRatingSize)size
                          ratingColor:(ACRRatingColor)ratingColor
                                style:(ACRRatingStyle)style
                                count:(NSInteger)count
                           hostConfig:(ACOHostConfig *)hostConfig;

- (NSInteger)getValue;
- (void)setValue:(NSInteger)value;
- (NSArray *)accessibleChildren;


@end

