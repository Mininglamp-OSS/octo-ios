//
//  ACICitationPresenter.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 25/03/26.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ACOCitation.h"
#import "ACOReference.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Public protocol for presenting citation bottom sheets.
 * Adopt this protocol to present citation reference details without depending on internal implementation.
 *
 * Both methods are required:
 * - handleCitationTap: is called by the native card tap path (parser fires it; conformer resolves the UIViewController internally).
 * - presentBottomSheetFrom: is called by the web-rendering path (caller provides the UIViewController directly).
 */
@protocol ACICitationPresenter <NSObject>

/**
 * Native card path: called when a citation pill is tapped in a rendered card.
 * The conformer is responsible for resolving the active UIViewController (e.g. via its stored actionDelegate).
 * @param citation The citation that was tapped
 * @param referenceData The reference data for the citation
 */
- (void)handleCitationTap:(ACOCitation *)citation
            referenceData:(ACOReference * _Nullable)referenceData;

/**
 * Web-rendering path: called when the caller has already resolved the active view controller.
 * @param activeController The view controller from which to present the sheet
 * @param citation The citation that was tapped
 * @param referenceData The reference data for the citation
 */
- (void)presentBottomSheetFrom:(UIViewController *)activeController
                didTapCitation:(ACOCitation *)citation
                 referenceData:(ACOReference * _Nullable)referenceData;

@end

NS_ASSUME_NONNULL_END
