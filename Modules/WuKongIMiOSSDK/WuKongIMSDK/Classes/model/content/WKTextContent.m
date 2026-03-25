//
//  WKText.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKTextContent.h"
#import "WKConst.h"
@implementation WKTextContent

- (instancetype)initWithContent:(NSString*)content {
    self = [super init];
    if(self) {
        self.content = content;
    }
    return self;
}


- (void)decodeWithJSON:(NSDictionary *)contentDic {
     self.content = contentDic[@"content"];
    self.format = contentDic[@"format"]?:@"";
}


- (NSDictionary *)encodeWithJSON {
    return @{@"content":self.content?:@"",@"format":self.format?:@""};
}

+(NSNumber*) contentType {
    return @(WK_TEXT);
}


- (NSString *)conversationDigest {
    if([self.format isEqualToString:@"html"]) {
        NSRegularExpression *regularExpretion=[NSRegularExpression regularExpressionWithPattern:@"<[^>]*>|\n"
                                                options:0
                                                 error:nil];
        NSString *digest=[regularExpretion stringByReplacingMatchesInString:self.content options:NSMatchingReportProgress range:NSMakeRange(0, self.content.length) withTemplate:@""];
        return digest;
    }
    if(!self.content) return @"";
    NSMutableString *digest = [self.content mutableCopy];
    // 对所有文本统一去除 markdown 语法（普通文本不含这些语法，不受影响）
    // Strip code fences
    NSRegularExpression *codeFenceRegex = [NSRegularExpression regularExpressionWithPattern:@"```[\\s\\S]*?```" options:0 error:nil];
    [codeFenceRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"[code]"];
    // Strip bold **text** -> text
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.+?)\\*\\*" options:0 error:nil];
    [boldRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Strip italic *text* -> text
    NSRegularExpression *italicRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*(.+?)\\*" options:0 error:nil];
    [italicRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Strip strikethrough ~~text~~ -> text
    NSRegularExpression *strikeRegex = [NSRegularExpression regularExpressionWithPattern:@"~~(.+?)~~" options:0 error:nil];
    [strikeRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Strip inline code `text` -> text
    NSRegularExpression *inlineCodeRegex = [NSRegularExpression regularExpressionWithPattern:@"`(.+?)`" options:0 error:nil];
    [inlineCodeRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Strip links [text](url) -> text
    NSRegularExpression *linkRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[(.+?)\\]\\(.+?\\)" options:0 error:nil];
    [linkRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Strip heading markers
    NSRegularExpression *headingRegex = [NSRegularExpression regularExpressionWithPattern:@"^#{1,3} " options:NSRegularExpressionAnchorsMatchLines error:nil];
    [headingRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@""];
    // Strip blockquote markers
    NSRegularExpression *quoteRegex = [NSRegularExpression regularExpressionWithPattern:@"^> ?" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [quoteRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@""];
    // Strip list markers
    NSRegularExpression *listRegex = [NSRegularExpression regularExpressionWithPattern:@"^[\\-\\*] |^\\d+\\. " options:NSRegularExpressionAnchorsMatchLines error:nil];
    [listRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@""];
    // Strip task list markers - [x] or - [ ]
    NSRegularExpression *taskRegex = [NSRegularExpression regularExpressionWithPattern:@"^- \\[[xX ]\\] " options:NSRegularExpressionAnchorsMatchLines error:nil];
    [taskRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@""];
    // Strip horizontal rules
    NSRegularExpression *hrRegex = [NSRegularExpression regularExpressionWithPattern:@"^-{3,}$|^\\*{3,}$|^_{3,}$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [hrRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@""];
    // Strip table rows (lines starting/ending with |)
    NSRegularExpression *tableRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\|.*\\|$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [tableRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"[table]"];
    // Strip bold+italic ***text*** -> text
    NSRegularExpression *boldItalicRegex = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*\\*(.+?)\\*\\*\\*" options:0 error:nil];
    [boldItalicRegex replaceMatchesInString:digest options:0 range:NSMakeRange(0, digest.length) withTemplate:@"$1"];
    // Replace newlines with spaces
    return [digest stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

- (NSString *)searchableWord {
     return self.content;
}
@end
