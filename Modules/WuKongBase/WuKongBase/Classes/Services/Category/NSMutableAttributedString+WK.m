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
            if(token.type == WKatchTokenTypeText && token.range.location + token.range.length <= self.length) {
                [self removeAttribute:NSForegroundColorAttributeName range:token.range];
                [self addAttribute:NSForegroundColorAttributeName value:textColor range:token.range];
            }
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
       
       NSMutableArray<id<WKMatchToken>> *realTokens = [NSMutableArray array]; // 解析完后的字符串真实的token range
       for(id<WKMatchToken> token in tokens){
           NSRange range;
           if (token.type == WKatchTokenTypeEmoji){
               WKEmotionToken *emojiToken = (WKEmotionToken*)token;
               UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
               NSInteger location = self.length;
               if(image){
                   [self appendImage:image size:CGSizeMake(24.0f, 24.0f)];
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
            [newtokens addObject:[WKDefaultToken text:tokenText range:NSMakeRange(start, text.length) type:WKatchTokenTypeText]];
        }
    }
    
    NSMutableArray<id<WKMatchToken>> *realTokens = [NSMutableArray array]; // 解析完后的字符串真实的token range
    for(id<WKMatchToken> token in newtokens){
        NSRange range;
        if (token.type == WKatchTokenTypeEmoji){
            WKEmotionToken *emojiToken = (WKEmotionToken*)token;
            UIImage *image = [[WKEmoticonService shared] emojiImageNamed:emojiToken.imageName];
            NSInteger location = self.length;
            if(image){
                [self appendImage:image size:CGSizeMake(24.0f, 24.0f)];
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

-(CGSize) size:(CGFloat)maxWidth {
    CGSize size =   [self boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    
    return size;
}


@end
