//
//  NSAttributedString+Markdown.m
//  Tot
//
//  Created by Craig Hockenberry on 12/14/19.
//  Copyright © 2020 The Iconfactory. All rights reserved.
//
/*
    Copyright (c) 2020 The Iconfactory, Inc. <https://iconfactory.com>
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT WKITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
 */

// NOTE: Since the parser makes a pass over the source Markdown for each marker, turning off the ALLOW configuration items
// below will improve performance slightly.

#define ALLOW_LINKS 1            // CONFIGURATION - When enabled, inline and automatic links in Markdown will be converted to rich text attributes.
#define ALLOW_ALTERNATES 1        // CONFIGURATION - When enabled, alternate Markdown such as * for single emphasis and __ for double will be converted.
#define ALLOW_ALL_LITERALS 1    // CONFIGURATION - When enabled, backslash escapes for all of Markdown's literal characters will be removed when converting to rich text. Otherwise it's a minimal set (just for emphasis and escapes).

#define ESCAPE_ALL_LITERALS 0    // CONFIGURATION - When ALLOW\_ALL\_LITERALS is enabled, ESCAPE\_ALL\_LITERALS converts all literals in rich text \(including punctuation\!\)\. You'll probably find this irritating\.
                                // Not only is text harder to read \- it breaks many of the tests\.

#define LOG_CONVERSIONS 0        // CONFIGURATION - When enabled, debug logging will include string conversion details.

#import "NSAttributedString+Markdown.h"

#if TARGET_OS_OSX

#define FONT_CLASS NSFont
#define FONT_DESCRIPTOR_CLASS NSFontDescriptor
#define FONT_DESCRIPTOR_SYMBOLIC_TRAITS NSFontDescriptorSymbolicTraits
#define FONT_DESCRIPTOR_TRAIT_BOLD NSFontDescriptorTraitBold
#define FONT_DESCRIPTOR_TRAIT_ITALIC NSFontDescriptorTraitItalic
#define FONT_DESCRIPTOR_CLASS_SYMBOLIC NSFontDescriptorClassSymbolic
#define FONT_DESCRIPTOR_FAMILY_ATTRIBUTE NSFontFamilyAttribute

#else

#define FONT_CLASS UIFont
#define FONT_DESCRIPTOR_CLASS UIFontDescriptor
#define FONT_DESCRIPTOR_SYMBOLIC_TRAITS UIFontDescriptorSymbolicTraits
#define FONT_DESCRIPTOR_TRAIT_BOLD UIFontDescriptorTraitBold
#define FONT_DESCRIPTOR_TRAIT_ITALIC UIFontDescriptorTraitItalic
#define FONT_DESCRIPTOR_CLASS_SYMBOLIC UIFontDescriptorClassSymbolic
#define FONT_DESCRIPTOR_FAMILY_ATTRIBUTE UIFontDescriptorFamilyAttribute

#endif

#ifdef DEBUG
    #define DebugLog(...) NSLog(__VA_ARGS__)
#else
    #define DebugLog(...) do {} while (0)
#endif

NSString *const literalBackslash = @"\\";
NSString *const literalAsterisk = @"*";
NSString *const literalUnderscore = @"_";

#if ALLOW_ALL_LITERALS
NSString *const literalBacktick = @"`";
NSString *const literalCurlyBraceOpen = @"{";
NSString *const literalCurlyBraceClose = @"}";
NSString *const literalSquareBracketOpen = @"[";
NSString *const literalSquareBracketClose = @"]";
NSString *const literalParenthesesOpen = @"(";
NSString *const literalParenthesesClose = @")";
NSString *const literalHashMark = @"#";
NSString *const literalPlusSign = @"+";
NSString *const literalMinusSign = @"-";
NSString *const literalDot = @".";
NSString *const literalExclamationPoint = @"!";
#endif

@implementation NSCharacterSet (Markdown)

+ (NSCharacterSet *)markdownLiteralCharacterSet {
    NSMutableString *characters = [NSMutableString string];
    [characters appendString:literalBackslash];
    [characters appendString:literalAsterisk];
    [characters appendString:literalUnderscore];

#if ALLOW_ALL_LITERALS
    [characters appendString:literalBacktick];
    [characters appendString:literalCurlyBraceOpen];
    [characters appendString:literalCurlyBraceClose];
    [characters appendString:literalSquareBracketOpen];
    [characters appendString:literalSquareBracketClose];
    [characters appendString:literalParenthesesOpen];
    [characters appendString:literalParenthesesClose];
    [characters appendString:literalHashMark];
    [characters appendString:literalPlusSign];
    [characters appendString:literalMinusSign];
    [characters appendString:literalDot];
    [characters appendString:literalExclamationPoint];
#endif
    
    return [NSCharacterSet characterSetWithCharactersInString:characters];
}

@end

NSString *const UTTypeMarkdown = @"net.daringfireball.markdown";

MarkdownStyleKey MarkdownStyleEmphasisSingle = @"MarkdownStyleEmphasisSingle";
MarkdownStyleKey MarkdownStyleEmphasisDouble = @"MarkdownStyleEmphasisDouble";
MarkdownStyleKey MarkdownStyleEmphasisBoth = @"MarkdownStyleEmphasisBoth";

MarkdownStyleKey MarkdownStyleLink = @"MarkdownStyleLink";

#if ALLOW_CODE_MARKERS
MarkdownStyleKey MarkdownStyleCode = @"MarkdownStyleCode";
#endif

@implementation NSAttributedString (Markdown)

NSString *const visualLineBreak = @"\n\n";

NSString *const linkInlineStart = @"[";
NSString *const linkInlineStartDivider = @"]";
NSString *const linkInlineEndDivider = @"(";
NSString *const linkInlineEnd = @")";

NSString *const linkAutomaticStart = @"<";
NSString *const linkAutomaticEnd = @">";

NSString *const emphasisSingleStart = @"_";
NSString *const emphasisSingleEnd = @"_";
#if ALLOW_ALTERNATES
NSString *const emphasisSingleAlternateStart = @"*";
NSString *const emphasisSingleAlternateEnd = @"*";
#endif

NSString *const emphasisDoubleStart = @"**";
NSString *const emphasisDoubleEnd = @"**";
#if ALLOW_ALTERNATES
NSString *const emphasisDoubleAlternateStart = @"__";
NSString *const emphasisDoubleAlternateEnd = @"__";
#endif

#if ALLOW_CODE_MARKERS
NSString *const codeStart = @"`";
NSString *const codeEnd = @"`";
#endif

const unichar escapeCharacter = '\\';
const unichar spaceCharacter = ' ';
const unichar tabCharacter = '\t';
const unichar newlineCharacter = '\n';

typedef enum {
    MarkdownSpanUnknown = -1,
    MarkdownSpanEmphasisSingle = 0,
    MarkdownSpanEmphasisDouble,
    MarkdownSpanLinkInline,
    MarkdownSpanLinkAutomatic,
    MarkdownSpanCode, // not supported
} MarkdownSpanType;

static BOOL hasCharacterRelative(NSString *string, NSRange range, NSInteger offset, unichar character)
{
    BOOL hasCharacter = NO;
    
    NSUInteger index = range.location + offset;
    if (index >= 0 && index < string.length) {
        if ([string characterAtIndex:index] == character) {
            hasCharacter = YES;
        }
    }
    
    return hasCharacter;
}

static void addTrait(FONT_DESCRIPTOR_SYMBOLIC_TRAITS newFontTrait, NSMutableAttributedString *result, NSRange replacementRange)
{
    [result enumerateAttribute:NSFontAttributeName inRange:replacementRange options:(0) usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        FONT_CLASS *font = value;
        
        NSString *familyName = font.familyName;
        CGFloat fontSize = font.pointSize;
        FONT_DESCRIPTOR_CLASS *familyFontDescriptor = [FONT_DESCRIPTOR_CLASS fontDescriptorWithFontAttributes:@{ FONT_DESCRIPTOR_FAMILY_ATTRIBUTE: familyName}];
        
        FONT_DESCRIPTOR_SYMBOLIC_TRAITS currentSymbolicTraits = font.fontDescriptor.symbolicTraits;
        FONT_DESCRIPTOR_SYMBOLIC_TRAITS newSymbolicTraits = currentSymbolicTraits | newFontTrait;
        
        FONT_DESCRIPTOR_CLASS *replacementFontDescriptor = [familyFontDescriptor fontDescriptorWithSymbolicTraits:newSymbolicTraits];
        FONT_CLASS *replacementFont = [FONT_CLASS fontWithDescriptor:replacementFontDescriptor size:fontSize];
        
        [result removeAttribute:NSFontAttributeName range:range];
        if (replacementFont) {
            [result addAttribute:NSFontAttributeName value:replacementFont range:range];
        }
    }];
}

static void replaceAttributes(MarkdownSpanType spanType, NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *styleAttributes, NSMutableAttributedString *result, NSRange replacementRange)
{
    [result enumerateAttributesInRange:replacementRange options:(0) usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes, NSRange range, BOOL * _Nonnull stop) {
        
        NSDictionary<NSAttributedStringKey, id> *replacementAttributes = nil;
        
        MarkdownStyleKey checkKey = nil;
        MarkdownStyleKey replacementKey = nil;
        
        if (spanType == MarkdownSpanEmphasisSingle) {
            checkKey = MarkdownStyleEmphasisDouble;
            replacementKey = MarkdownStyleEmphasisSingle;
        }
        else  if (spanType == MarkdownSpanEmphasisDouble) {
            checkKey = MarkdownStyleEmphasisSingle;
            replacementKey = MarkdownStyleEmphasisDouble;
        }

        if (checkKey && replacementKey) {
            NSDictionary<NSAttributedStringKey, id> *checkAttributes = styleAttributes[checkKey];
            BOOL hasExistingAttributes = YES;
            for (NSAttributedStringKey key in checkAttributes.allKeys) {
                if (! [checkAttributes[key] isEqual:attributes[key]]) {
                    hasExistingAttributes = NO;
                }
            }
            if (hasExistingAttributes) {
                // check attributes are present, replace with attributes for both kinds of emphasis
                replacementAttributes = styleAttributes[MarkdownStyleEmphasisBoth];
            }
            else {
                replacementAttributes = styleAttributes[replacementKey];
            }
            
            if (replacementAttributes) {
                for (NSAttributedStringKey key in replacementAttributes.allKeys) {
                    [result removeAttribute:key range:range];
                }
                [result addAttributes:replacementAttributes range:range];
            }
        }
    }];
}

static void updateAttributedString(NSMutableAttributedString *result, NSString *beginMarker, NSString *dividerMarker, NSString *endMarker, MarkdownSpanType spanType, NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *styleAttributes)
{
    NSStringCompareOptions options = 0;

    // see the note below about these two variables
    NSString *scanString = [result.string copy];
    NSUInteger mutationOffset = 0;
    
    // check the input for horizontal rules and ignore markers that occur within their line's range
    NSMutableArray *horizontalRuleRangeValues = [NSMutableArray array];
    NSString *rulerString = [beginMarker substringToIndex:1];
    if ([rulerString isEqual:literalAsterisk] || [rulerString isEqual:literalUnderscore]) {
        NSRange checkRange = NSMakeRange(0, 1);
        while (checkRange.location + checkRange.length < scanString.length) {
            NSRange lineRange = [scanString lineRangeForRange:checkRange];
            NSString *lineString = [scanString substringWithRange:lineRange];
            
            // NOTE: The Markdown syntax specifies three or more characters, but for our purposes, it's more than one of an asterisk or underline.
            NSString *compressedString = [lineString stringByReplacingOccurrencesOfString:rulerString withString:@""];
            NSString *trimmedString = [compressedString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (trimmedString.length == 0) {
                [horizontalRuleRangeValues addObject:[NSValue valueWithRange:lineRange]];
            }
            
            checkRange = NSMakeRange(lineRange.location + lineRange.length, 1);
        }
    }

#if LOG_CONVERSIONS
    DebugLog(@"%s <<<< ---- '%@ %@ %@' start", "NSAttributedString+Markdown", (beginMarker ? beginMarker : @""), (dividerMarker ? dividerMarker : @""), (endMarker ? endMarker : @""));
#endif
        
    BOOL abortScan = NO;
    NSUInteger scanIndex = 0;
    while ((! abortScan) && (scanIndex < scanString.length)) {
        NSRange beginRange = [scanString rangeOfString:beginMarker options:options range:NSMakeRange(scanIndex, scanString.length - scanIndex)];
        if (beginRange.length > 0) {
            // found potential begin marker
            
            BOOL skipEscapedMarker = hasCharacterRelative(scanString, beginRange, -1, escapeCharacter);
            BOOL skipLiteralOrListMarker = NO;
            if (beginRange.length == 1) {
                BOOL hasPrefixStartOfLine = beginRange.location == 0 || hasCharacterRelative(scanString, beginRange, -1, newlineCharacter);
                BOOL hasPrefixSpace = hasCharacterRelative(scanString, beginRange, -1, spaceCharacter);
                BOOL hasSuffixSpace = hasCharacterRelative(scanString, beginRange, +1, spaceCharacter);
                BOOL hasPrefixTab = hasCharacterRelative(scanString, beginRange, -1, tabCharacter);
                BOOL hasSuffixTab = hasCharacterRelative(scanString, beginRange, +1, tabCharacter);
                if ((hasPrefixStartOfLine || hasPrefixSpace || hasPrefixTab) && (hasSuffixSpace || hasSuffixTab)) {
                    skipLiteralOrListMarker = YES;
                }
            }
            BOOL skipLinkedText = NO;
            NSUInteger mutatedIndex = beginRange.location - mutationOffset;
            if (mutatedIndex >= 0 && mutatedIndex < result.length) {
                if ([result attribute:NSLinkAttributeName atIndex:mutatedIndex effectiveRange:nil] != nil) {
                    skipLinkedText = YES;
                }
            }
            BOOL skipHorizontalRule = NO;
            if (horizontalRuleRangeValues.count > 0) {
                for (NSValue *horizontalRuleRangeValue in horizontalRuleRangeValues) {
                    NSRange horizontalRuleRange = horizontalRuleRangeValue.rangeValue;
                    if (NSLocationInRange(beginRange.location, horizontalRuleRange)) {
                        skipHorizontalRule = YES;
                    }
                }
            }

            if (skipEscapedMarker || skipLiteralOrListMarker || skipLinkedText || skipHorizontalRule) {
                scanIndex = beginRange.location + beginRange.length;
            }
            else {
                NSUInteger beginIndex = beginRange.location + beginRange.length;
                
                BOOL foundEndMarker = NO;
                NSRange endRange = emptyRange();
                
                BOOL abortEndScan = NO;
                NSUInteger scanEndIndex = beginIndex;
                if (scanEndIndex >= scanString.length) {
#if LOG_CONVERSIONS
                    DebugLog(@"%s <<<< .... end marker at end of string", "NSAttributedString+Markdown");
#endif
                    abortScan = YES;
                }
                while ((! abortEndScan) && (scanEndIndex < scanString.length)) {
                    BOOL continueScan = NO;

                    // look for end markers in a remaining range that's to the first visual line break (two newlines) or the end of the text
                    NSRange remainingRange = NSMakeRange(scanEndIndex, scanString.length - scanEndIndex);
                    NSRange visualLineRange = [scanString rangeOfString:visualLineBreak options:options range:remainingRange];
                    if (visualLineRange.location != NSNotFound) {
                        remainingRange = NSMakeRange(scanEndIndex, visualLineRange.location - scanEndIndex);
                    }

                    BOOL dividerMissing = NO;
                    if (dividerMarker) {
                        // if a divider was specified, make sure that the range we just captured contains it
                        NSRange dividerRange = [scanString rangeOfString:dividerMarker options:options range:remainingRange];
                        if (dividerRange.location == NSNotFound) {
                            dividerMissing = YES;
                        }
                        else {
                            // adjust the remainingRange so that it falls after a divider that's not escaped
                            BOOL hasEscapeMarker = hasCharacterRelative(scanString, dividerRange, -1, escapeCharacter);
                            if (hasEscapeMarker) {
                                dividerMissing = YES;
                            }
                            else {
                                remainingRange.length = remainingRange.length - (NSMaxRange(dividerRange) - remainingRange.location);
                                remainingRange.location = NSMaxRange(dividerRange);
                            }
                        }
                    }

                    endRange = [scanString rangeOfString:endMarker options:options range:remainingRange];
                    if (endRange.length > 0) {
                        // found potential end marker

                        if (! dividerMissing) {
                            BOOL hasEscapeMarker = hasCharacterRelative(scanString, endRange, -1, escapeCharacter);
                            BOOL hasPrefixSpace = hasCharacterRelative(scanString, endRange, -1, spaceCharacter);
                            BOOL hasSuffixSpace = hasCharacterRelative(scanString, endRange, +1, spaceCharacter);
                            if (! hasEscapeMarker && ! (hasPrefixSpace && hasSuffixSpace)) {
                                foundEndMarker = YES;
                                break;
                            }
                            if (endRange.location + endRange.length < scanString.length) {
                                continueScan = YES;
                                //scanEndIndex = endRange.location + endRange.length;
                                scanEndIndex = endRange.location + 1;
                            }
                        }
                        else {
                            // no divider in range, abort scanning for end marker, but continue scanning for begin marker at the end of the remaining range
#if LOG_CONVERSIONS
                            DebugLog(@"%s <<<< .... no divider marker in \"...%@...\"", "NSAttributedString+Markdown", [scanString substringWithRange:NSMakeRange(scanEndIndex, endRange.location - scanEndIndex)]);
#endif
                        }
                    }
                    else {
                        // no end marker, abort scanning for end marker, but continue scanning for begin marker at the end of the remaining range
#if DEBUG
#if LOG_CONVERSIONS
                        NSString *textString = [scanString substringWithRange:NSMakeRange(beginIndex - beginMarker.length, (beginIndex + 10 < scanString.length ? 10 : scanString.length - beginIndex))];
                        NSString *logString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
                        DebugLog(@"%s <<<< .... no end marker to match begin marker at \"%@...\"", "NSAttributedString+Markdown", logString);
#endif
#endif
                    }
                    
                    if (! continueScan) {
                        abortEndScan = YES;
                        scanIndex = remainingRange.location + remainingRange.length;
                    }
                }
                
                if (foundEndMarker) {
                    NSUInteger endIndex = endRange.location;

#if DEBUG
#if LOG_CONVERSIONS
                    NSString *textString = [scanString substringWithRange:NSMakeRange(beginIndex, endIndex - beginIndex)];
                    NSString *logString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
                    DebugLog(@"%s <<<<      \"%@\" (%ld)", "NSAttributedString+Markdown", logString, textString.length);
#endif
#endif

                    // NOTE: This code may be a bit too tricky for its own good: we're mutating the attributed
                    // result while keeping a copy of the unattributed original in scanString. For performance reasons,
                    // an attributed string's backing store is exposed through its string property, which makes
                    // scanning the raw string problematic.
                    //
                    // To compensate for this mutation, there is a mutationOffset that keeps a count of the number of
                    // characters removed in the result. This offset is applied to all ranges within the result.

                    BOOL replaceMarkers = NO;
                    BOOL replaceStyleAttributes = NO;
                    NSString *replacementString = nil;
                    NSDictionary<NSAttributedStringKey,id> *replacementAttributes = nil;
                    
                    NSRange mutatedMatchTextRange = NSMakeRange(beginIndex - mutationOffset, endIndex - beginIndex);
                    switch (spanType) {
                        default:
                            break;
                        case MarkdownSpanEmphasisSingle:
                            if (beginIndex != endIndex) { // leave ** and __ alone, the intent was probably not emphasis with zero width
                                replaceStyleAttributes = YES;
                                replaceMarkers = YES;
                            }
                            break;
                        case MarkdownSpanEmphasisDouble:
                            if (beginIndex != endIndex) { // leave ** and __ alone, the intent was probably not emphasis with zero width
                                replaceStyleAttributes = YES;
                                replaceMarkers = YES;
                            }
                            break;
                        case MarkdownSpanLinkInline: {
                            NSString *linkText = nil;
                            NSString *inlineLink = nil;
                            NSString *matchString = [result.string substringWithRange:mutatedMatchTextRange];
                            NSRange linkTextMarkerRange = [matchString rangeOfString:linkInlineStartDivider options:0 range:NSMakeRange(0, matchString.length)]; // text before "]"
                            if (linkTextMarkerRange.length > 0) {
                                NSRange linkTextRange = NSMakeRange(0, linkTextMarkerRange.location);
                                linkText = [matchString substringWithRange:linkTextRange];
                                NSRange inlineLinkMarkerRange = [matchString rangeOfString:linkInlineEndDivider options:NSBackwardsSearch range:NSMakeRange(0, matchString.length)]; // text after "("
                                if (inlineLinkMarkerRange.length > 0) {
                                    if (inlineLinkMarkerRange.location == linkTextMarkerRange.location + linkTextMarkerRange.length) {
                                        NSUInteger markerIndex = inlineLinkMarkerRange.location + 1;
                                        NSRange inlineLinkRange = NSMakeRange(markerIndex, matchString.length - markerIndex);
                                        inlineLink = [matchString substringWithRange:inlineLinkRange];
                                    }
                                }
                            }
                            if (linkText && inlineLink) {
                                NSURL *URL = [NSURL URLWithString:inlineLink];
                                if (URL) {
                                    replacementString = linkText;
                                    if (styleAttributes[MarkdownStyleLink]) {
                                        replacementAttributes = styleAttributes[MarkdownStyleLink];
                                    }
                                    else {
                                        replacementAttributes = @{ NSLinkAttributeName: URL };
                                    }
                                    replaceMarkers = YES;
                                }
                            }
                            break;
                        }
                        case MarkdownSpanLinkAutomatic: {
                            NSString *string = [result.string substringWithRange:mutatedMatchTextRange];
                            NSURL *URL = [NSURL URLWithString:string];
                            if (URL) {
                                if (URL.scheme) {
                                    // use URL as-is (could be tel: or ftp: or something else that's not specified in Markdown syntax)
                                    if (styleAttributes[MarkdownStyleLink]) {
                                        replacementAttributes = styleAttributes[MarkdownStyleLink];
                                    }
                                    else {
                                        replacementAttributes = @{ NSLinkAttributeName: URL };
                                    }
                                    replaceMarkers = YES;
                                }
                                else {
                                    NSURL *synthesizedURL = nil;
                                    // check if it's an email address
                                    NSString *pattern = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}";
                                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
                                    BOOL result = [predicate evaluateWithObject:string];
                                    if (result) {
                                        // create mailto: link
                                        NSString *mailtoString = [NSString stringWithFormat:@"mailto:%@", string];
                                        synthesizedURL = [NSURL URLWithString:mailtoString];
                                    }
                                    else {
                                        // check if it's a domain name
                                        NSString *pattern = @"[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}";
                                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
                                        BOOL result = [predicate evaluateWithObject:string];
                                        if (result) {
                                            // prepend https: to the string
                                            NSString *httpString = [NSString stringWithFormat:@"https://%@", string];
                                            synthesizedURL = [NSURL URLWithString:httpString];
                                        }
                                    }
                                    if (synthesizedURL) {
                                        if (styleAttributes[MarkdownStyleLink]) {
                                            replacementAttributes = styleAttributes[MarkdownStyleLink];
                                        }
                                        else {
                                            replacementAttributes = @{ NSLinkAttributeName: synthesizedURL };
                                        }
                                        replaceMarkers = YES;
                                    }
                                }
                            }
                            break;
                        }
                        case MarkdownSpanCode:
#if ALLOW_CODE_MARKERS
                            // NOTE: This is a simplistic implementation that only adjusts the visual aspects of the inline code. It's a much harder problem
                            // when you think about how stuff between the code markers doesn't get modified (e.g. with emphasis or literals.)
                            replacementAttributes = @{ NSForegroundColorAttributeName: NSColor.labelColor, NSBackgroundColorAttributeName: [NSColor.labelColor colorWithAlphaComponent:0.1], NSFontAttributeName: [NSFont userFixedPitchFontOfSize:16.0], NSMarkedClauseSegmentAttributeName: @(1) };
                            replaceMarkers = YES;
#else
                            NSCAssert(NO, @"Not implemented");
#endif
                            break;
                    }
                     
                    if (replaceMarkers) {
                        NSRange mutatedBeginRange = NSMakeRange(beginRange.location - mutationOffset, beginRange.length);
                        [result replaceCharactersInRange:mutatedBeginRange withString:@""];
                        mutationOffset += beginRange.length;
                   
                        NSRange mutatedTextRange = NSMakeRange(beginIndex - mutationOffset, endIndex - beginIndex);

                        if (replaceStyleAttributes) {
                            if (spanType == MarkdownSpanEmphasisSingle) {
                                if (styleAttributes[MarkdownStyleEmphasisSingle]) {
                                    replaceAttributes(spanType, styleAttributes, result, mutatedTextRange);
                                }
                                else {
                                    addTrait(FONT_DESCRIPTOR_TRAIT_ITALIC, result, mutatedTextRange);
                                }
                            }
                            else if (spanType == MarkdownSpanEmphasisDouble) {
                                if (styleAttributes[MarkdownStyleEmphasisDouble]) {
                                    replaceAttributes(spanType, styleAttributes, result, mutatedTextRange);
                                }
                                else {
                                    addTrait(FONT_DESCRIPTOR_TRAIT_BOLD, result, mutatedTextRange);
                                }
                            }
                        }
                        
                        if (replacementAttributes) {
                            [result addAttributes:replacementAttributes range:mutatedTextRange];
                        }
                        if (replacementString) {
                            [result replaceCharactersInRange:mutatedTextRange withString:replacementString];
                            mutationOffset += mutatedTextRange.length - replacementString.length;
                        }
                        
                        NSRange mutatedEndRange = NSMakeRange(endRange.location - mutationOffset, endRange.length);
                        [result replaceCharactersInRange:mutatedEndRange withString:@""];
                        mutationOffset += endRange.length;
                    }
                    
                    scanIndex = endRange.location + endRange.length;
                }
            }
        }
        else {
            // no begin marker
            //DebugLog(@"%s <<<< .... no begin marker", "NSAttributedString+Markdown");
            abortScan = YES;
        }
    }

#if LOG_CONVERSIONS
    DebugLog(@"%s <<<< ---- '%@ %@ %@' end", "NSAttributedString+Markdown", (beginMarker ? beginMarker : @""), (dividerMarker ? dividerMarker : @""), (endMarker ? endMarker : @""));
    DebugLog(@"%s", "NSAttributedString+Markdown");
#endif
}

static void removeEscapedCharacterSetInAttributedString(NSMutableAttributedString *result, NSCharacterSet *characterSet)
{
    NSUInteger scanStart = 0;
    BOOL needsScan = YES;
    while (needsScan) {
        NSString *scanString = result.string;
        NSRange range = [scanString rangeOfCharacterFromSet:characterSet options:0 range:NSMakeRange(scanStart, scanString.length - scanStart)];
        if (range.length > 0) {
            BOOL hasEscapeMarker = hasCharacterRelative(scanString, range, -1, escapeCharacter);
            if (hasEscapeMarker) {
                // found character with escape, remove it
                [result replaceCharactersInRange:NSMakeRange(range.location - 1, 1) withString:@""];
                
                // NOTE: Since we're mutating by removing the escape characters in the string as we scan it, range.location will the first character after the matched literal character
                // and where we'll start our next scan. Like the mutationOffset above, this is some tricky stuff, in both senses of the word.
                scanStart = NSMaxRange(range);
                if (scanStart > result.length) {
                    needsScan = NO;
                }
            }
            else {
                scanStart = NSMaxRange(range);
            }
        }
        else {
            needsScan = NO;
        }
    }
}

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownString attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    return [self initWithMarkdownRepresentation:markdownString baseAttributes:attributes styleAttributes:nil];
}

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownString baseAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)baseAttributes styleAttributes:(nullable NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *)styleAttributes;
{
    NSAssert(baseAttributes[NSFontAttributeName] != nil, @"A font attribute is required");
    
    // NOTE: The order of these operations is important. For example, emphasis won't be applied if a link attribute is detected.
    
    // start by creating a string that contains the Markdown syntax with the base attributes: the string will have attributes
    // applied as the Markdown syntax is processed by updateAttributedString().
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:markdownString attributes:baseAttributes];

#if ALLOW_LINKS
    // replace [] and () markers with a link attribute
    NSString *linkInlineDividerMarker = [linkInlineStartDivider stringByAppendingString:linkInlineEndDivider];
    updateAttributedString(result, linkInlineStart, linkInlineDividerMarker, linkInlineEnd, MarkdownSpanLinkInline, styleAttributes);

    // replace < and > markers with a link attribute
    updateAttributedString(result, linkAutomaticStart, nil, linkAutomaticEnd, MarkdownSpanLinkAutomatic, styleAttributes);
#endif
    
#if ALLOW_CODE_MARKERS
    updateAttributedString(result, codeStart, nil, codeEnd, MarkdownSpanCode, styleAttributes);
#endif
    
    // replace ** and __ markers with bold font traits or MarkdownStyleEmphasisDouble style attributes
    updateAttributedString(result, emphasisDoubleStart, nil, emphasisDoubleEnd, MarkdownSpanEmphasisDouble, styleAttributes);
#if ALLOW_ALTERNATES
    updateAttributedString(result, emphasisDoubleAlternateStart, nil, emphasisDoubleAlternateEnd, MarkdownSpanEmphasisDouble, styleAttributes);
#endif
    
    // replace _ and _ markers with italic font traits or MarkdownStyleEmphasisSingle style attributes
    updateAttributedString(result, emphasisSingleStart, nil, emphasisSingleEnd, MarkdownSpanEmphasisSingle, styleAttributes);
#if ALLOW_ALTERNATES
    updateAttributedString(result, emphasisSingleAlternateStart, nil, emphasisSingleAlternateEnd, MarkdownSpanEmphasisSingle, styleAttributes);
#endif

    // remove backslashes from any escaped markers that haven't already been converted
    removeEscapedCharacterSetInAttributedString(result, NSCharacterSet.markdownLiteralCharacterSet);
    
    return result;
}

#pragma mark -

NS_INLINE NSRange emptyRange()
{
    return NSMakeRange(NSNotFound, 0);
}

static BOOL adjustRangeForWhitespace(NSRange range, NSString *string, NSRange *prefixRange, NSRange *textRange, NSRange *suffixRange)
{
    BOOL rangeAdjusted = NO;
    
    NSUInteger length = string.length;

    // TODO: This code would be simpler...
    //NSCharacterSet *characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    //trimmed [string stringByTrimmingCharactersInSet:characterSet];
    //range = [string rangeOfString:trimmed];
    
    // startIndex is first character in range that's not whitespace
    NSUInteger startIndex = range.location;
    while (startIndex < length &&
            ([string characterAtIndex:startIndex] == spaceCharacter ||  [string characterAtIndex:startIndex] == tabCharacter || [string characterAtIndex:startIndex] == newlineCharacter)) {
        startIndex += 1;
        rangeAdjusted = YES;
    }
    
    // endIndex is last character in range that's not whitespace
    NSUInteger endIndex = range.location + range.length - 1;
    while (endIndex > 0 &&
           ([string characterAtIndex:endIndex] == spaceCharacter || [string characterAtIndex:endIndex] == tabCharacter || [string characterAtIndex:endIndex] == newlineCharacter)) {
        endIndex -= 1;
        rangeAdjusted = YES;
    }
    endIndex += 1;
    
    //DebugLog(@"%s startIndex = %ld, endIndex = %ld", , "NSAttributedString+Markdown", startIndex, endIndex);
    
    if (startIndex < endIndex) {
        // prefixRange specifies whitespace before textRange, suffixRange specifies whitespace after
        *prefixRange = NSMakeRange(range.location, startIndex - range.location);
        *textRange = NSMakeRange(startIndex, endIndex - startIndex);
        *suffixRange = NSMakeRange(endIndex, range.location + range.length - endIndex);
    }
    else {
        // if endIndex >= startIndex, there was nothing but whitespace
        *prefixRange = emptyRange();
        *textRange = range;
        *suffixRange = emptyRange();
    }
    
    return rangeAdjusted;
}

static void addEscapesInMarkdownString(NSMutableString *text, NSString *marker)
{
    if (marker.length == 1) {

        const NSInteger prefixOffset = -1;
        const NSInteger suffixOffset = +1;

        BOOL needsScan = YES;
        NSUInteger scanIndex = 0;
        while (needsScan) {
            NSRange range = [text rangeOfString:marker options:0 range:NSMakeRange(scanIndex, text.length - scanIndex)];
            if (range.length > 0) {
                // found marker
                
                BOOL isHorizontalRuler = NO;
                if (range.location == 0 || hasCharacterRelative(text, range, prefixOffset, newlineCharacter)) {
                    // NOTE: At the start of a new line, check if there is nothing but three markers and additional space until the end of the line (and is therefore a horizontal ruler).
                    NSString *remainderText = [text substringFromIndex:range.location];
                    NSRange remainderRange = [remainderText rangeOfString:@"\n"];
                    if (remainderRange.location != NSNotFound) {
                        remainderText = [remainderText substringToIndex:remainderRange.location];
                    }
                    NSString *characterText = [remainderText stringByReplacingOccurrencesOfString:@" " withString:@""];
                    NSString *checkText = [characterText stringByReplacingOccurrencesOfString:marker withString:@""];
                    if (checkText.length == 0 && characterText.length >= 3) {
                        isHorizontalRuler = YES;
                        // no escapes are added, and scanning continues at end of line
                        scanIndex = range.location + range.length + remainderText.length - 1;
                    }
                }
                
                if (! isHorizontalRuler) {
                    BOOL insertEscape = NO;
                    
                    // NOTE: Check if marker surrounded by whitespace. On entry, the text range has already been adjusted for whitespace using adjustRangeForWhitespace().
                    // If the range is at the beginning or end of the text, we can assume that there's whitespace before or after.
                    BOOL hasPrefixSpace = YES;
                    BOOL hasSuffixSpace = YES;
                    
                    if (range.location == 0) {
                        hasSuffixSpace = hasCharacterRelative(text, range, suffixOffset, spaceCharacter) || hasCharacterRelative(text, range, suffixOffset, tabCharacter) || hasCharacterRelative(text, range, suffixOffset, newlineCharacter);
                    }
                    else if (range.location == (text.length - 1)) {
                        hasPrefixSpace = hasCharacterRelative(text, range, prefixOffset, spaceCharacter) || hasCharacterRelative(text, range, prefixOffset, tabCharacter) || hasCharacterRelative(text, range, prefixOffset, newlineCharacter);
                    }
                    else {
                        hasPrefixSpace = hasCharacterRelative(text, range, prefixOffset, spaceCharacter) || hasCharacterRelative(text, range, prefixOffset, tabCharacter) || hasCharacterRelative(text, range, prefixOffset, newlineCharacter);
                        hasSuffixSpace = hasCharacterRelative(text, range, suffixOffset, spaceCharacter) || hasCharacterRelative(text, range, suffixOffset, tabCharacter) || hasCharacterRelative(text, range, suffixOffset, newlineCharacter);
                    }
                    
                    if (! (hasPrefixSpace && hasSuffixSpace)) {
                        insertEscape = YES;
                    }
                    
                    if (insertEscape) {
                        [text insertString:literalBackslash atIndex:range.location];
                        scanIndex = range.location + range.length + literalBackslash.length;
                    }
                    else {
                        scanIndex = range.location + range.length;
                    }
                }
            }
            else {
                needsScan = NO;
            }
        }
    }
}

static void updateMarkdownString(NSMutableString *result, NSString *string, NSString *prefixString, NSRange prefixRange, NSRange textRange, NSString *suffixString, NSRange suffixRange, BOOL needsEscaping)
{
    if (prefixRange.location != NSNotFound) {
        NSString *prefix = [string substringWithRange:prefixRange];
        [result appendString:prefix];
    }
    
    if (prefixString) {
        [result appendString:prefixString];
    }
    
    NSMutableString *text = [NSMutableString stringWithString:[string substringWithRange:textRange]];
    // NOTE: Escaping literals isn't always needed. In an automatic link, the escapes will break the URL.
    if (needsEscaping) {
        // NOTE: This has to happen first since we're modifying the string in place (and don't want to escape the backslashes we're adding below).
        addEscapesInMarkdownString(text, literalBackslash);
        
        addEscapesInMarkdownString(text, literalAsterisk);
        addEscapesInMarkdownString(text, literalUnderscore);

#if ALLOW_ALL_LITERALS && ESCAPE_ALL_LITERALS
        addEscapesInMarkdownString(text, literalBacktick);
        addEscapesInMarkdownString(text, literalCurlyBraceOpen);
        addEscapesInMarkdownString(text, literalCurlyBraceClose);
        addEscapesInMarkdownString(text, literalSquareBracketOpen);
        addEscapesInMarkdownString(text, literalSquareBracketClose);
        addEscapesInMarkdownString(text, literalParenthesesOpen);
        addEscapesInMarkdownString(text, literalParenthesesClose);
        addEscapesInMarkdownString(text, literalHashMark);
        addEscapesInMarkdownString(text, literalPlusSign);
        addEscapesInMarkdownString(text, literalMinusSign);
        addEscapesInMarkdownString(text, literalDot);
        addEscapesInMarkdownString(text, literalExclamationPoint);
#endif
    }
    [result appendString:[text copy]];

    if (suffixString) {
        [result appendString:suffixString];
    }
    
    if (suffixRange.location != NSNotFound) {
        NSString *suffix = [string substringWithRange:suffixRange];
        [result appendString:suffix];
    }
#if DEBUG
#if LOG_CONVERSIONS
    NSString *logString = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    DebugLog(@"%s >>>> '%@'(%ld) '%@'(%ld) '%@'(%ld)", "NSAttributedString+Markdown", (prefixString ? prefixString : @""), prefixString.length, logString, text.length, (suffixString ? suffixString : @""), suffixString.length);
#endif
#endif
}

static FONT_DESCRIPTOR_SYMBOLIC_TRAITS symbolicTraitsForAttributes(NSDictionary<NSAttributedStringKey, id> *attributes)
{
    FONT_DESCRIPTOR_SYMBOLIC_TRAITS result = 0;
    
    FONT_CLASS *font = attributes[NSFontAttributeName];
    if (font) {
        FONT_DESCRIPTOR_CLASS *fontDescriptor = font.fontDescriptor;
        if (fontDescriptor) {
            result = fontDescriptor.symbolicTraits;
        }
        else {
#if LOG_CONVERSIONS
            DebugLog(@"%s >>>> no symbolic traits", "NSAttributedString+Markdown");
#endif
        }
    }
    
    return result;
}

// With an attributed string that looks like this:
//
//   This {0:normal} is an {1:bold} example {2:bold+italic} of how {3:italic} traits {4:bold} can {5:bold+italic} overlap {6:bold}
//
// The following markdownRepresentation will be created:
//
//   This **is an _example** of how_ **traits _can_ overlap**
//
// Here is the text that is emitted for each attribute range (numbered 0 to 6 above.)
//
// 0: This
//
// 1:      ** (prefix, inBoldRun = YES)
// 1:        is an
//
// 2:              _ (prefix, inItalicRun = YES)
// 2:               example
// 2:                      ** (suffix, inBoldRun = NO)
//
// 3:                         of how
// 3:                               _ (suffix, inItalicRun = NO)
//
// 4:                                 ** (prefix, inBoldRun = YES)
// 4:                                   traits
//
// 5:                                          _ (prefix, inItalicRun = YES)
// 5:                                           can
// 5:                                              _ (suffix, inItalicRun = NO)
//
// 6:                                                overlap
// 6:                                                       ** (suffix, inBoldRun = NO)

static void emitMarkdown(NSMutableString *result, NSString *normalizedString, NSString *currentString, NSRange currentRange, NSDictionary<NSAttributedStringKey, id> *currentAttributes, NSDictionary<NSAttributedStringKey, id> *nextAttributes, BOOL *inBoldRun, BOOL *inItalicRun)
{
    NSCharacterSet *characterSet = NSCharacterSet.whitespaceCharacterSet;
    if ([currentString stringByTrimmingCharactersInSet: characterSet].length == 0) {
        // current string only has whitespace, so we can ignore it
#if DEBUG
#if LOG_CONVERSIONS
        NSString *logString = [currentString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        FONT_CLASS *logFont = currentAttributes[NSFontAttributeName];
        DebugLog(@"%s >>>> %s %s %s (%@) [%@] %@", "NSAttributedString+Markdown", ".", ".", ".", logString, logFont.fontName, NSStringFromRange(currentRange));
#endif
#endif
        updateMarkdownString(result, normalizedString, nil, emptyRange(), currentRange, nil, emptyRange(), NO);
    }
    else {
        BOOL currentRangeHasLink = NO;
        NSURL *currentRangeURL = nil;
        if (currentAttributes[NSLinkAttributeName]) {
            NSURL *currentAttributeURL = nil;
            id currentLinkAttribute = currentAttributes[NSLinkAttributeName];
            if ([currentLinkAttribute isKindOfClass:[NSURL class]]) {
                currentAttributeURL = (NSURL *)currentLinkAttribute;
            }
            else if ([currentLinkAttribute isKindOfClass:[NSString class]]) {
                currentAttributeURL = [NSURL URLWithString:(NSString *)currentLinkAttribute];
            }
            if (currentAttributeURL) {
                currentRangeHasLink = YES;
                if ([currentAttributeURL.scheme isEqual:@"mailto"]) {
                    // a nil currentRangeURL indicates an automatic link
                }
                else {
                    if (! [currentAttributeURL.absoluteString isEqual:currentString]) {
                        currentRangeURL = currentAttributeURL;
                    }
                    else {
                        // a nil currentRangeURL indicates an automatic link
                    }
                }
            }
        }
        
#if ALLOW_CODE_MARKERS
        BOOL currentRangeHasCode = NO;
        if (currentAttributes[NSMarkedClauseSegmentAttributeName]) {
            currentRangeHasCode = YES;
        }
#endif
        
        // compare current traits to previous states
        NSString *prefixString = @"";
        NSString *suffixString = @"";
        
        FONT_DESCRIPTOR_SYMBOLIC_TRAITS currentSymbolicTraits = symbolicTraitsForAttributes(currentAttributes);
        
        FONT_DESCRIPTOR_SYMBOLIC_TRAITS nextSymbolicTraits;
        if (nextAttributes) {
            nextSymbolicTraits = symbolicTraitsForAttributes(nextAttributes);
        }
        else {
            // we're at the last attribute range: clear the traits so the correct suffixString is emitted
            nextSymbolicTraits = 0;
        }
        
        // check the symbolic traits for the font used in this and the next range
        BOOL currentRangeHasBold = (currentSymbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
        BOOL currentRangeHasItalic = (currentSymbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
        
        BOOL nextRangeHasBold = (nextSymbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
        BOOL nextRangeHasItalic = (nextSymbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
        
#if DEBUG
#if LOG_CONVERSIONS
        BOOL currentRangeHasSymbolic = (currentSymbolicTraits & FONT_DESCRIPTOR_CLASS_SYMBOLIC) != 0;
        NSString *logString = [currentString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        FONT_CLASS *logFont = currentAttributes[NSFontAttributeName];
        DebugLog(@"%s >>>> %s %s %s (%@) [%@] %@", "NSAttributedString+Markdown", (currentRangeHasBold ? "B" : " "), (currentRangeHasItalic ? "I" : " "), (currentRangeHasSymbolic ? "S" : " "), logString, logFont.fontName, NSStringFromRange(currentRange));
#endif
#endif
        
        BOOL needsEscaping = YES;
        
        if (currentRangeHasBold) {
            if (! *inBoldRun) {
                // emit start of bold run
                prefixString = [prefixString stringByAppendingString:emphasisDoubleStart];
                *inBoldRun = YES;
            }
        }
        if (currentRangeHasItalic) {
            if (! *inItalicRun) {
                // emit start of italic run
                prefixString = [prefixString stringByAppendingString:emphasisSingleStart];
                *inItalicRun = YES;
            }
        }
        
        if (currentRangeHasLink) {
            if (currentRangeURL) {
                prefixString = [prefixString stringByAppendingString:linkInlineStart];
                suffixString = [[[[suffixString stringByAppendingString:linkInlineStartDivider] stringByAppendingString:linkInlineEndDivider] stringByAppendingString:currentRangeURL.absoluteString] stringByAppendingString:linkInlineEnd];
            }
            else {
                needsEscaping = NO;
                prefixString = [prefixString stringByAppendingString:linkAutomaticStart];
                suffixString = [suffixString stringByAppendingString:linkAutomaticEnd];
            }
        }
        
#if ALLOW_CODE_MARKERS
        if (currentRangeHasCode) {
            prefixString = [prefixString stringByAppendingString:codeStart];
            suffixString = [suffixString stringByAppendingString:codeEnd];
        }
#endif
        
        if (! nextRangeHasItalic) {
            if (*inItalicRun) {
                // emit end of italic run
                suffixString = [suffixString stringByAppendingString:emphasisSingleEnd];
                *inItalicRun = NO;
            }
        }
        if (! nextRangeHasBold) {
            if (*inBoldRun) {
                // emit end of bold run
                suffixString = [suffixString stringByAppendingString:emphasisDoubleEnd];
                *inBoldRun = NO;
            }
        }
        
        NSRange prefixRange;
        NSRange textRange;
        NSRange suffixRange;
        adjustRangeForWhitespace(currentRange, normalizedString, &prefixRange, &textRange, &suffixRange);
        updateMarkdownString(result, normalizedString, prefixString, prefixRange, textRange, suffixString, suffixRange, needsEscaping);
    }
}

- (NSString *)markdownRepresentation
{
    NSMutableString *result = [NSMutableString string];

    // TODO: Do we need to ensure that the result is normalized using either the canonical or compatability mapping?
    // https://developer.apple.com/documentation/foundation/nsstring/1412645-precomposedstringwithcanonicalma?language=objc
    // https://unicode.org/reports/tr15/#Norm_Forms
    
    NSMutableAttributedString *cleanAttributedString = [self mutableCopy];
    // remove attributes that may break a range we're interested in (like paragraph styling from edits in UITextView)
    [cleanAttributedString removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, cleanAttributedString.length)];
    [cleanAttributedString removeAttribute:NSParagraphStyleAttributeName range:NSMakeRange(0, cleanAttributedString.length)];

    NSAttributedString *normalizedAttributedString = [cleanAttributedString copy];
    NSString *normalizedString = normalizedAttributedString.string;
    NSUInteger normalizedLength = normalizedAttributedString.length;

    BOOL inBoldRun = NO;
    BOOL inItalicRun = NO;
    
    NSUInteger index = 0;
    while (index < normalizedLength) {
        NSRange currentRange;
        NSDictionary<NSAttributedStringKey, id> *currentAttributes = [normalizedAttributedString attributesAtIndex:index effectiveRange:&currentRange];
        NSString *currentString = [normalizedString substringWithRange:currentRange];
        
        NSDictionary<NSAttributedStringKey, id> *nextAttributes = nil;
        NSUInteger nextIndex = currentRange.location + currentRange.length;
        if (nextIndex < normalizedLength) {
            nextAttributes = [normalizedAttributedString attributesAtIndex:nextIndex effectiveRange:NULL];
        }
        else {
            // leave nextAttributes as nil to signal that we're at the last range (in emitMarkdown)
        }

        // check if current range contains one or more visual breaks, if it does each piece will be emitted separately
        if ([currentString containsString:visualLineBreak]) {

            NSArray<NSString *> *currentStringComponents = [currentString componentsSeparatedByString:visualLineBreak];
            
#if DEBUG
#if LOG_CONVERSIONS
            NSUInteger componentCount = 1;
            for (NSString *currentStringComponent in currentStringComponents) {
                NSString *logString = [currentStringComponent stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
                DebugLog(@"%s >>>> %s %s %s [%ld of %ld] (%@)", "NSAttributedString+Markdown", "-", "-", "-", componentCount, currentStringComponents.count, logString);
                componentCount += 1;
            }
#endif
#endif
            
            // NOTE: The first component doesn't include the visual line break sequence (\n\n) but subsequent components do by adjusting the visualLineBreakOffset.
            NSUInteger visualLineBreakOffset = 0;
            NSRange currentComponentRange = NSMakeRange(currentRange.location, 0);
            for (NSString *currentStringComponent in currentStringComponents) {
                currentComponentRange.length = currentStringComponent.length + visualLineBreakOffset;
                emitMarkdown(result, normalizedString, currentStringComponent, currentComponentRange, currentAttributes, nextAttributes, &inBoldRun, &inItalicRun);
                currentComponentRange.location = currentComponentRange.location + currentStringComponent.length + visualLineBreakOffset;
                
                visualLineBreakOffset = visualLineBreak.length;
            }
        }
        else {
            emitMarkdown(result, normalizedString, currentString, currentRange, currentAttributes, nextAttributes, &inBoldRun, &inItalicRun);
        }
        
        index = currentRange.location + currentRange.length;
    }
    
    return [result copy];
}

// NOTE: The tests use this method to build a simple representation of the attributed string that can be checked against an expected result.

- (NSString *)markdownDebug
{
    NSMutableString *result = [NSMutableString string];
    
    [self enumerateAttributesInRange:NSMakeRange(0, self.length) options:(0) usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attributes, NSRange range, BOOL *stop) {
        
        BOOL rangeHasBold = NO;
        BOOL rangeHasItalic = NO;
        FONT_CLASS *font = (FONT_CLASS *)attributes[NSFontAttributeName];
        if (font) {
            FONT_DESCRIPTOR_CLASS *fontDescriptor = font.fontDescriptor;
            if (fontDescriptor) {
                FONT_DESCRIPTOR_SYMBOLIC_TRAITS symbolicTraits = fontDescriptor.symbolicTraits;
                
                rangeHasBold = (symbolicTraits & FONT_DESCRIPTOR_TRAIT_BOLD) != 0;
                rangeHasItalic = (symbolicTraits & FONT_DESCRIPTOR_TRAIT_ITALIC) != 0;
            }
        }

        BOOL rangeHasLink = NO;
        NSString *linkString = @"";
        id link = attributes[NSLinkAttributeName];
        if (link) {
            rangeHasLink = YES;
            if ([link isKindOfClass:[NSURL class]]) {
                NSURL *URL = (NSURL *)link;
                linkString = [NSString stringWithFormat:@"<%@>", URL.absoluteString];
            }
            else if ([link isKindOfClass:[NSString class]]) {
                NSString *string = (NSString *)link;
                linkString = [NSString stringWithFormat:@"<%@>", string];
            }
        }
        
        NSString *rangeString = [NSString stringWithFormat:@"[%@](%s%s)%@", [self.string substringWithRange:range], (rangeHasBold ? "B" : " "), (rangeHasItalic ? "I" : " "), linkString];
        [result appendString:rangeString];
    }];
    
    [result replaceOccurrencesOfString:@"\n" withString:@"\\n" options:(0) range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"\t" withString:@"\\t" options:(0) range:NSMakeRange(0, result.length)];

    return [result copy];
}

@end
