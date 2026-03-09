//
//  WKRichTextParseService.m
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import "WKRichTextParseService.h"
#import "WKEmoticonService.h"
#import "WKMentionService.h"

@implementation WKRichTextParseOptions



@end

@implementation WKRichTextParseService

static WKRichTextParseService *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKRichTextParseService *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        
    });
    return _instance;
}

-(NSArray<id<WKMatchToken>>*) parse:(NSString*)text mentionInfo:(WKMentionedInfo*)mentionInfo options:(WKRichTextParseOptions*)options{
    NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];
    NSArray<id<WKMatchToken>> *linkTokens;
    if(options && options.disableLink) {
        linkTokens = @[ [WKDefaultToken text:text range:NSMakeRange(0, text.length) type:WKatchTokenTypeText]];
    }else{
        linkTokens =  [self parseLink:text];
    }
    if(linkTokens && linkTokens.count>0) {
        for (id<WKMatchToken> matchToken in linkTokens) {
            if(matchToken.type == WKatchTokenTypeLink) {
                [tokens addObject:matchToken];
            }else {
                NSArray<id<WKMatchToken>> *emojiTokens = [[WKEmoticonService shared] parseEmotion:matchToken.text];
                for(id<WKMatchToken> token in emojiTokens){
                    if (token.type == WKatchTokenTypeEmoji){
                        [tokens addObject:token];
                    }else  {
                        if(mentionInfo) {
                            NSArray<id<WKMatchToken>> *mentions = [[WKMentionService shared] parseMention:token.text mentionInfo:mentionInfo];
                            if(mentions && mentions.count>0) {
                                [tokens addObjectsFromArray:mentions];
                            }
                        }else{
                            [tokens addObject:token];
                        }
                    }
                }
            }
        }
    }
    return tokens;
}

-(NSArray<id<WKMatchToken>>*) parseLink:(NSString*)text {
    NSDataDetector *detector = [self linkDetector];
    NSMutableArray *links = [NSMutableArray array];
    __block NSInteger index = 0;
    [detector enumerateMatchesInString:text
                               options:0
                                 range:NSMakeRange(0, [text length])
                            usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        NSRange range = result.range;
        if (range.location > index){
            NSRange rawRange = NSMakeRange(index, result.range.location - index);
            NSString *rawText = [text substringWithRange:rawRange];
            [links addObject:[WKDefaultToken text:rawText range:rawRange type:WKatchTokenTypeText]];
        }
        NSString *lk = [text substringWithRange:range];
        [links addObject: [WKDefaultToken text:lk range:range type:WKatchTokenTypeLink]];
        index = result.range.location + result.range.length;
    }];
    if (index < [text length])
    {
        NSRange range = NSMakeRange(index, [text length] - index);
        NSString *rawText = [text substringWithRange:range];
        [links addObject:[WKDefaultToken text:rawText range:range type:WKatchTokenTypeText]];
    }
    return links;
}

- (NSDataDetector *)linkDetector
{
    static NSString *WKLinkDetectorKey = @"WKLinkDetectorKey";
    
    NSMutableDictionary *dict = [[NSThread currentThread] threadDictionary];
    NSDataDetector *detector = dict[WKLinkDetectorKey];
    if (detector == nil)
    {
        detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber
                                                   error:nil];
        if (detector)
        {
            dict[WKLinkDetectorKey] = detector;
        }
    }
    return detector;
}


@end
