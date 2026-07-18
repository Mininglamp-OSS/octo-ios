//
//  ACRRatingInputDataSource.h
//  AdaptiveCards
//
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "ACOBaseCardElement.h"
#import "ACRColumnSetView.h"
#import "ACRIBaseCardElementRenderer.h"
#import "ACRIBaseInputHandler.h"
#import "HostConfig.h"
#import "RatingInput.h"
#import "ACRRatingView.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/ACOBaseCardElement.h>
#import <AdaptiveCards/ACRColumnSetView.h>
#import <AdaptiveCards/ACRIBaseCardElementRenderer.h>
#import <AdaptiveCards/ACRIBaseInputHandler.h>
#import <AdaptiveCards/HostConfig.h>
#import <AdaptiveCards/RatingInput.h>
#import <AdaptiveCards/ACRRatingView.h>
#endif

@interface ACRRatingInputDataSource : NSObject <ACRIBaseInputHandler, ACRRatingValueChangeDelegate>

@property NSString *id;
@property (weak) ACRRatingView *ratingView;

- (instancetype)initWithInputRating:(std::shared_ptr<AdaptiveCards::RatingInput> const &)ratingInput
                     WithHostConfig:(std::shared_ptr<AdaptiveCards::HostConfig> const &)hostConfig;
@end


