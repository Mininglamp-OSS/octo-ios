//
//  ACRCitationBuilderDelegate.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 29/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class ACRCitationBuilder;
@class ACOReference;
@class ACOCitation;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for ACRCitationBuilder to provide analytics callbacks on citation taps.
 */
@protocol ACRCitationBuilderDelegate <NSObject>

@optional

/**
 * Called when a citation is about to be presented
 * @param citationId The ID of the citation being presented
 * @param referenceData The reference data for the citation
 */
- (void)citationWillPresent:(NSString *)citationId referenceData:(ACOReference * _Nullable)referenceData;

/**
 * Called when a citation presentation is dismissed
 * @param citationId The ID of the citation that was dismissed
 */
- (void)citationDidDismiss:(NSString *)citationId;

/**
 * Called when a citation button is tapped
 * @param citationBuilder The citation builder handling the tap
 * @param citation ACOCitation object containing citation information
 * @param referenceData ACOReference object containing full reference information
 */
- (void)citationBuilder:(ACRCitationBuilder *)citationBuilder
         didTapCitation:(ACOCitation *)citation
          referenceData:(ACOReference * _Nullable)referenceData;

@end

NS_ASSUME_NONNULL_END
