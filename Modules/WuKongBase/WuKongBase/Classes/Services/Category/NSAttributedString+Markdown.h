//
//  NSAttributedString+Markdown.h
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

#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#define ALLOW_CODE_MARKERS 0    // EXPERIMENTAL - Currently literals aren't escaped and style attributes are baked in (not using styleAttributes).

NS_ASSUME_NONNULL_BEGIN

@interface NSCharacterSet (Markdown)

@property (readonly, class, copy) NSCharacterSet *markdownLiteralCharacterSet;

@end

extern NSString *const UTTypeMarkdown;
// NOTE: The definition above can be used to determine if text on the clipboard contains Markdown:
//
// if ([UIPasteboard.generalPasteboard containsPasteboardTypes:@[ UTTypeMarkdown, (NSString *)kUTTypeText ]]) { ... }


typedef NSString * MarkdownStyleKey NS_EXTENSIBLE_STRING_ENUM;

extern MarkdownStyleKey MarkdownStyleEmphasisSingle;                // attribute dictionary for occurances of _ or * (emphasis, typically an italic font)
extern MarkdownStyleKey MarkdownStyleEmphasisDouble;                // attribute dictionary for occurances of __ or ** (strong, typically a bold font)
extern MarkdownStyleKey MarkdownStyleEmphasisBoth;                    // attribute dictionary for occurances of _ or * within __ or ** (emphasis and strong, typically a bold italic font)

extern MarkdownStyleKey MarkdownStyleLink;                            // optional attribute dictionary to use instead of NSLinkAttributeName, link will be styled with attributes instead of clickable

#if ALLOW_CODE_MARKERS
extern MarkdownStyleKey MarkdownStyleCode;                            // EXPERIMENTAL - attribute dictionary for occuranges of `
#endif

@interface NSAttributedString (Markdown)

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownRepresentation attributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)attributes;

- (instancetype)initWithMarkdownRepresentation:(NSString *)markdownRepresentation baseAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)baseAttributes styleAttributes:(nullable NSDictionary<MarkdownStyleKey, NSDictionary<NSAttributedStringKey, id> *> *)styleAttributes;

@property (nonatomic, readonly) NSString *markdownRepresentation;

#ifdef TESTING
// for tests, to quickly check the placement of attributes
@property (nonatomic, readonly) NSString *markdownDebug;
#endif

@end

NS_ASSUME_NONNULL_END
