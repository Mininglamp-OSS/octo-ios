// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMatchToken.m
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import "WKMatchToken.h"

@implementation WKDefaultToken


+(WKDefaultToken*) text:(NSString*)text range:(NSRange)range type:(WKatchTokenType)type {
    WKDefaultToken *token = [[WKDefaultToken alloc] init];
    token.range = range;
    token.text= text;
    token.type = type;
    return token;
}




@synthesize range;
@synthesize text;
@synthesize type;

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKDefaultToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    return token;
}

@end

@implementation WKMetionToken

- (WKatchTokenType)type {
    return WKatchTokenTypeMetion;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKMetionToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.uid = [self.uid copy];
    token.index = self.index;
    return token;
}

@end

@implementation WKEmotionToken

- (WKatchTokenType)type {
    return WKatchTokenTypeEmoji;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKEmotionToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.imageName = [self.imageName copy];
    return token;
}

@end

@implementation WKLinkToken


- (WKatchTokenType)type {
    return WKatchTokenTypeLink2;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKLinkToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.linkText = [self.linkText copy];
    token.linkContent = [self.linkContent copy];
    return token;
}
@end

@implementation WKBoldToken
- (WKatchTokenType)type {
    return WKatchTokenTypeBold;
}

- (NSString *)boldText {
    if(_boldText) {
        return _boldText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKBoldToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.boldText = [self.boldText copy];
    return token;
}

@end

@implementation WKRemoteImageToken

- (WKatchTokenType)type {
    return WKatchTokenTypeRemoteImage;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKRemoteImageToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.size = self.size;
    token.url = [self.url copy];

    return token;
}

@end

@implementation WKColorToken

- (WKatchTokenType)type {
    return WKatchTokenTypeColor;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKColorToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.color = self.color;
    return token;
}

@end

@implementation WKUnderlineToken

- (WKatchTokenType)type {
    return WKatchTokenTypeUnderline;
}

@end

@implementation WKItalicToken

- (WKatchTokenType)type {
    return WKatchTokenTypeItalic;
}

- (NSString *)italicText {
    if(_italicText) {
        return _italicText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKItalicToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.italicText = [self.italicText copy];
    return token;
}

@end

@implementation WKStrikethroughToken

- (WKatchTokenType)type {
    return WKatchTokenTypeStrikethrough;
}

- (NSString *)strikethroughText {
    if(_strikethroughText) {
        return _strikethroughText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKStrikethroughToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.strikethroughText = [self.strikethroughText copy];
    return token;
}

@end


@implementation WKFontToken

- (WKatchTokenType)type {
    return WKatchTokenTypeFont;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKFontToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.fontSize = self.fontSize;
    return token;
}

@end

@implementation WKInlineCodeToken

- (WKatchTokenType)type {
    return WKatchTokenTypeInlineCode;
}

- (NSString *)codeText {
    if(_codeText) {
        return _codeText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKInlineCodeToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.codeText = [self.codeText copy];
    return token;
}

@end

@implementation WKHeadingToken

- (WKatchTokenType)type {
    return WKatchTokenTypeHeading;
}

- (NSString *)headingText {
    if(_headingText) {
        return _headingText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKHeadingToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.headingText = [self.headingText copy];
    token.level = self.level;
    return token;
}

@end

@implementation WKCodeBlockToken

- (WKatchTokenType)type {
    return WKatchTokenTypeCodeBlock;
}

- (NSString *)codeContent {
    if(_codeContent) {
        return _codeContent;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKCodeBlockToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.codeContent = [self.codeContent copy];
    token.language = [self.language copy];
    return token;
}

@end

@implementation WKListItemToken

- (WKatchTokenType)type {
    return WKatchTokenTypeListItem;
}

- (NSString *)itemText {
    if(_itemText) {
        return _itemText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKListItemToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.itemText = [self.itemText copy];
    token.ordered = self.ordered;
    token.orderNumber = self.orderNumber;
    return token;
}

@end

@implementation WKBlockquoteToken

- (WKatchTokenType)type {
    return WKatchTokenTypeBlockquote;
}

- (NSString *)quoteText {
    if(_quoteText) {
        return _quoteText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKBlockquoteToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.quoteText = [self.quoteText copy];
    return token;
}

@end

@implementation WKTableToken

- (WKatchTokenType)type {
    return WKatchTokenTypeTable;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKTableToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.rows = [[NSArray alloc] initWithArray:self.rows copyItems:NO];
    token.hasHeader = self.hasHeader;
    return token;
}

@end

@implementation WKTaskItemToken

- (WKatchTokenType)type {
    return WKatchTokenTypeTaskItem;
}

- (NSString *)itemText {
    if(_itemText) {
        return _itemText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKTaskItemToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.itemText = [self.itemText copy];
    token.checked = self.checked;
    return token;
}

@end

@implementation WKHorizontalRuleToken

- (WKatchTokenType)type {
    return WKatchTokenTypeHorizontalRule;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKHorizontalRuleToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    return token;
}

@end

@implementation WKBoldItalicToken

- (WKatchTokenType)type {
    return WKatchTokenTypeBoldItalic;
}

- (NSString *)boldItalicText {
    if(_boldItalicText) {
        return _boldItalicText;
    }
    return self.text;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKBoldItalicToken *token = [[[self class] allocWithZone:zone] init];
    token.range = self.range;
    token.text = [self.text copy];
    token.type = self.type;
    token.boldItalicText = [self.boldItalicText copy];
    return token;
}

@end
