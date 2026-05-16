// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMarkdownParse.m
//  WuKongBase
//
//  Created by tt on 2022/4/28.
//

#import "WKMarkdownParser.h"
#import "WKMatchToken.h"

@implementation WKMarkdownAttributeSet


-(instancetype) initWithFont:(UIFont*)font textColor:(UIColor*)textColor attributes:(NSDictionary<NSAttributedStringKey,id>*)attributes {
    WKMarkdownAttributeSet *p = [[WKMarkdownAttributeSet alloc] init];
    p.font = font;
    p.textColor = textColor;
    p.attributes = attributes;
    return p;
}

@end

@implementation WKMarkdownAttributes

-(instancetype) initBody:(WKMarkdownAttributeSet*)body bold:(WKMarkdownAttributeSet*)bold link:(WKMarkdownAttributeSet*)link linkAttribute:(NSDictionary<NSAttributedStringKey,id>*(^)(NSString*content))linkAttribute {
    WKMarkdownAttributes *attr = [[WKMarkdownAttributes alloc] init];
    attr.body = body;
    attr.bold = bold;
    attr.link = link;
    attr.linkAttribute = linkAttribute;
    return attr;
}


@end

@implementation WKMarkdownParser

-(NSArray<id<WKMatchToken>>*) parseMarkdownIntoAttributedString:(NSString*)string {
    if(!string || string.length == 0) {
        return @[];
    }

    NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];

    // Phase 1: Block-level parsing (line by line)
    NSArray<NSString*> *lines = [string componentsSeparatedByString:@"\n"];
    NSUInteger currentOffset = 0;
    BOOL inCodeBlock = NO;
    NSUInteger codeBlockStart = 0;
    NSString *codeBlockLanguage = nil;
    NSMutableString *codeBlockContent = nil;

    for (NSUInteger lineIndex = 0; lineIndex < lines.count; lineIndex++) {
        NSString *line = lines[lineIndex];
        NSUInteger lineStart = currentOffset;
        NSUInteger lineEnd = currentOffset + line.length;

        // Code fence detection
        if ([self isCodeFenceLine:line]) {
            if (!inCodeBlock) {
                // Opening fence
                inCodeBlock = YES;
                codeBlockStart = lineStart;
                codeBlockLanguage = [self extractLanguageFromFenceLine:line];
                codeBlockContent = [NSMutableString string];
            } else {
                // Closing fence
                inCodeBlock = NO;
                NSRange fullRange = NSMakeRange(codeBlockStart, lineEnd - codeBlockStart);
                WKCodeBlockToken *token = [WKCodeBlockToken new];
                token.range = fullRange;
                token.text = [string substringWithRange:fullRange];
                token.codeContent = [codeBlockContent copy];
                token.language = codeBlockLanguage;
                [tokens addObject:token];
                codeBlockLanguage = nil;
                codeBlockContent = nil;
            }
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        if (inCodeBlock) {
            if (codeBlockContent.length > 0) {
                [codeBlockContent appendString:@"\n"];
            }
            [codeBlockContent appendString:line];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Horizontal rule: --- or *** or ___ (3+ chars, line only contains these + spaces)
        if ([self isHorizontalRuleLine:line]) {
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKHorizontalRuleToken *token = [WKHorizontalRuleToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Table detection: line starts with |
        if ([self isTableLine:line]) {
            // Collect consecutive table lines
            NSMutableArray<NSString*> *tableLines = [NSMutableArray array];
            NSUInteger tableStart = lineStart;
            NSUInteger tableEndOffset = lineEnd;
            [tableLines addObject:line];

            NSUInteger nextIdx = lineIndex + 1;
            while (nextIdx < lines.count) {
                NSString *nextLine = lines[nextIdx];
                if ([self isTableLine:nextLine]) {
                    [tableLines addObject:nextLine];
                    tableEndOffset += 1 + nextLine.length; // +1 for \n
                    nextIdx++;
                } else {
                    break;
                }
            }

            if (tableLines.count >= 2) {
                // Parse table
                WKTableToken *tableToken = [self parseTableFromLines:tableLines];
                if (tableToken) {
                    NSRange fullRange = NSMakeRange(tableStart, tableEndOffset - tableStart);
                    tableToken.range = fullRange;
                    tableToken.text = [string substringWithRange:fullRange];
                    [tokens addObject:tableToken];

                    // Skip ahead past all table lines
                    lineIndex = nextIdx - 1;
                    currentOffset = tableEndOffset;
                    if (lineIndex < lines.count - 1) {
                        currentOffset += 1;
                    }
                    continue;
                }
            }
            // If not a valid table, fall through to inline parsing
        }

        // Heading detection: # , ## , ###
        NSInteger headingLevel = [self headingLevelForLine:line];
        if (headingLevel > 0) {
            NSString *headingText = [line substringFromIndex:headingLevel + 1];
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKHeadingToken *token = [WKHeadingToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            token.headingText = headingText;
            token.level = headingLevel;
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Task list: - [x] or - [ ]
        if ([self isTaskItemLine:line]) {
            BOOL checked = [self isTaskItemChecked:line];
            NSString *itemText = [self taskItemText:line];
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKTaskItemToken *token = [WKTaskItemToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            token.itemText = itemText;
            token.checked = checked;
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Unordered list: - or * (including indented sub-items)
        if ([self isUnorderedListLine:line]) {
            NSInteger indent = [self listIndentLevel:line];
            NSString *strippedLine = [self stripListPrefix:line];
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKListItemToken *token = [WKListItemToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            token.itemText = strippedLine;
            token.ordered = NO;
            token.orderNumber = indent; // reuse orderNumber to store indent level
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Ordered list: 1. , 2. , etc.
        NSInteger orderNumber = [self orderedListNumberForLine:line];
        if (orderNumber > 0) {
            NSRange dotRange = [line rangeOfString:@". "];
            NSString *itemText = [line substringFromIndex:dotRange.location + 2];
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKListItemToken *token = [WKListItemToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            token.itemText = itemText;
            token.ordered = YES;
            token.orderNumber = orderNumber;
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Blockquote: >
        if ([self isBlockquoteLine:line]) {
            NSString *quoteText;
            if (line.length > 2 && [line hasPrefix:@"> "]) {
                quoteText = [line substringFromIndex:2];
            } else if (line.length > 1) {
                quoteText = [line substringFromIndex:1];
            } else {
                quoteText = @"";
            }
            NSRange fullRange = NSMakeRange(lineStart, line.length);
            WKBlockquoteToken *token = [WKBlockquoteToken new];
            token.range = fullRange;
            token.text = [string substringWithRange:fullRange];
            token.quoteText = quoteText;
            [tokens addObject:token];
            currentOffset = lineEnd;
            if (lineIndex < lines.count - 1) {
                currentOffset += 1;
            }
            continue;
        }

        // Regular text line: Phase 2 inline parsing
        if (line.length > 0) {
            NSArray<id<WKMatchToken>> *inlineTokens = [self parseInlineMarkdown:line baseOffset:lineStart];
            [tokens addObjectsFromArray:inlineTokens];
        }

        currentOffset = lineEnd;
        if (lineIndex < lines.count - 1) {
            currentOffset += 1;
        }
    }

    // Handle unclosed code block (streaming tolerance)
    if (inCodeBlock && codeBlockContent) {
        NSRange fullRange = NSMakeRange(codeBlockStart, string.length - codeBlockStart);
        WKCodeBlockToken *token = [WKCodeBlockToken new];
        token.range = fullRange;
        token.text = [string substringWithRange:fullRange];
        token.codeContent = [codeBlockContent copy];
        token.language = codeBlockLanguage;
        [tokens addObject:token];
    }

    return tokens;
}

#pragma mark - Block-level helpers

-(BOOL) isCodeFenceLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [trimmed hasPrefix:@"```"];
}

-(NSString*) extractLanguageFromFenceLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length > 3) {
        NSString *lang = [[trimmed substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (lang.length > 0) {
            return lang;
        }
    }
    return nil;
}

-(NSInteger) headingLevelForLine:(NSString*)line {
    if ([line hasPrefix:@"### "]) return 3;
    if ([line hasPrefix:@"## "]) return 2;
    if ([line hasPrefix:@"# "]) return 1;
    return 0;
}

-(BOOL) isUnorderedListLine:(NSString*)line {
    // Support indented sub-items:  "  - sub" or "    - sub"
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trimmed hasPrefix:@"- "]) return YES;
    if ([trimmed hasPrefix:@"* "] && ![trimmed hasPrefix:@"**"]) return YES;
    return NO;
}

-(NSInteger) listIndentLevel:(NSString*)line {
    NSInteger spaces = 0;
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar ch = [line characterAtIndex:i];
        if (ch == ' ') {
            spaces++;
        } else if (ch == '\t') {
            spaces += 4;
        } else {
            break;
        }
    }
    return spaces / 2; // every 2 spaces = 1 indent level
}

-(NSString*) stripListPrefix:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trimmed hasPrefix:@"- "]) return [trimmed substringFromIndex:2];
    if ([trimmed hasPrefix:@"* "] && ![trimmed hasPrefix:@"**"]) return [trimmed substringFromIndex:2];
    return trimmed;
}

-(NSInteger) orderedListNumberForLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\. " options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
    if (match) {
        NSString *numStr = [trimmed substringWithRange:[match rangeAtIndex:1]];
        return [numStr integerValue];
    }
    return 0;
}

-(BOOL) isBlockquoteLine:(NSString*)line {
    return [line hasPrefix:@">"];
}

-(BOOL) isHorizontalRuleLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length < 3) return NO;
    // Must be only dashes, asterisks, or underscores (with optional spaces)
    NSString *stripped = [trimmed stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (stripped.length < 3) return NO;
    unichar first = [stripped characterAtIndex:0];
    if (first != '-' && first != '*' && first != '_') return NO;
    for (NSUInteger i = 0; i < stripped.length; i++) {
        if ([stripped characterAtIndex:i] != first) return NO;
    }
    return YES;
}

-(BOOL) isTaskItemLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [trimmed hasPrefix:@"- [x] "] || [trimmed hasPrefix:@"- [X] "] || [trimmed hasPrefix:@"- [ ] "];
}

-(BOOL) isTaskItemChecked:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [trimmed hasPrefix:@"- [x] "] || [trimmed hasPrefix:@"- [X] "];
}

-(NSString*) taskItemText:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length > 6) {
        return [trimmed substringFromIndex:6]; // skip "- [x] " or "- [ ] "
    }
    return @"";
}

-(BOOL) isTableLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [trimmed hasPrefix:@"|"] && [trimmed hasSuffix:@"|"];
}

-(BOOL) isTableSeparatorLine:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (![trimmed hasPrefix:@"|"] || ![trimmed hasSuffix:@"|"]) return NO;
    // Check if it only contains |, -, :, and spaces
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"|:- "];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar ch = [trimmed characterAtIndex:i];
        if (![allowed characterIsMember:ch]) return NO;
    }
    return YES;
}

-(NSArray<NSString*>*) parseTableRow:(NSString*)line {
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    // Remove leading and trailing |
    if ([trimmed hasPrefix:@"|"]) trimmed = [trimmed substringFromIndex:1];
    if ([trimmed hasSuffix:@"|"]) trimmed = [trimmed substringToIndex:trimmed.length - 1];

    NSArray<NSString*> *cells = [trimmed componentsSeparatedByString:@"|"];
    NSMutableArray<NSString*> *result = [NSMutableArray array];
    for (NSString *cell in cells) {
        [result addObject:[cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
    return result;
}

-(WKTableToken*) parseTableFromLines:(NSArray<NSString*>*)tableLines {
    if (tableLines.count < 2) return nil;

    // Check if second line is separator
    BOOL hasHeader = [self isTableSeparatorLine:tableLines[1]];

    NSMutableArray<NSArray<NSString*>*> *rows = [NSMutableArray array];
    for (NSUInteger i = 0; i < tableLines.count; i++) {
        if (hasHeader && i == 1) continue; // skip separator row
        NSArray<NSString*> *row = [self parseTableRow:tableLines[i]];
        [rows addObject:row];
    }

    if (rows.count == 0) return nil;

    WKTableToken *token = [WKTableToken new];
    token.rows = rows;
    token.hasHeader = hasHeader;
    return token;
}

#pragma mark - Phase 2: Inline parsing

-(NSArray<id<WKMatchToken>>*) parseInlineMarkdown:(NSString*)line baseOffset:(NSUInteger)baseOffset {
    NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];

    // First pass: find inline code spans to protect their contents
    NSMutableArray<NSValue*> *protectedRanges = [NSMutableArray array];

    // Find inline code: `code`
    NSUInteger i = 0;
    while (i < line.length) {
        unichar ch = [line characterAtIndex:i];
        if (ch == '`') {
            NSUInteger closeIndex = [self findClosingChar:'`' inString:line fromIndex:i+1];
            if (closeIndex != NSNotFound) {
                NSRange localRange = NSMakeRange(i, closeIndex - i + 1);
                [protectedRanges addObject:[NSValue valueWithRange:localRange]];
                NSString *codeText = [line substringWithRange:NSMakeRange(i+1, closeIndex - i - 1)];
                WKInlineCodeToken *token = [WKInlineCodeToken new];
                token.range = NSMakeRange(baseOffset + i, localRange.length);
                token.text = [line substringWithRange:localRange];
                token.codeText = codeText;
                [tokens addObject:token];
                i = closeIndex + 1;
                continue;
            }
        }
        i++;
    }

    // Second pass: find bold+italic, bold, italic, strikethrough, links (skip protected ranges)
    i = 0;
    while (i < line.length) {
        if ([self index:i isInProtectedRanges:protectedRanges]) {
            i++;
            continue;
        }

        unichar ch = [line characterAtIndex:i];

        // Bold+Italic: ***text***
        if (ch == '*' && i + 2 < line.length && [line characterAtIndex:i+1] == '*' && [line characterAtIndex:i+2] == '*') {
            NSRange closeRange = [line rangeOfString:@"***" options:0 range:NSMakeRange(i+3, line.length - i - 3)];
            if (closeRange.location != NSNotFound && ![self rangeOverlapsProtected:NSMakeRange(i, closeRange.location + 3 - i) protectedRanges:protectedRanges]) {
                NSString *biText = [line substringWithRange:NSMakeRange(i+3, closeRange.location - i - 3)];
                if (biText.length > 0) {
                    NSRange fullRange = NSMakeRange(baseOffset + i, closeRange.location + 3 - i);
                    WKBoldItalicToken *token = [WKBoldItalicToken new];
                    token.range = fullRange;
                    token.text = [line substringWithRange:NSMakeRange(i, closeRange.location + 3 - i)];
                    token.boldItalicText = biText;
                    [tokens addObject:token];
                    [protectedRanges addObject:[NSValue valueWithRange:NSMakeRange(i, closeRange.location + 3 - i)]];
                    i = closeRange.location + 3;
                    continue;
                }
            }
        }

        // Bold: **text**
        if (ch == '*' && i + 1 < line.length && [line characterAtIndex:i+1] == '*') {
            // Make sure it's not *** (already handled above)
            if (i + 2 < line.length && [line characterAtIndex:i+2] == '*') {
                i++;
                continue;
            }
            NSRange closeRange = [line rangeOfString:@"**" options:0 range:NSMakeRange(i+2, line.length - i - 2)];
            if (closeRange.location != NSNotFound && ![self rangeOverlapsProtected:NSMakeRange(i, closeRange.location + 2 - i) protectedRanges:protectedRanges]) {
                NSString *boldText = [line substringWithRange:NSMakeRange(i+2, closeRange.location - i - 2)];
                if (boldText.length > 0) {
                    NSRange fullRange = NSMakeRange(baseOffset + i, closeRange.location + 2 - i);
                    WKBoldToken *token = [WKBoldToken new];
                    token.range = fullRange;
                    token.text = [line substringWithRange:NSMakeRange(i, closeRange.location + 2 - i)];
                    token.boldText = boldText;
                    [tokens addObject:token];
                    [protectedRanges addObject:[NSValue valueWithRange:NSMakeRange(i, closeRange.location + 2 - i)]];
                    i = closeRange.location + 2;
                    continue;
                }
            }
        }

        // Italic: *text* (single asterisk)
        if (ch == '*' && !(i + 1 < line.length && [line characterAtIndex:i+1] == '*')) {
            NSUInteger searchStart = i + 1;
            NSUInteger closeIdx = NSNotFound;
            while (searchStart < line.length) {
                NSRange r = [line rangeOfString:@"*" options:0 range:NSMakeRange(searchStart, line.length - searchStart)];
                if (r.location == NSNotFound) break;
                if (r.location + 1 < line.length && [line characterAtIndex:r.location+1] == '*') {
                    searchStart = r.location + 2;
                    continue;
                }
                if (r.location > 0 && [line characterAtIndex:r.location-1] == '*') {
                    searchStart = r.location + 1;
                    continue;
                }
                closeIdx = r.location;
                break;
            }
            if (closeIdx != NSNotFound && ![self rangeOverlapsProtected:NSMakeRange(i, closeIdx + 1 - i) protectedRanges:protectedRanges]) {
                NSString *italicText = [line substringWithRange:NSMakeRange(i+1, closeIdx - i - 1)];
                if (italicText.length > 0) {
                    NSRange fullRange = NSMakeRange(baseOffset + i, closeIdx + 1 - i);
                    WKItalicToken *token = [WKItalicToken new];
                    token.range = fullRange;
                    token.text = [line substringWithRange:NSMakeRange(i, closeIdx + 1 - i)];
                    token.italicText = italicText;
                    [tokens addObject:token];
                    [protectedRanges addObject:[NSValue valueWithRange:NSMakeRange(i, closeIdx + 1 - i)]];
                    i = closeIdx + 1;
                    continue;
                }
            }
        }

        // Strikethrough: ~~text~~
        if (ch == '~' && i + 1 < line.length && [line characterAtIndex:i+1] == '~') {
            NSRange closeRange = [line rangeOfString:@"~~" options:0 range:NSMakeRange(i+2, line.length - i - 2)];
            if (closeRange.location != NSNotFound && ![self rangeOverlapsProtected:NSMakeRange(i, closeRange.location + 2 - i) protectedRanges:protectedRanges]) {
                NSString *strikeText = [line substringWithRange:NSMakeRange(i+2, closeRange.location - i - 2)];
                if (strikeText.length > 0) {
                    NSRange fullRange = NSMakeRange(baseOffset + i, closeRange.location + 2 - i);
                    WKStrikethroughToken *token = [WKStrikethroughToken new];
                    token.range = fullRange;
                    token.text = [line substringWithRange:NSMakeRange(i, closeRange.location + 2 - i)];
                    token.strikethroughText = strikeText;
                    [tokens addObject:token];
                    [protectedRanges addObject:[NSValue valueWithRange:NSMakeRange(i, closeRange.location + 2 - i)]];
                    i = closeRange.location + 2;
                    continue;
                }
            }
        }

        // Link: [text](url)
        if (ch == '[') {
            NSRange closeBracket = [line rangeOfString:@"](" options:0 range:NSMakeRange(i+1, line.length - i - 1)];
            if (closeBracket.location != NSNotFound) {
                NSRange closeParen = [line rangeOfString:@")" options:0 range:NSMakeRange(closeBracket.location + 2, line.length - closeBracket.location - 2)];
                if (closeParen.location != NSNotFound) {
                    NSString *linkText = [line substringWithRange:NSMakeRange(i+1, closeBracket.location - i - 1)];
                    NSString *linkURL = [line substringWithRange:NSMakeRange(closeBracket.location + 2, closeParen.location - closeBracket.location - 2)];
                    NSRange fullRange = NSMakeRange(baseOffset + i, closeParen.location + 1 - i);
                    WKLinkToken *token = [WKLinkToken new];
                    token.range = fullRange;
                    token.text = [line substringWithRange:NSMakeRange(i, closeParen.location + 1 - i)];
                    token.linkText = linkText;
                    token.linkContent = linkURL;
                    [tokens addObject:token];
                    [protectedRanges addObject:[NSValue valueWithRange:NSMakeRange(i, closeParen.location + 1 - i)]];
                    i = closeParen.location + 1;
                    continue;
                }
            }
        }

        i++;
    }

    return tokens;
}

#pragma mark - Inline parsing helpers

-(NSUInteger) findClosingChar:(unichar)ch inString:(NSString*)string fromIndex:(NSUInteger)fromIndex {
    for (NSUInteger i = fromIndex; i < string.length; i++) {
        if ([string characterAtIndex:i] == ch) {
            return i;
        }
    }
    return NSNotFound;
}

-(BOOL) index:(NSUInteger)index isInProtectedRanges:(NSArray<NSValue*>*)ranges {
    for (NSValue *val in ranges) {
        NSRange range = val.rangeValue;
        if (index >= range.location && index < range.location + range.length) {
            return YES;
        }
    }
    return NO;
}

-(BOOL) rangeOverlapsProtected:(NSRange)range protectedRanges:(NSArray<NSValue*>*)ranges {
    for (NSValue *val in ranges) {
        NSRange pRange = val.rangeValue;
        if (range.location < pRange.location + pRange.length && pRange.location < range.location + range.length) {
            return YES;
        }
    }
    return NO;
}

@end
