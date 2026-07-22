//
//  ARCGridViewLayout.h
//  AdaptiveCards
//
//  Created by hiteshkumar on 07/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "AreaGridLayout.h"
#import "ACRIContentHoldingView.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/AreaGridLayout.h>
#import <AdaptiveCards/ACRIContentHoldingView.h>
#endif

#import <UIKit/UIKit.h>

/*!
 @class ARCGridViewLayout
 @abstract This class handles arrangenment of items in  Area grid layout.
*/
@interface ARCGridViewLayout : UIView<ACRIContentHoldingView>

/**
 * Initializes a ARCGridViewLayout instance with a specific parameter.
 *
 * @param gridLayout Area grid layout meta data for container.
 * @param style style needed for this container.
 * @param parentStyle style needed for parent of this container.
 * @param acoConfig Host config object.
 * @param superview superView of this container where it will be rendered..
 * @return An ARCGridViewLayout MyClass object.
 */
- (instancetype)initWithGridLayout:(std::shared_ptr<AdaptiveCards::AreaGridLayout> const &)gridLayout
                             style:(ACRContainerStyle)style
                       parentStyle:(ACRContainerStyle)parentStyle
                        hostConfig:(ACOHostConfig *)acoConfig
                         superview:(UIView *)superview;

@end
