//
//  ACRFlowLayout.h
//  AdaptiveCards
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "FlowLayout.h"
#import "ACRIContentHoldingView.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/FlowLayout.h>
#import <AdaptiveCards/ACRIContentHoldingView.h>
#endif

/*!
 @class ACRFlowLayout
 @abstract This class handles arrangenment of items in flow layout.
*/
@interface ACRFlowLayout: UIView<ACRIContentHoldingView>

/**
 * Initializes a ACRFlowLayout instance with a specific parameter.
 *
 * @param flowLayout flow layout meta data for container.
 * @param style style needed for this container.
 * @param parentStyle style needed for parent of this container.
 * @param acoConfig Host config object.
 * @param maxWidth Max width this container can take.
 * @param superview superView of this container where it will be rendered..
 * @return An ACRFlowLayout MyClass object.
 */
- (instancetype)initWithFlowLayout:(std::shared_ptr<AdaptiveCards::FlowLayout> const &)flowLayout
                             style:(ACRContainerStyle)style
                       parentStyle:(ACRContainerStyle)parentStyle
                        hostConfig:(ACOHostConfig *)acoConfig
                          maxWidth:(CGFloat)maxWidth
                         superview:(UIView *)superview;

@end

