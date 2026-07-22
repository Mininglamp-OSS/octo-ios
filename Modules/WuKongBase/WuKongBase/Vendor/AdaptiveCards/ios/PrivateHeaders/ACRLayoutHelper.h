//
//  ACRWidthDistributor.h
//  AdaptiveCards
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "ACRBaseCardElementRenderer.h"
#import "ACRIContentHoldingView.h"
#import "ACRRenderer.h"
#import "BackgroundImage.h"
#import "HostConfig.h"
#import "SharedAdaptiveCard.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/ACRBaseCardElementRenderer.h>
#import <AdaptiveCards/ACRIContentHoldingView.h>
#import <AdaptiveCards/ACRRenderer.h>
#import <AdaptiveCards/BackgroundImage.h>
#import <AdaptiveCards/HostConfig.h>
#import <AdaptiveCards/SharedAdaptiveCard.h>
#endif
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

using namespace AdaptiveCards;
@interface ACRLayoutHelper : NSObject

- (instancetype)init;
- (void)distributeWidth:(float)parentWidth
               rootView:(ACRView *)rootView
          forElement:(std::shared_ptr<AdaptiveCard> const &)card
          andHostConfig:(ACOHostConfig *)config;

- (std::shared_ptr<AdaptiveCards::Layout>)layoutToApplyFrom:(std::vector<std::shared_ptr<Layout>>)layoutArray andHostConfig:(ACOHostConfig *)config;

@end
