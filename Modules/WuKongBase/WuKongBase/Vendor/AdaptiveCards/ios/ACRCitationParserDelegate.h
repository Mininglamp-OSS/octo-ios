//
//  ACRCitationParserDelegate.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 30/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ACOReference;
@class ACOCitation;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for citation parser to communicate back to its manager
 */
@protocol ACRCitationParserDelegate <NSObject>

/**
 * Called when a citation button is tapped
 * @param citation ACOCitation object containing citation information
 * @param referenceData ACOReference object containing full reference information
 */
- (void)citationParser:(id)parser 
      didTapCitation:(ACOCitation *)citation 
       referenceData:(ACOReference * _Nullable)referenceData;

@end

NS_ASSUME_NONNULL_END