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

@end

@implementation WKStrikethroughToken

- (WKatchTokenType)type {
    return WKatchTokenTypeStrikethrough;
}

@end


@implementation WKFontToken

- (WKatchTokenType)type {
    return WKatchTokenTypeFont;
}

@end
