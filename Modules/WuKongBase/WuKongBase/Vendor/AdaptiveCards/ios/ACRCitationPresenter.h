//
//  ACRCitationPresenter.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 25/03/26.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ACICitationPresenter.h"

@class ACOHostConfig;
@protocol ACRActionDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Handles all UIKit presentation concerns for citations:
 * - First-level bottom sheet (citation reference view)
 * - Second-level bottom sheet (full detail card via ACRRenderer)
 *
 * Conforms to ACICitationPresenter and is the concrete type returned by ACRView.citationPresenter.
 * Has no dependency on ACRView or ACRCitationBuilder internals.
 */
@interface ACRCitationPresenter : NSObject <ACICitationPresenter>

/**
 * @param hostConfig  Configures ACRBottomSheetConfiguration and ACRRenderer. If nil, defaults to a new empty config.
 * @param actionDelegate  Used in handleCitationTap: to resolve the active UIViewController. Held weakly.
 */
- (instancetype)initWithHostConfig:(nullable ACOHostConfig *)hostConfig
                    actionDelegate:(id<ACRActionDelegate>)actionDelegate NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
