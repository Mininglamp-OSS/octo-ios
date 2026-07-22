//
//  ACRCitationReferenceView.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 31/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACOReference;
@class ACOCitation;
@class ACRCitationReferenceView;

NS_ASSUME_NONNULL_BEGIN

@protocol ACRCitationReferenceViewDelegate <NSObject>

@optional
/**
 * Called when the user taps the "More details" button
 * @param citationReferenceView The view that triggered the event
 * @param citation The citation associated with the reference
 * @param reference The reference containing the content/URL to show
 */
- (void)citationReferenceView:(ACRCitationReferenceView *)citationReferenceView
         didTapMoreDetailsForCitation:(ACOCitation *)citation
                            reference:(ACOReference *)reference;

@end


/**
 * A custom UIView that renders a citation reference with a numbered pill, icon, title, keywords, and description
 * Designed to match the bottom sheet citation reference layout
 */
@interface ACRCitationReferenceView : UIView

/**
 * The reference data to display
 */
@property (nonatomic, strong) ACOReference *reference;

/**
 * The citation containing the display text for the pill
 */
@property (nonatomic, strong) ACOCitation *citation;

/**
 * The delegate to handle user interactions
 */
@property (nonatomic, weak) id<ACRCitationReferenceViewDelegate> delegate;

/**
 * Initialize with a citation and reference
 * @param citation The ACOCitation object containing the display text for the pill
 * @param reference The ACOReference object containing the data to display
 */
- (instancetype)initWithCitation:(ACOCitation *)citation reference:(ACOReference *)reference;

/**
 * Update the view with new citation and reference data
 * @param citation The ACOCitation object containing the display text for the pill
 * @param reference The ACOReference object containing the data to display
 */
- (void)updateWithCitation:(ACOCitation *)citation reference:(ACOReference *)reference;

@end

NS_ASSUME_NONNULL_END
