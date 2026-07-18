//
//  ACRRatingInputDataSource.m
//  AdaptiveCards
//
//  Copyright © 2024 Microsoft. All rights reserved.
//

#import "ACRRatingInputDataSource.h"
#import "ACRColumnSetView.h"
#import "ACRIBaseCardElementRenderer.h"
#import "ACRInputLabelView.h"
#import "ACRUILabel.h"
#import "HostConfig.h"
#import <Foundation/Foundation.h>

using namespace AdaptiveCards;

@implementation ACRRatingInputDataSource
{
    NSMutableArray<CompletionHandler> *_completionHandlers;
    double _defaultValue;
}

- (instancetype)initWithInputRating:(std::shared_ptr<RatingInput> const &)ratingInput
                     WithHostConfig:(std::shared_ptr<HostConfig> const &)hostConfig
{
    self = [super init];

    self.id = [[NSString alloc] initWithCString:ratingInput->GetId().c_str()
                                       encoding:NSUTF8StringEncoding];
    self.hasValidationProperties = self.isRequired;
    _defaultValue = ratingInput->GetValue();
    _completionHandlers = [[NSMutableArray alloc] init];
    return self;
}

- (BOOL)validate:(NSError * __autoreleasing *)error
{
    if (self.isRequired) {
        return [_ratingView getValue] != 0;
    }
    return YES;
}

- (void)getInput:(NSMutableDictionary *)dictionary
{
    dictionary[self.id] = @([_ratingView getValue]);
}

- (void)setFocus:(BOOL)shouldBecomeFirstResponder view:(UIView *)view
{
    [ACRInputLabelView commonSetFocus:shouldBecomeFirstResponder view:_ratingView];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _ratingView);
}

- (void)addObserverWithCompletion:(CompletionHandler)completion
{
    _ratingView.ratingValueChangeDelegate = self;
    [_completionHandlers addObject:completion];
}

- (void)resetInput { 
    [_ratingView setValue:(NSInteger)_defaultValue];
}


- (void)didChangeValueTo:(NSInteger)newValue {
    for(CompletionHandler completion in _completionHandlers) {
        completion();
    }
}

@synthesize isRequired;
@synthesize hasValidationProperties;
@synthesize hasVisibilityChanged;



@end
