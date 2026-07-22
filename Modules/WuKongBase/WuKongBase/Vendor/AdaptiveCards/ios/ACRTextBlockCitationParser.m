//
//  ACRTextBlockCitationParser.m
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 29/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRTextBlockCitationParser.h"
#import "ACRViewTextAttachment.h"
#import "ACOCitation.h"

@class ACOReference;

@implementation ACRTextBlockCitationParser

- (NSMutableAttributedString *)parseAttributedString:(NSAttributedString *)attributedString
                                      withReferences:(NSArray<ACOReference *> *)references
                                               theme:(ACRTheme)theme
{
    NSMutableAttributedString *result = [attributedString mutableCopy];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSMutableArray<NSDictionary *> *replacements = [NSMutableArray array];
    
    // First: collect all matches
    [attributedString enumerateAttributesInRange:NSMakeRange(0, attributedString.length)
                                         options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                      usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange range, BOOL *stop) {
        id linkValue = attrs[NSLinkAttributeName];
        NSString *linkString = nil;
        
        if ([linkValue isKindOfClass:[NSURL class]]) {
            linkString = [(NSURL *)linkValue absoluteString];
        } else if ([linkValue isKindOfClass:[NSString class]]) {
            linkString = (NSString *)linkValue;
        }
        
        if ([linkString hasPrefix:@"cite:"]) {
            NSNumber *referenceId = [formatter numberFromString:[linkString substringFromIndex:5]];
            NSString *displayText = [[attributedString attributedSubstringFromRange:range] string];
            displayText = [displayText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            ACOCitation *citation = [[ACOCitation alloc] initWithDisplayText:displayText
                                                              referenceIndex:referenceId
                                                                       theme:theme];
            
            NSAttributedString *attachmentString = [self parseAttributedStringWithCitation:citation
                                                                             andReferences:references];
            
            // Store replacement info
            [replacements addObject:@{
                @"range" : [NSValue valueWithRange:range],
                @"attachment" : attachmentString
            }];
        }
    }];
    
    // Second: apply replacements (reverse order so ranges stay valid)
    for (NSDictionary *item in [replacements reverseObjectEnumerator]) {
        NSRange range = [item[@"range"] rangeValue];
        NSAttributedString *attachment = item[@"attachment"];
        [result replaceCharactersInRange:range withAttributedString:attachment];
    }
    
    return result;
}

@end
