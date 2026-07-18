//
//  ACRTextBlockCitationParser.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 29/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRCitationParser.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Parser for TextBlock citations using regex pattern matching (e.g., "[1](cite:0)")
 */
@interface ACRInlineCitationTokenParser : ACRCitationParser

@end

NS_ASSUME_NONNULL_END
