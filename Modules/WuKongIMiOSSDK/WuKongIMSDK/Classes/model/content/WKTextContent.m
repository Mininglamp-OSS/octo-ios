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
    if(self.content) {
        return [self.content stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    }
    return @"";
}

- (NSString *)searchableWord {
     return self.content;
}
@end
