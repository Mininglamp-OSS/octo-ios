// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  NSMutableAttributedString+WK.m
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import "NSMutableAttributedString+WK.h"

#import <objc/runtime.h>
#import "WKEmoticonService.h"
#import "WKRemoteImageAttachment.h"

static void * kFontKey = &kFontKey;
static void * kTextColorKey = &kTextColorKey;
static void * kMetionColor = &kMetionColor;
static void * kTokens = &kTokens;
static void *kMetionUnderline = &kMetionUnderline;
static void * kLinkColor = &kLinkColor;
@implementation NSMutableAttributedString (WK)

@dynamic font;
@dynamic textColor;

- (BOOL )metionUnderline {
    NSNumber *value =  objc_getAssociatedObject(self,kMetionUnderline);
    if(value && value.intValue == 1) {
        return true;
    }
    return false;
}


- (void)setMetionUnderline:(BOOL)metionUnderline {
    NSNumber *value = @0;
    if(metionUnderline) {
        value = @1;
    }
    objc_setAssociatedObject(self, kMetionUnderline, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(self.tokens && self.tokens.count>0) {
        for (id<WKMatchToken> token in self.tokens) {
            if(token.type == WKatchTokenTypeMetion) {
                [self removeAttribute:NSUnderlineStyleAttributeName range:token.range];
                [self addAttribute:NSUnderlineStyleAttributeName value:value range:token.range];
            }
        }
    }
}

- (UIColor *)metionColor {
    return  objc_getAssociatedObject(self,kMetionColor);
}


- (void)setMetionColor:(UIColor *)metionColor {
    objc_setAssociatedObject(self, kMetionColor, metionColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(self.tokens && self.tokens.count>0) {
        for (id<WKMatchToken> token in self.tokens) {
            if(token.type == WKatchTokenTypeMetion) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:metionColor range:token.range];
            }
        }
    }
}

- (UIColor *)linkColor {
    UIColor *color =   objc_getAssociatedObject(self,kLinkColor);
    if(color) {
        return color;
    }

    return [UIColor blueColor];
}

- (void)setLinkColor:(UIColor *)linkColor {
    objc_setAssociatedObject(self, kLinkColor, linkColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(self.tokens && self.tokens.count>0) {
        for (id<WKMatchToken> token in self.tokens) {
            if(token.type == WKatchTokenTypeLink || token.type == WKatchTokenTypeLink2) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:linkColor range:token.range];
            }
        }
    }
}

- (UIColor *)textColor {
    return  objc_getAssociatedObject(self, kTextColorKey);
}

- (void)setTextColor:(UIColor *)textColor {
    objc_setAssociatedObject(self, kTextColorKey, textColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if(self.tokens && self.tokens.count>0) {
        for (id<WKMatchToken> token in self.tokens) {
            if(token.range.location + token.range.length > self.length) {
                continue;
            }
            if(token.type == WKatchTokenTypeText) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeBold) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeItalic) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeStrikethrough) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeHeading) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeListItem) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeTaskItem) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeBoldItalic) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            } else if(token.type == WKatchTokenTypeTable) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            }
            // Skip code tokens (inline code, code block) and blockquote to keep their fixed colors
        }
    }
}

- (UIFont *)font{
    return objc_getAssociatedObject(self, kFontKey);
}

- (void)setFont:(UIFont*)font{
    return objc_setAssociatedObject(self, kFontKey, font, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<id<WKMatchToken>> *)tokens {
    return objc_getAssociatedObject(self, kTokens);
}

-(void) setTokens:(NSArray<id<WKMatchToken>>*)tokens {
    return objc_setAssociatedObject(self, kTokens, tokens, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)lim_parse:(NSString *)text {
    [self lim_parse:text mentionInfo:nil];
}

- (void)lim_parse:(NSString *)text mentionInfo:(WKMentionedInfo *)mentionInfo options:(WKRichTextParseOptions*)options{
    if(!text || [text isEqualToString:@""]) {
           return;
       }
       NSArray<id<WKMatchToken>> *tokens = [ [WKRichTextParseService shared] parse:text mentionInfo:mentionInfo options:options];

       // 判断是否为单个自定义表情（大图模式）：仅在聊天气泡中 + 只有一个 emoji token 且无其他文本
       BOOL isSingleCustomEmoji = NO;
       if (options && options.allowLargeCustomEmoji && tokens.count == 1 && tokens.firstObject.type == WKatchTokenTypeEmoji) {
           WKEmotionToken *singleToken = (WKEmotionToken *)tokens.firstObject;
           if ([singleToken.imageName hasPrefix:@"custom_"]) {
               isSingleCustomEmoji = YES;
           }
       }

       NSMutableArray<id<WKMatchToken>> *realTokens = [NSMutableArray array];
       for(id<WKMatchToken> token in tokens){
           NSRange range;
           if (token.type == WKatchTokenTypeEmoji){
               WKEmotionToken *emojiToken = (WKEmotionToken*)token;
               UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
               NSInteger location = self.length;
               if(image){
                   // 自定义表情单独发送时大图显示，混合文本时正常大小
                   CGFloat emojiSize = (isSingleCustomEmoji) ? 120.0f : 24.0f;
                   [self appendImage:image size:CGSizeMake(emojiSize, emojiSize)];
               }
               NSInteger length = self.length - location;
               range = NSMakeRange(location, length);
           }else if(token.type == WKatchTokenTypeLink) {
               range = [self appendLink:token];
           }else if(token.type == WKatchTokenTypeMetion) {
               range = [self appendMetion:token];
           }else{
               range = [self appendText:token.text];
           }
           token.range = range;
           [realTokens addObject:token];
       }
       self.tokens = realTokens;
}


-(void) lim_render:(NSString *)text tokens:(NSArray<id<WKMatchToken>>*)tokens {
    if(!tokens || tokens.count == 0) {
        // 无 entity tokens 时也尝试解析 emoji
        NSArray<id<WKMatchToken>> *emojiTokens = [[WKEmoticonService shared] parseEmotion:text];
        if (emojiTokens.count > 0 && !(emojiTokens.count == 1 && emojiTokens.firstObject.type == WKatchTokenTypeText)) {
            // 判断是否单个自定义表情大图
            BOOL isSingleCustom = NO;
            if (emojiTokens.count == 1 && emojiTokens.firstObject.type == WKatchTokenTypeEmoji) {
                WKEmotionToken *st = (WKEmotionToken *)emojiTokens.firstObject;
                if ([st.imageName hasPrefix:@"custom_"]) {
                    isSingleCustom = YES;
                }
            }
            NSMutableArray<id<WKMatchToken>> *realTokens = [NSMutableArray array];
            for (id<WKMatchToken> token in emojiTokens) {
                NSRange range;
                if (token.type == WKatchTokenTypeEmoji) {
                    WKEmotionToken *emojiToken = (WKEmotionToken *)token;
                    UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
                    NSInteger location = self.length;
                    if (image) {
                        CGFloat sz = isSingleCustom ? 120.0f : 24.0f;
                        [self appendImage:image size:CGSizeMake(sz, sz)];
                    }
                    range = NSMakeRange(location, self.length - location);
                } else {
                    range = [self appendText:token.text];
                }
                token.range = range;
                [realTokens addObject:token];
            }
            self.tokens = realTokens;
            return;
        }
        NSRange range = [self appendText:text];
        WKDefaultToken *token = [WKDefaultToken new];
        token.range = range;
        token.text = text;
        token.type = WKatchTokenTypeText;
        self.tokens = @[token];
        return;
    }

    tokens = [tokens sortedArrayUsingComparator:^NSComparisonResult(id<WKMatchToken>  _Nonnull obj1, id<WKMatchToken>  _Nonnull obj2) {
        if(obj1.range.location>obj2.range.location) {
            return NSOrderedDescending;
        }
        if(obj1.range.location == obj2.range.location) {
            return NSOrderedSame;
        }
        return NSOrderedAscending;
    }];
    NSMutableArray *newtokens = [NSMutableArray array];
    id<WKMatchToken> preToken;
    for (NSInteger i=0; i<tokens.count; i++) {
        id<WKMatchToken> token = tokens[i];
        if(!preToken) {
            if(token.range.location>0) {
                NSRange range = NSMakeRange(0, token.range.location);
                if(token.range.location>text.length) {
                    NSLog(@"------");
                }else {
                    NSString *tokenText = [text substringWithRange:range];
                    [newtokens addObject:[WKDefaultToken text:tokenText range:range type:WKatchTokenTypeText]];
                }

            }
        }else {
            if(token.range.location > preToken.range.location + preToken.range.length) {
                NSRange range = NSMakeRange(preToken.range.location + preToken.range.length, token.range.location - (preToken.range.location + preToken.range.length));
                NSString *tokenText = [text substringWithRange:range];
                [newtokens addObject:[WKDefaultToken text:tokenText range:range type:WKatchTokenTypeText]];
            }
        }
        [newtokens addObject:token];
        preToken = token;

        if(i == tokens.count-1 && text.length > token.range.location + token.range.length) {
            NSUInteger start = token.range.location + token.range.length;
            NSString *tokenText = [text substringFromIndex:start];
            [newtokens addObject:[WKDefaultToken text:tokenText range:NSMakeRange(start, text.length - start) type:WKatchTokenTypeText]];
        }
    }

    // 对 text 类型的 token 再过一遍 emoji 解析（支持自定义表情 [崇尚行动] 等）
    NSMutableArray *expandedTokens = [NSMutableArray array];
    for (id<WKMatchToken> token in newtokens) {
        if (token.type == WKatchTokenTypeText && token.text.length > 0) {
            NSArray<id<WKMatchToken>> *emojiTokens = [[WKEmoticonService shared] parseEmotion:token.text];
            if (emojiTokens.count > 0 && !(emojiTokens.count == 1 && emojiTokens.firstObject.type == WKatchTokenTypeText)) {
                [expandedTokens addObjectsFromArray:emojiTokens];
            } else {
                [expandedTokens addObject:token];
            }
        } else {
            [expandedTokens addObject:token];
        }
    }

    // 判断 expandedTokens 是否为单个自定义表情（大图）
    BOOL isLargeCustom = NO;
    if (expandedTokens.count == 1) {
        id<WKMatchToken> onlyToken = expandedTokens.firstObject;
        if (onlyToken.type == WKatchTokenTypeEmoji) {
            WKEmotionToken *et = (WKEmotionToken *)onlyToken;
            if ([et.imageName hasPrefix:@"custom_"]) {
                isLargeCustom = YES;
            }
        }
    }

    NSMutableArray<id<WKMatchToken>> *realTokens = [NSMutableArray array];
    for(id<WKMatchToken> token in expandedTokens){
        NSRange range;
        if (token.type == WKatchTokenTypeEmoji){
            WKEmotionToken *emojiToken = (WKEmotionToken*)token;
            UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
            NSInteger location = self.length;
            if(image){
                CGFloat sz = isLargeCustom ? 120.0f : 24.0f;
                [self appendImage:image size:CGSizeMake(sz, sz)];
            }
            NSInteger length = self.length - location;
            range = NSMakeRange(location, length);
        }else if(token.type == WKatchTokenTypeLink) {
            range = [self appendLink:token];
        }else if(token.type == WKatchTokenTypeMetion) {
            range = [self appendMetion:token];
        }else if(token.type == WKatchTokenTypeBold) {
            range = [self appendBold:token];
        }else if(token.type == WKatchTokenTypeLink2) {
            range = [self appendLink2:token];
        }else if(token.type == WKatchTokenTypeRemoteImage) {
            range = [self appendRemoteImage:token];
        }else if(token.type == WKatchTokenTypeColor) {
            range = [self appendColor:token];
        }else if(token.type == WKatchTokenTypeItalic) {
            range = [self appendItalic:token];
        }else if(token.type == WKatchTokenTypeStrikethrough) {
            range = [self appendStrikethrough:token];
        }else if(token.type == WKatchTokenTypeInlineCode) {
            range = [self appendInlineCode:token];
        }else if(token.type == WKatchTokenTypeHeading) {
            range = [self appendHeading:token];
        }else if(token.type == WKatchTokenTypeCodeBlock) {
            range = [self appendCodeBlock:token];
        }else if(token.type == WKatchTokenTypeListItem) {
            range = [self appendListItem:token];
        }else if(token.type == WKatchTokenTypeBlockquote) {
            range = [self appendBlockquote:token];
        }else if(token.type == WKatchTokenTypeTable) {
            range = [self appendTable:token];
        }else if(token.type == WKatchTokenTypeTaskItem) {
            range = [self appendTaskItem:token];
        }else if(token.type == WKatchTokenTypeHorizontalRule) {
            range = [self appendHorizontalRule:token];
        }else if(token.type == WKatchTokenTypeBoldItalic) {
            range = [self appendBoldItalic:token];
        } else {
            range = [self appendText:token.text];
        }
        id<WKMatchToken> newToken = [(WKDefaultToken*)token copy];
        newToken.range = range;
        [realTokens addObject:newToken];
    }

    self.tokens = realTokens;
}

- (void)lim_parse:(NSString *)text mentionInfo:(WKMentionedInfo *)mentionInfo {
    [self lim_parse:text mentionInfo:mentionInfo options:nil];
}


- (CGFloat)lastlineWidth:(CGFloat)maxWidth{
//    return maxWidth;
    CGSize labelSize = CGSizeMake(maxWidth, INFINITY);
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:labelSize];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];

    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    textContainer.lineFragmentPadding = 0.0;
    textContainer.lineBreakMode = NSLineBreakByWordWrapping;
    textContainer.maximumNumberOfLines = 0;

    NSInteger lastGlyphIndex = [layoutManager glyphIndexForCharacterAtIndex:self.length-1];

    CGRect lastLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:lastGlyphIndex effectiveRange:nil];

    return lastLineRect.size.width;
}

-(void) appendImage:(UIImage*)image size:(CGSize)size {
    NSTextAttachment *imageAtta = [[NSTextAttachment alloc] init];
    imageAtta.bounds = CGRectMake(0, -4.0f, size.width, size.height);
    imageAtta.image = image;
    [self appendAttributedString:[NSAttributedString attributedStringWithAttachment:imageAtta]];
}

-(NSRange) appendText:(NSString*)text {
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentLeft;
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    if(self.font) {
        [attributes setObject:self.font forKey:NSFontAttributeName];
    }
    if(self.textColor) {
        [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName];
    }
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:attributes];
    [self appendAttributedString:string];

    return NSMakeRange(self.length-text.length, text.length);
}

-(NSRange) appendLink:(WKDefaultToken*)token{
    if(!token || !token.text) {
        return NSMakeRange(self.length,0);
    }
    NSRange range = [self appendText:token.text];

//    [self addAttribute:NSLinkAttributeName value:[NSURL URLWithString:[token.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] range:range];
    [self addAttribute:NSForegroundColorAttributeName value:self.linkColor range:range];
    [self addAttribute:NSUnderlineStyleAttributeName value:@1 range:range];
    return range;
}

-(NSRange) appendLink2:(WKLinkToken*)token{
    if(!token || !token.linkText) {
        return NSMakeRange(self.length,0);
    }
    NSRange range = [self appendText:token.linkText];

    [self addAttribute:NSForegroundColorAttributeName value:self.linkColor range:range];
    [self addAttribute:NSUnderlineStyleAttributeName value:@1 range:range];
    return range;
}

-(NSRange) appendMetion:(WKMetionToken*)token {
    WKChannelInfo *metionChannelInfo = [WKSDK.shared.channelManager getCache:[WKChannel personWithChannelID:token.uid]];
    NSInteger len = 0;
    if(metionChannelInfo && metionChannelInfo.remark && ![metionChannelInfo.remark isEqualToString:@""]) {
        NSString *mentionText = [NSString stringWithFormat:@"@%@",metionChannelInfo.remark];
        len = mentionText.length;
        [self appendText:mentionText];
    }else{
        len = token.text.length;
        [self appendText:token.text];
    }

    UIColor *metionColor = self.metionColor;
    if(!metionColor) {
        metionColor = [UIColor orangeColor];
    }
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:metionColor forKey:NSForegroundColorAttributeName];
    if(self.metionUnderline) {
        [attributes setObject:@1 forKey:NSUnderlineStyleAttributeName];
    }
    NSRange range = NSMakeRange(self.length-len, len);
    [self addAttributes:attributes range:range];
    return range;
}

-(NSRange) appendBold:(WKBoldToken*)token {
    NSRange range = [self appendText:token.boldText?:@""];
    [self addAttribute:NSFontAttributeName value:[WKApp.shared.config appFontOfSizeMedium:self.font.pointSize] range:range];
    return range;
}

-(NSRange) appendColor:(WKColorToken*)token {
    NSRange range = [self appendText:token.text?:@""];
    [self addAttribute:NSForegroundColorAttributeName value:token.color range:range];
    return range;
}

-(NSRange) appendRemoteImage:(WKRemoteImageToken*)token {
    NSRange range =  [self appendText:token.text];
    WKRemoteImageAttachment *imageAttachMent = [[WKRemoteImageAttachment alloc] initWithURL:token.url displaySize:token.size];


    [self addAttribute:NSAttachmentAttributeName value:imageAttachMent range:range];


    return range;
}

#pragma mark - Markdown rendering methods

-(NSRange) appendItalic:(WKItalicToken*)token {
    NSString *displayText = token.italicText ?: @"";
    NSRange range = [self appendText:displayText];
    if (self.font) {
        UIFontDescriptor *descriptor = [self.font.fontDescriptor fontDescriptorWithMatrix:CGAffineTransformMake(1, 0, tanf(M_PI * -12.0f / 180.0f), 1, 0, 0)];
        UIFont *italicFont = [UIFont fontWithDescriptor:descriptor size:self.font.pointSize];
        [self addAttribute:NSFontAttributeName value:italicFont range:range];
    }
    return range;
}

-(NSRange) appendStrikethrough:(WKStrikethroughToken*)token {
    NSString *displayText = token.strikethroughText ?: @"";
    NSRange range = [self appendText:displayText];
    [self addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    return range;
}

-(NSRange) appendInlineCode:(WKInlineCodeToken*)token {
    NSString *displayText = token.codeText ?: @"";
    CGFloat fontSize = self.font ? self.font.pointSize : 15.0f;
    UIFont *codeFont = [UIFont fontWithName:@"Menlo" size:fontSize - 1.0f];
    if (!codeFont) {
        codeFont = [UIFont fontWithName:@"Courier" size:fontSize - 1.0f];
    }

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (codeFont) {
        [attributes setObject:codeFont forKey:NSFontAttributeName];
    }
    [attributes setObject:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0] forKey:NSForegroundColorAttributeName];
    [attributes setObject:[UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0] forKey:NSBackgroundColorAttributeName];

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:displayText attributes:attributes];
    NSUInteger startLoc = self.length;
    [self appendAttributedString:string];
    return NSMakeRange(startLoc, displayText.length);
}

-(NSRange) appendHeading:(WKHeadingToken*)token {
    NSString *displayText = token.headingText ?: @"";
    CGFloat baseFontSize = self.font ? self.font.pointSize : 15.0f;
    CGFloat scale = 1.15f;
    if (token.level == 1) scale = 1.5f;
    else if (token.level == 2) scale = 1.3f;

    CGFloat headingSize = baseFontSize * scale;
    UIFont *headingFont = [WKApp.shared.config appFontOfSizeMedium:headingSize];

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.paragraphSpacingBefore = 4.0f;
    style.paragraphSpacing = 4.0f;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:headingFont forKey:NSFontAttributeName];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    if (self.textColor) {
        [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName];
    }

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:displayText attributes:attributes];
    NSUInteger startLoc = self.length;
    [self appendAttributedString:string];
    return NSMakeRange(startLoc, displayText.length);
}

-(NSRange) appendCodeBlock:(WKCodeBlockToken*)token {
    NSString *displayText = token.codeContent ?: @"";
    CGFloat fontSize = self.font ? self.font.pointSize : 15.0f;
    UIFont *codeFont = [UIFont fontWithName:@"Menlo" size:fontSize - 1.0f];
    if (!codeFont) {
        codeFont = [UIFont fontWithName:@"Courier" size:fontSize - 1.0f];
    }

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByCharWrapping;
    style.firstLineHeadIndent = 8.0f;
    style.headIndent = 8.0f;
    style.tailIndent = -8.0f;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (codeFont) {
        [attributes setObject:codeFont forKey:NSFontAttributeName];
    }
    [attributes setObject:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0] forKey:NSForegroundColorAttributeName];
    [attributes setObject:[UIColor colorWithRed:0.93 green:0.93 blue:0.93 alpha:1.0] forKey:NSBackgroundColorAttributeName];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];

    // Add newline before code block for visual separation
    NSUInteger startLoc = self.length;
    if (startLoc > 0) {
        [self appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        startLoc = self.length;
    }

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:displayText attributes:attributes];
    [self appendAttributedString:string];

    // Add newline after code block
    [self appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];

    return NSMakeRange(startLoc, displayText.length);
}

-(NSRange) appendListItem:(WKListItemToken*)token {
    NSString *displayText = token.itemText ?: @"";
    NSString *prefix;
    if (token.ordered) {
        prefix = [NSString stringWithFormat:@" %ld.  ", (long)token.orderNumber];
    } else {
        prefix = @" \u2022  ";
    }
    NSString *fullText = [NSString stringWithFormat:@"%@%@", prefix, displayText];

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    // headIndent aligns wrapped lines with the text after the bullet/number
    CGFloat indentWidth = 28.0f;
    style.headIndent = indentWidth;
    style.firstLineHeadIndent = 0.0f;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    if (self.font) {
        [attributes setObject:self.font forKey:NSFontAttributeName];
    }
    if (self.textColor) {
        [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName];
    }

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:fullText attributes:attributes];
    NSUInteger startLoc = self.length;
    [self appendAttributedString:string];
    return NSMakeRange(startLoc, fullText.length);
}

-(NSRange) appendBlockquote:(WKBlockquoteToken*)token {
    NSString *displayText = token.quoteText ?: @"";

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.firstLineHeadIndent = 12.0f;
    style.headIndent = 12.0f;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    if (self.font) {
        [attributes setObject:self.font forKey:NSFontAttributeName];
    }
    [attributes setObject:[UIColor grayColor] forKey:NSForegroundColorAttributeName];

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:displayText attributes:attributes];
    NSUInteger startLoc = self.length;
    [self appendAttributedString:string];
    return NSMakeRange(startLoc, displayText.length);
}

-(NSRange) appendTable:(WKTableToken*)token {
    NSArray<NSArray<NSString*>*> *rows = token.rows;
    if (!rows || rows.count == 0) {
        return NSMakeRange(self.length, 0);
    }

    // Calculate column widths
    NSUInteger colCount = 0;
    for (NSArray<NSString*> *row in rows) {
        if (row.count > colCount) colCount = row.count;
    }
    if (colCount == 0) return NSMakeRange(self.length, 0);

    NSMutableArray<NSNumber*> *colWidths = [NSMutableArray array];
    for (NSUInteger c = 0; c < colCount; c++) {
        NSUInteger maxLen = 0;
        for (NSArray<NSString*> *row in rows) {
            if (c < row.count) {
                NSUInteger len = row[c].length;
                if (len > maxLen) maxLen = len;
            }
        }
        // Clamp max width per column to keep table compact
        if (maxLen > 16) maxLen = 16;
        if (maxLen < 2) maxLen = 2;
        [colWidths addObject:@(maxLen)];
    }

    CGFloat fontSize = self.font ? self.font.pointSize : 15.0f;
    UIFont *tableFont = [UIFont fontWithName:@"Menlo" size:fontSize - 2.0f];
    if (!tableFont) {
        tableFont = [UIFont fontWithName:@"Courier" size:fontSize - 2.0f];
    }

    NSUInteger startLoc = self.length;
    // Add newline before table if needed
    if (startLoc > 0) {
        [self appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    startLoc = self.length;

    for (NSUInteger r = 0; r < rows.count; r++) {
        NSArray<NSString*> *row = rows[r];
        NSMutableString *rowStr = [NSMutableString string];

        for (NSUInteger c = 0; c < colCount; c++) {
            NSString *cell = (c < row.count) ? row[c] : @"";
            NSUInteger targetLen = [colWidths[c] unsignedIntegerValue];
            // Truncate if too long
            if (cell.length > targetLen) {
                cell = [[cell substringToIndex:targetLen - 1] stringByAppendingString:@"\u2026"];
            }
            // Pad with spaces
            NSMutableString *padded = [cell mutableCopy];
            while (padded.length < targetLen) {
                [padded appendString:@" "];
            }
            if (c == 0) {
                [rowStr appendString:padded];
            } else {
                [rowStr appendFormat:@"  %@", padded];
            }
        }

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (tableFont) {
            [attributes setObject:tableFont forKey:NSFontAttributeName];
        }
        if (self.textColor) {
            [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName];
        }

        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        style.lineBreakMode = NSLineBreakByClipping;
        [attributes setObject:style forKey:NSParagraphStyleAttributeName];

        // Bold header row
        if (token.hasHeader && r == 0) {
            UIFont *boldTableFont = [UIFont fontWithName:@"Menlo-Bold" size:fontSize - 2.0f];
            if (boldTableFont) {
                [attributes setObject:boldTableFont forKey:NSFontAttributeName];
            }
        }

        NSAttributedString *rowAttrStr = [[NSAttributedString alloc] initWithString:rowStr attributes:attributes];
        [self appendAttributedString:rowAttrStr];

        // Add separator line after header
        if (token.hasHeader && r == 0) {
            NSMutableString *sepStr = [NSMutableString string];
            for (NSUInteger c = 0; c < colCount; c++) {
                NSUInteger targetLen = [colWidths[c] unsignedIntegerValue];
                NSMutableString *dashes = [NSMutableString string];
                for (NSUInteger d = 0; d < targetLen; d++) {
                    [dashes appendString:@"\u2500"];
                }
                if (c == 0) {
                    [sepStr appendString:dashes];
                } else {
                    [sepStr appendFormat:@"  %@", dashes];
                }
            }
            NSMutableDictionary *sepAttrs = [NSMutableDictionary dictionary];
            if (tableFont) [sepAttrs setObject:tableFont forKey:NSFontAttributeName];
            [sepAttrs setObject:[UIColor grayColor] forKey:NSForegroundColorAttributeName];
            [sepAttrs setObject:style forKey:NSParagraphStyleAttributeName];
            [self appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            [self appendAttributedString:[[NSAttributedString alloc] initWithString:sepStr attributes:sepAttrs]];
        }

        // Newline between rows
        if (r < rows.count - 1) {
            [self appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
    }

    return NSMakeRange(startLoc, self.length - startLoc);
}

-(NSRange) appendTaskItem:(WKTaskItemToken*)token {
    NSString *displayText = token.itemText ?: @"";
    NSString *checkbox = token.checked ? @"\u2611 " : @"\u2610 ";
    NSString *fullText = [NSString stringWithFormat:@"%@%@", checkbox, displayText];

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.headIndent = 24.0f;
    style.firstLineHeadIndent = 0.0f;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    if (self.font) {
        [attributes setObject:self.font forKey:NSFontAttributeName];
    }
    if (self.textColor) {
        [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName];
    }

    NSAttributedString *string = [[NSAttributedString alloc] initWithString:fullText attributes:attributes];
    NSUInteger startLoc = self.length;
    [self appendAttributedString:string];

    // Apply strikethrough to checked items
    if (token.checked) {
        NSRange textRange = NSMakeRange(startLoc + checkbox.length, displayText.length);
        [self addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:textRange];
        [self addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:textRange];
    }

    return NSMakeRange(startLoc, fullText.length);
}

-(NSRange) appendHorizontalRule:(WKHorizontalRuleToken*)token {
    NSString *rule = @"\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500";

    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByClipping;
    style.paragraphSpacingBefore = 4.0f;
    style.paragraphSpacing = 4.0f;
    style.alignment = NSTextAlignmentCenter;

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:style forKey:NSParagraphStyleAttributeName];
    [attributes setObject:[UIColor lightGrayColor] forKey:NSForegroundColorAttributeName];
    if (self.font) {
        [attributes setObject:[UIFont systemFontOfSize:self.font.pointSize * 0.6f] forKey:NSFontAttributeName];
    }

    NSUInteger startLoc = self.length;
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:rule attributes:attributes];
    [self appendAttributedString:string];
    return NSMakeRange(startLoc, rule.length);
}

-(NSRange) appendBoldItalic:(WKBoldItalicToken*)token {
    NSString *displayText = token.boldItalicText ?: @"";
    NSRange range = [self appendText:displayText];
    // Apply bold
    [self addAttribute:NSFontAttributeName value:[WKApp.shared.config appFontOfSizeMedium:self.font.pointSize] range:range];
    // Apply italic via oblique transform
    if (self.font) {
        UIFont *boldFont = [WKApp.shared.config appFontOfSizeMedium:self.font.pointSize];
        UIFontDescriptor *descriptor = [boldFont.fontDescriptor fontDescriptorWithMatrix:CGAffineTransformMake(1, 0, tanf(M_PI * -12.0f / 180.0f), 1, 0, 0)];
        UIFont *boldItalicFont = [UIFont fontWithDescriptor:descriptor size:self.font.pointSize];
        [self addAttribute:NSFontAttributeName value:boldItalicFont range:range];
    }
    return range;
}

-(CGSize) size:(CGFloat)maxWidth {
    CGSize size =   [self boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;

    return size;
}


@end
