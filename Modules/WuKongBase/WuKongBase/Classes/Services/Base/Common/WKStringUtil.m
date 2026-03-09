//
//  WKStringUtil.m
//  WuKongBase
//
//  Created by tt on 2021/11/8.
//

#define WKInputAtStartChar  @"@"
#define WKInputAtEndChar    @"\u2004"

#import "WKStringUtil.h"

@implementation WKStringUtil

+ (NSArray *)matchMention:(NSString *)text
{
    NSString *pattern = [NSString stringWithFormat:@"%@([^%@]+)%@",WKInputAtStartChar,WKInputAtEndChar,WKInputAtEndChar];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *results = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    NSMutableArray *matchs = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *result in results) {
        NSString *name = [text substringWithRange:result.range];
        name = [name substringFromIndex:1];
        name = [name substringToIndex:name.length -1];
        [matchs addObject:name];
    }
    return matchs;
}

@end
