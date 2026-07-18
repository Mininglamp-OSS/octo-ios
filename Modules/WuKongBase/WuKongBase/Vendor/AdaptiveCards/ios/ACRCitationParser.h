//
//  ACRCitationParser.h
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 29/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACOEnums.h"

@protocol ACRCitationParserDelegate;
@protocol ACICitationPresenter;
@class ACRViewTextAttachment;
@class ACOReference;
@class ACOCitation;

NS_ASSUME_NONNULL_BEGIN

// Associated object keys — exposed so tests can verify stored values.
// Using address of static char gives a unique, stable pointer across all dylibs.
FOUNDATION_EXTERN const char kACRCitationKey;
FOUNDATION_EXTERN const char kACRReferenceDataKey;
FOUNDATION_EXTERN const char kACRPresenterKey;

/**
 * Abstract base class for citation parsing strategies
 * Subclasses implement specific parsing logic for different input formats (TextBlock vs RichTextBlock)
 */
@interface ACRCitationParser : NSObject

@property (nonatomic, weak, nullable) id<ACRCitationParserDelegate> delegate;

/**
 * The presenter stored per-button via associated object at attachment-creation time.
 * Set by ACRCitationBuilder before each parse call; stored immediately onto each
 * created UIButton so tap events route to the correct presenter per card instance.
 */
@property (nonatomic, weak, nullable) id<ACICitationPresenter> presenter;

/**
 * Initialize the parser with a delegate
 * @param delegate The delegate that will receive parsing events
 * @return Initialized parser instance
 */
- (instancetype)initWithDelegate:(id<ACRCitationParserDelegate>)delegate;

/**
 * Abstract method to parse an attributed string and return a new one with citation attachments
 * Subclasses must override this method
 * @param attributedString The input attributed string to parse
 * @param references Array of ACOReference objects for citations
 * @return A new attributed string with citations replaced by text attachments
 */
- (NSMutableAttributedString *)parseAttributedString:(NSAttributedString *)attributedString 
                                      withReferences:(NSArray<ACOReference *> *)references
                                               theme:(ACRTheme)theme;

/**
 * Abstract method to parse a citation object and create an attributed string with citation attachment
 * Subclasses must override this method
 * @param citation ACOCitation object containing displayText and referenceIndex
 * @param references Array of ACOReference objects for citations
 * @return NSAttributedString containing the citation attachment
 */
- (NSAttributedString *)parseAttributedStringWithCitation:(ACOCitation *)citation 
                                            andReferences:(NSArray<ACOReference *> *)references;

/**
 * Concrete helper method to create a default citation attributed string with attachment
 * Subclasses can use this as a base implementation or create their own custom styling
 * @param citation ACOCitation object containing displayText and referenceIndex
 * @param referenceData ACOReference object containing the full reference information
 * @return NSAttributedString containing the citation attachment with default styling
 */
- (ACRViewTextAttachment *)createAttachmentWithCitation:(ACOCitation *)citation 
                                          referenceData:(ACOReference *)referenceData;

/**
 * Helper method to find a reference by its index in the references array
 * @param referenceId NSNumber containing the reference index
 * @param references Array of ACOReference objects to search through
 * @return ACOReference object if found, nil otherwise
 */
- (nullable ACOReference *)findReferenceByIndex:(nullable NSNumber *)referenceId 
                                   inReferences:(nullable NSArray<ACOReference *> *)references;

@end

NS_ASSUME_NONNULL_END
