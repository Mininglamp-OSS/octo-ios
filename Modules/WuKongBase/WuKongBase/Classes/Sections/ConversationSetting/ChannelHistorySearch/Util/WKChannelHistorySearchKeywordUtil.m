//
//  WKChannelHistorySearchKeywordUtil.m
//

#import "WKChannelHistorySearchKeywordUtil.h"

const NSInteger WKChannelHistorySearchKeywordMaxRunes = 64;

@implementation WKChannelHistorySearchKeywordUtil

+ (NSInteger)runeCount:(NSString *)keyword {
    if (keyword.length == 0) return 0;
    __block NSInteger count = 0;
    [keyword enumerateSubstringsInRange:NSMakeRange(0, keyword.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substr, NSRange r, NSRange er, BOOL *stop) {
        count++;
    }];
    return count;
}

+ (NSString *)truncate:(NSString *)keyword maxRunes:(NSInteger)maxRunes didTruncate:(BOOL *)didTruncate {
    if (didTruncate) *didTruncate = NO;
    if (keyword.length == 0) return keyword ?: @"";
    if (maxRunes <= 0) {
        if (didTruncate) *didTruncate = keyword.length > 0;
        return @"";
    }
    // 快路径：UTF-16 长度 <= maxRunes，必然不超
    if ((NSInteger)keyword.length <= maxRunes) return keyword;
    __block NSInteger count = 0;
    __block NSRange cutRange = NSMakeRange(0, keyword.length);
    [keyword enumerateSubstringsInRange:NSMakeRange(0, keyword.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substr, NSRange r, NSRange er, BOOL *stop) {
        count++;
        if (count == maxRunes) {
            cutRange = NSMakeRange(0, NSMaxRange(r));
            *stop = YES;
        }
    }];
    if (count <= maxRunes && cutRange.length == keyword.length) return keyword;
    if (didTruncate) *didTruncate = YES;
    return [keyword substringWithRange:cutRange];
}

+ (NSString *)truncateToDefault:(NSString *)keyword didTruncate:(BOOL *)didTruncate {
    return [self truncate:keyword maxRunes:WKChannelHistorySearchKeywordMaxRunes didTruncate:didTruncate];
}

@end
