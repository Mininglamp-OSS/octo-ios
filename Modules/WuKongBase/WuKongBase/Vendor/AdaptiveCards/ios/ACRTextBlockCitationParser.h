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
 * Parser for TextBlock citations using regex-based pattern matching
 * Handles citations in the format "[displayText](cite:referenceId)"
 * This is the primary parser used for text content with embedded citation markup
 */
@interface ACRTextBlockCitationParser : ACRCitationParser

@end

NS_ASSUME_NONNULL_END