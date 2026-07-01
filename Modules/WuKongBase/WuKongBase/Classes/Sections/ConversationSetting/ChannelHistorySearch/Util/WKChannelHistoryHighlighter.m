//
//  WKChannelHistoryHighlighter.m
//

#import "WKChannelHistoryHighlighter.h"

@implementation WKChannelHistoryHighlighter

/// 把 snippet 解构成 [(text, isHighlight)...]。
/// 如果 snippet 完全不含 <mark>，返回 nil 表示走兜底路径。
+ (nullable NSArray<NSDictionary *> *)splitMarkSegments:(NSString *)snippet {
    if (snippet.length == 0) return nil;
    NSError *err = nil;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"<mark>([\\s\\S]*?)</mark>"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:nil];
    });
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:snippet
                                                              options:0
                                                                range:NSMakeRange(0, snippet.length)];
    if (matches.count == 0) return nil;
    NSMutableArray<NSDictionary *> *segs = [NSMutableArray array];
    NSUInteger cursor = 0;
    for (NSTextCheckingResult *m in matches) {
        if (m.range.location > cursor) {
            NSString *plain = [snippet substringWithRange:NSMakeRange(cursor, m.range.location - cursor)];
            [segs addObject:@{ @"text": plain, @"highlight": @NO }];
        }
        NSString *inner = [snippet substringWithRange:[m rangeAtIndex:1]];
        [segs addObject:@{ @"text": inner ?: @"", @"highlight": @YES }];
        cursor = NSMaxRange(m.range);
    }
    if (cursor < snippet.length) {
        NSString *tail = [snippet substringWithRange:NSMakeRange(cursor, snippet.length - cursor)];
        [segs addObject:@{ @"text": tail, @"highlight": @NO }];
    }
    return segs;
}

+ (NSAttributedString *)attributedFromSnippet:(NSString *)snippet
                                       keyword:(NSString *)keyword
                                          font:(UIFont *)font
                                     textColor:(UIColor *)textColor
                                highlightColor:(UIColor *)highlightColor {
    if (snippet.length == 0) {
        return [[NSAttributedString alloc] initWithString:@""];
    }
    NSArray<NSDictionary *> *segs = [self splitMarkSegments:snippet];
    if (segs) {
        NSMutableAttributedString *out = [NSMutableAttributedString new];
        for (NSDictionary *seg in segs) {
            NSString *t = seg[@"text"] ?: @"";
            BOOL hl = [seg[@"highlight"] boolValue];
            NSDictionary *attrs = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: hl ? highlightColor : textColor,
            };
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:t attributes:attrs]];
        }
        return out;
    }
    return [self attributedFromText:snippet
                              keyword:keyword
                                 font:font
                            textColor:textColor
                       highlightColor:highlightColor];
}

+ (NSAttributedString *)attributedFromText:(NSString *)text
                                    keyword:(NSString *)keyword
                                       font:(UIFont *)font
                                  textColor:(UIColor *)textColor
                             highlightColor:(UIColor *)highlightColor {
    NSString *s = text ?: @"";
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] initWithString:s attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
    }];
    NSString *needle = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (needle.length == 0 || s.length == 0) return out;
    NSRange searchRange = NSMakeRange(0, s.length);
    while (searchRange.location < s.length) {
        NSRange r = [s rangeOfString:needle
                              options:NSCaseInsensitiveSearch
                                range:searchRange];
        if (r.location == NSNotFound) break;
        [out addAttribute:NSForegroundColorAttributeName value:highlightColor range:r];
        NSUInteger next = NSMaxRange(r);
        searchRange = NSMakeRange(next, s.length - next);
    }
    return out;
}

+ (NSString *)centerSnippet:(NSString *)text keyword:(NSString *)keyword maxLength:(NSInteger)maxLength {
    if (text.length == 0) return @"";
    if (maxLength <= 0) return @"";
    NSString *kw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kw.length == 0) {
        return text.length > (NSUInteger)maxLength ? [text substringToIndex:maxLength] : text;
    }
    NSRange range = [text rangeOfString:kw options:NSCaseInsensitiveSearch];
    if (range.location == NSNotFound) {
        return text.length > (NSUInteger)maxLength
            ? [NSString stringWithFormat:@"%@...", [text substringToIndex:maxLength]]
            : text;
    }
    return [self centerSubstringInText:text
                              anchorLoc:range.location
                              anchorLen:range.length
                              maxLength:maxLength];
}

+ (NSString *)centerSnippetFromServerText:(NSString *)serverText
                                    keyword:(NSString *)keyword
                                  maxLength:(NSInteger)maxLength {
    if (serverText.length == 0) return @"";
    if (maxLength <= 0) return @"";
    static NSRegularExpression *regex;
    static NSRegularExpression *wsRegex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"<mark>([\\s\\S]*?)</mark>"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:nil];
        // 折叠连续空白 (含 \n \t 及多空格) → 单个空格
        wsRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s+"
                                                             options:0
                                                               error:nil];
    });

    // 关键: 服务端 snippet 常带大量 \n (代码块 / Markdown 列表 / 表格),
    // UILabel numberOfLines=2 会用光在这些换行上, 关键词附近的真实文字被挤到显示区外。
    // 先把所有连续空白折叠成单个空格, 再做 <mark> 剥除和居中, 显示效果才是"按文字量"截 2 行。
    NSString *flatSource = [wsRegex stringByReplacingMatchesInString:serverText
                                                             options:0
                                                               range:NSMakeRange(0, serverText.length)
                                                        withTemplate:@" "];
    NSTextCheckingResult *first = [regex firstMatchInString:flatSource
                                                    options:0
                                                      range:NSMakeRange(0, flatSource.length)];
    NSString *plain = first ? [self stripMarks:flatSource] : flatSource;

    // 锚点优先级 (关键改动):
    //   1) 纯文本里能找到 keyword 字符串 → 用它作锚 (最能对齐用户输入)
    //   2) 服务端 <mark> 存在 → 用第一个 <mark> 位置 (处理服务端做了词干/近义词匹配的情况)
    //   3) 都没匹配 → 从头截 maxLength + "..."
    NSString *kw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kw.length > 0) {
        NSRange r = [plain rangeOfString:kw options:NSCaseInsensitiveSearch];
        if (r.location != NSNotFound) {
            return [self centerSubstringInText:plain
                                     anchorLoc:r.location
                                     anchorLen:r.length
                                     maxLength:maxLength];
        }
    }
    if (first) {
        NSString *markedWord = [flatSource substringWithRange:[first rangeAtIndex:1]];
        return [self centerSubstringInText:plain
                                 anchorLoc:first.range.location
                                 anchorLen:markedWord.length
                                 maxLength:maxLength];
    }
    return plain.length > (NSUInteger)maxLength
        ? [NSString stringWithFormat:@"%@...", [plain substringToIndex:maxLength]]
        : plain;
}

+ (NSString *)stripMarks:(NSString *)html {
    if (html.length == 0) return @"";
    NSString *s = [html stringByReplacingOccurrencesOfString:@"<mark>"
                                                  withString:@""
                                                     options:NSCaseInsensitiveSearch
                                                       range:NSMakeRange(0, html.length)];
    return [s stringByReplacingOccurrencesOfString:@"</mark>"
                                        withString:@""
                                           options:NSCaseInsensitiveSearch
                                             range:NSMakeRange(0, s.length)];
}

/// 内部工具: 以 (anchorLoc, anchorLen) 为中心, 前后各取 (maxLength - anchorLen)/2 上下文,
/// 对齐到 composed character sequence 边界, 首尾按需加 "..."。
+ (NSString *)centerSubstringInText:(NSString *)text
                          anchorLoc:(NSInteger)anchorLoc
                          anchorLen:(NSInteger)anchorLen
                          maxLength:(NSInteger)maxLength {
    if (text.length == 0) return @"";
    if (anchorLoc < 0 || anchorLoc >= (NSInteger)text.length) return text;
    NSInteger radius = maxLength - anchorLen;
    if (radius < 0) radius = 0;
    NSInteger contextRadius = radius / 2;
    NSInteger start = MAX(0, anchorLoc - contextRadius);
    NSInteger end = MIN((NSInteger)text.length, anchorLoc + anchorLen + contextRadius);
    NSRange safe = [text rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, end - start)];
    NSString *snippet = [text substringWithRange:safe];
    if (safe.location > 0) snippet = [NSString stringWithFormat:@"...%@", snippet];
    if (NSMaxRange(safe) < text.length) snippet = [NSString stringWithFormat:@"%@...", snippet];
    return snippet;
}

@end
