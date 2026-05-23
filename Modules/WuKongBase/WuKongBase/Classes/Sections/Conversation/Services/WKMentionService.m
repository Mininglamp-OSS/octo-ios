//
//  WKMentionService.m
//  WuKongBase
//
//  Created by tt on 2020/7/16.
//

#import "WKMentionService.h"
#import "NSString+WKLocalized.h"

// LLang 在 WuKongBase.h 里定义，这里只引入 NSString+WKLocalized 取 -Localized: 调用，
// 然后本地复述 LLang 宏的等价表达式，避免拉入整套 WuKongBase.h。
#ifndef LLang
#define LLang(a) [a Localized:self]
#endif



@implementation WKMentionService
static WKMentionService *_instance;
+ (WKMentionService *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];

    });
    return _instance;
}

// 三态 mention 广播标签（@所有人 / @所有AI / @all），locale-independent 构建。
// 关键原则：这个列表用于解析来自任意 sender locale 的消息，必须覆盖所有可能的
// wire text，不只是接收方当前 locale 的渲染结果。Chinese 端发出 "@所有AI" 到
// English 端、English 端发出 "@All AIs" 到 Chinese 端，两个方向都必须命中。
// 因此必须把 canonical 中文 + 所有已知英文翻译 + 当前 locale 的 LLang 结果
// （为未来新增语言留出兼容空间）+ legacy "all" 都列上。
- (NSArray<NSString*>*)broadcastLabels {
    NSArray<NSString*> *names = @[
        @"所有人",           // Chinese canonical
        @"所有AI",           // Chinese canonical
        @"all",              // legacy English
        @"All People",       // en.lproj 所有人
        @"All AIs",          // en.lproj 所有AI
        LLang(@"所有人"),     // current locale (may add future translations)
        LLang(@"所有AI"),     // current locale
    ];
    NSMutableArray<NSString*> *unique = [NSMutableArray array];
    NSMutableSet<NSString*> *seen = [NSMutableSet set];
    for (NSString *n in names) {
        if (n.length == 0) continue;
        NSString *key = n.lowercaseString;
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [unique addObject:n];
    }
    // 长度降序：保证 "All AIs" 优先于 "all" 命中，避免短标签先抢。
    [unique sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        if (a.length > b.length) return NSOrderedAscending;
        if (a.length < b.length) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return unique;
}

- (NSRegularExpression* _Nullable)broadcastRegex {
    NSArray<NSString*> *labels = [self broadcastLabels];
    if (labels.count == 0) return nil;
    NSMutableArray<NSString*> *escaped = [NSMutableArray array];
    for (NSString *l in labels) {
        [escaped addObject:[NSRegularExpression escapedPatternForString:l]];
    }
    // 末尾 \b 保证 "@所有AI" 不会在 "@所有AIs" / "@所有人组" 这种延伸串里被误命中
    NSString *pattern = [NSString stringWithFormat:@"@(?:%@)\\b", [escaped componentsJoinedByString:@"|"]];
    return [NSRegularExpression regularExpressionWithPattern:pattern
                                                     options:NSRegularExpressionCaseInsensitive
                                                       error:nil];
}

-(NSArray<id<WKMatchToken>>*)parseMention:(NSString *)str mentionInfo:(WKMentionedInfo *)mentionInfo{
    if (!str || str.length == 0) {
        return @[];
    }
    static NSRegularExpression *atExp; // @正则表达式
    if(!atExp) {
        atExp = [NSRegularExpression regularExpressionWithPattern:@"@\\S+\\b"
        options:NSRegularExpressionCaseInsensitive
          error:nil];
    }
    // 先扫描广播 token —— 它们的 label 可能含空格（英文 "All AIs"），@\S+\b 会被空格截断，
    // 这里用本地化标签做字面量匹配，避免漏识别 / 切碎成 "@All" + " AIs"。
    NSRegularExpression *broadcastExp = [self broadcastRegex];
    NSMutableArray<NSValue*> *broadcastRanges = [NSMutableArray array];
    if (broadcastExp) {
        [broadcastExp enumerateMatchesInString:str
                                       options:0
                                         range:NSMakeRange(0, str.length)
                                    usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            [broadcastRanges addObject:[NSValue valueWithRange:result.range]];
        }];
    }
    // 收集普通 @mention，跳过与广播段重叠的命中（例如 "@All" 与 "@All AIs" 重叠时只保留后者）
    NSMutableArray<NSValue*> *mentionRanges = [NSMutableArray array];
    [atExp enumerateMatchesInString:str
       options:0
         range:NSMakeRange(0, str.length)
    usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        for (NSValue *bv in broadcastRanges) {
            NSRange br = [bv rangeValue];
            if (NSIntersectionRange(br, result.range).length > 0) {
                return;
            }
        }
        [mentionRanges addObject:[NSValue valueWithRange:result.range]];
    }];
    // 合并并按位置排序
    NSMutableArray<NSDictionary*> *entries = [NSMutableArray array];
    for (NSValue *v in broadcastRanges) {
        [entries addObject:@{@"range": v, @"broadcast": @YES}];
    }
    for (NSValue *v in mentionRanges) {
        [entries addObject:@{@"range": v, @"broadcast": @NO}];
    }
    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSRange ra = [(NSValue*)a[@"range"] rangeValue];
        NSRange rb = [(NSValue*)b[@"range"] rangeValue];
        if (ra.location < rb.location) return NSOrderedAscending;
        if (ra.location > rb.location) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];
    NSInteger index = 0;
    NSInteger mentionIndex = 0;
    for (NSDictionary *entry in entries) {
        NSRange r = [(NSValue*)entry[@"range"] rangeValue];
        if (r.location > (NSUInteger)index) {
            NSRange rawRange = NSMakeRange(index, r.location - index);
            NSString *rawText = [str substringWithRange:rawRange];
            [tokens addObject:[WKDefaultToken text:rawText range:rawRange type:WKatchTokenTypeText]];
        }
        NSString *rangeText = [str substringWithRange:r];
        BOOL isBroadcast = [entry[@"broadcast"] boolValue];
        if (isBroadcast) {
            // 三态 mention：广播 token（@所有人 / @所有AI / @all）单独高亮，不消费 mentionInfo.uids
            WKMetionToken *token = [WKMetionToken new];
            token.text = rangeText;
            token.range = r;
            token.uid = @"all"; // sentinel for broadcast rendering（点击不跳人卡片）
            [tokens addObject:token];
        } else {
            NSString *atUID;
            if (mentionInfo && mentionInfo.uids && mentionInfo.uids.count > (NSUInteger)mentionIndex) {
                atUID = mentionInfo.uids[mentionIndex];
            }
            if (atUID) {
                WKMetionToken *token = [WKMetionToken new];
                token.text = rangeText;
                token.range = r;
                token.index = mentionIndex;
                token.uid = atUID;
                [tokens addObject:token];
                mentionIndex++;
            } else {
                [tokens addObject:[WKDefaultToken text:rangeText range:r type:WKatchTokenTypeText]];
            }
        }
        index = r.location + r.length;
    }
    if ((NSUInteger)index < str.length) {
        NSRange range = NSMakeRange(index, str.length - index);
        NSString *rawText = [str substringWithRange:range];
        [tokens addObject:[WKDefaultToken text:rawText range:range type:WKatchTokenTypeText]];
    }
    return tokens;
}
@end
